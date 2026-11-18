import Foundation
import Combine
import Security
import SwiftUI
import AuthenticationServices

// MARK: - Backend contract (client side of the agreement)
//
// All endpoints live under https://minglimaster.com/between/api
//
// POST /auth/apple
//   { "identity_token": "...", "authorization_code": "..." }
//   200 { "token": "...", "user": { "id": "A7K2M9", "nickname": null }, "needs_nickname": true }
//
// GET /me                       Authorization: Bearer <token>
//   -> { "user": { "id": "A7K2M9", "nickname": "晚风" } }
//
// PATCH /me                     { "nickname": "晚风" }
//   200 { "user": { ... } } | 409 { "error": "nickname_taken" }
//
// DELETE /me                    -> 204
//
// Guests carry no token and may only call read endpoints.

enum BetweenAPI {
    static var base: String {
        ProcessInfo.processInfo.environment["BETWEEN_API_BASE"] ?? "https://minglimaster.com/between/api"
    }
}

struct BetweenAccount: Codable, Equatable {
    let id: String
    var nickname: String?
}

struct AuthUserPayload: Decodable {
    let id: String
    let nickname: String?
}

struct AuthResponse: Decodable {
    let token: String
    let user: AuthUserPayload
    let needs_nickname: Bool?
}

private struct AuthUserEnvelope: Decodable { let user: AuthUserPayload }

enum NicknameRule {
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validate(_ raw: String, zh: Bool) -> String? {
        let name = normalize(raw)
        if name.count < 2 { return zh ? "昵称至少需要 2 个字符" : "Use at least 2 characters" }
        if name.count > 16 { return zh ? "昵称最多 16 个字符" : "Use at most 16 characters" }
        var allowed = CharacterSet.letters
        allowed.insert(charactersIn: "0123456789_-")
        if name.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return zh ? "只支持中英文、数字、下划线和短横线" : "Use letters, numbers, _ or - only"
        }
        return nil
    }
}

private enum KeychainStore {
    static let service = "com.example.between.account"

    static func set(_ value: String, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var account: BetweenAccount?
    @Published var needsNickname = false
    @Published var busy = false
    @Published var errorText: String?

    private let tokenKey = "session.token"
    private let cacheKey = "between.account.v1"

    var isPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-preview-fixture")
        #else
        return false
        #endif
    }

    var isGuest: Bool { account == nil }
    var isReady: Bool { account != nil && !needsNickname }
    var displayName: String { account?.nickname ?? "" }
    var userId: String? { account?.id }

    private var zh: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-zh") || UserDefaults.standard.string(forKey: "native.language") == "zh"
    }
    private func t(_ a: String, _ b: String) -> String { zh ? a : b }

    init() {
        if isPreview {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-ui-guest") {
                account = nil
            } else if args.contains("-ui-nickname") {
                account = BetweenAccount(id: "A7K2M9", nickname: nil)
                needsNickname = true
            } else {
                account = BetweenAccount(id: "A7K2M9", nickname: zh ? "晚风" : "Nightfall")
            }
            return
        }
        if let cached = loadCachedAccount() {
            account = cached
            needsNickname = (cached.nickname?.isEmpty ?? true)
        }
    }

    // MARK: Session bootstrap

    func bootstrap() async {
        guard !isPreview, let token = KeychainStore.get(tokenKey), account != nil else { return }
        do {
            let fresh = try await fetchMe(token)
            persist(fresh)
        } catch AuthFailure.unauthorized {
            clearSession()
        } catch {
            // Offline: keep the cached nickname so the profile still renders.
        }
    }

    // MARK: Apple sign-in

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityData = credential.identityToken,
                  let identityToken = String(data: identityData, encoding: .utf8) else {
                errorText = t("无法读取 Apple 登录凭证，请稍后再试", "Could not read the Apple credential. Try again.")
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            Task { await exchange(identityToken: identityToken, authorizationCode: code) }
        case .failure(let error):
            if let appleError = error as? ASAuthorizationError, appleError.code == .canceled { return }
            errorText = t("登录没有完成，请稍后再试", "Sign in didn’t finish. Try again.")
        }
    }

    private func exchange(identityToken: String, authorizationCode: String) async {
        busy = true
        errorText = nil
        defer { busy = false }
        if isPreview {
            account = BetweenAccount(id: "A7K2M9", nickname: nil)
            needsNickname = true
            return
        }
        do {
            var request = URLRequest(url: URL(string: BetweenAPI.base + "/auth/apple")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["identity_token": identityToken, "authorization_code": authorizationCode])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw AuthFailure.server
            }
            let payload = try JSONDecoder().decode(AuthResponse.self, from: data)
            KeychainStore.set(payload.token, for: tokenKey)
            let fresh = BetweenAccount(id: payload.user.id, nickname: payload.user.nickname)
            persist(fresh)
        } catch {
            errorText = t("登录失败，请检查网络后重试", "Sign in failed. Check your connection and try again.")
        }
    }

    // MARK: Nickname

    /// Returns an error message when the nickname cannot be used.
    func submitNickname(_ raw: String) async -> String? {
        let name = NicknameRule.normalize(raw)
        if let message = NicknameRule.validate(name, zh: zh) { return message }
        guard let current = account else {
            return t("请先通过 Apple 登录", "Sign in with Apple first")
        }
        if let old = current.nickname, old == name, !needsNickname { return nil }
        busy = true
        errorText = nil
        defer { busy = false }
        if isPreview {
            if ["admin", "管理员", "angel", "devil"].contains(name.lowercased()) {
                return t("这个昵称已被占用", "That nickname is taken")
            }
            var updated = current
            updated.nickname = name
            persist(updated)
            needsNickname = false
            return nil
        }
        guard let token = KeychainStore.get(tokenKey) else {
            return t("登录已过期，请重新登录", "Your session expired. Sign in again.")
        }
        do {
            var request = URLRequest(url: URL(string: BetweenAPI.base + "/me")!)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(["nickname": name])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AuthFailure.server }
            if http.statusCode == 409 {
                return t("这个昵称已被占用，换一个试试", "That nickname is taken. Try another.")
            }
            guard http.statusCode == 200 else { throw AuthFailure.server }
            let envelope = try JSONDecoder().decode(AuthUserEnvelope.self, from: data)
            persist(BetweenAccount(id: envelope.user.id, nickname: envelope.user.nickname ?? name))
            needsNickname = false
            return nil
        } catch {
            return t("保存昵称失败，请稍后再试", "Could not save the nickname. Try again.")
        }
    }

    // MARK: Sign out / delete

    func signOut() {
        clearSession()
        errorText = nil
    }

    func deleteAccount() async -> Bool {
        busy = true
        errorText = nil
        defer { busy = false }
        if !isPreview, let token = KeychainStore.get(tokenKey) {
            var request = URLRequest(url: URL(string: BetweenAPI.base + "/me")!)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 204 else {
                    errorText = t("删除账号失败，请稍后再试", "Could not delete the account. Try again.")
                    return false
                }
            } catch {
                errorText = t("删除账号失败，请稍后再试", "Could not delete the account. Try again.")
                return false
            }
        }
        clearSession()
        return true
    }

    // MARK: Helpers

    private func fetchMe(_ token: String) async throws -> BetweenAccount {
        var request = URLRequest(url: URL(string: BetweenAPI.base + "/me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthFailure.server }
        if http.statusCode == 401 { throw AuthFailure.unauthorized }
        guard http.statusCode == 200 else { throw AuthFailure.server }
        let envelope = try JSONDecoder().decode(AuthUserEnvelope.self, from: data)
        return BetweenAccount(id: envelope.user.id, nickname: envelope.user.nickname)
    }

    private func persist(_ fresh: BetweenAccount) {
        account = fresh
        needsNickname = (fresh.nickname?.isEmpty ?? true)
        if let data = try? JSONEncoder().encode(fresh) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCachedAccount() -> BetweenAccount? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(BetweenAccount.self, from: data)
    }

    private func clearSession() {
        KeychainStore.remove(tokenKey)
        UserDefaults.standard.removeObject(forKey: cacheKey)
        account = nil
        needsNickname = false
    }
}

private enum AuthFailure: Error {
    case unauthorized
    case server
}

/// System Sign in with Apple control, styled to match the paper UI.
struct AppleSignInControl: View {
    @ObservedObject var auth: AuthManager

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = []
        } onCompletion: { result in
            Task { @MainActor in auth.handleAppleCompletion(result) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(auth.busy ? 0.55 : 1)
        .disabled(auth.busy)
    }
}
