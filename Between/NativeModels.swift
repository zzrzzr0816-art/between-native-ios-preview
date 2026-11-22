import SwiftUI

struct NativeReply: Codable, Equatable { let id: String?; let author: String; let text: String; var authorID: String? = nil; var publicAuthorID: String? = nil; var mine: Bool? = nil }
struct NativeAnswer: Codable, Identifiable, Equatable {
    let id: String
    let author: String
    let side: String
    let text: String
    var likes: Int
    var replies: [NativeReply]
    var authorID: String? = nil
    var publicAuthorID: String? = nil
    var mine: Bool? = nil
    var liked: Bool? = nil
}
struct NativeStory: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    var detail: String? = nil
    let created: Double
    var answers: [NativeAnswer]
    var author: String? = nil
    var authorID: String? = nil
    var publicAuthorID: String? = nil
    var mine: Bool? = nil

    func hoursRemaining(at now: Double = Date().timeIntervalSince1970) -> Int {
        let remaining = (created/1000+86400-now)/3600
        guard remaining.isFinite else { return 0 }
        return Int(min(24,max(0,ceil(remaining))))
    }
}
struct NativeReportDetails: Codable {
    var content: String?
    var targetNickname: String?
    var targetPublicID: String?
    var camp: String?
    var createdAt: Date?
    var acceptanceStatus: String?
    var result: String?
}

struct NativeBlockedRecord: Codable, Identifiable {
    let id: String
    let nickname: String?
    let blockedAt: Date
    let server: Bool
}

struct NativeLocalState: Codable {
    var localStories: [NativeStory] = []
    var snapshots: [NativeStory] = []
    var reports: [String] = []
    var reportDetails: [String: NativeReportDetails]? = nil
    var hidden: [String] = []
    var liked: [String: Bool] = [:]
    var best: [String: String] = [:]
    var updates: [String: [String]] = [:]
    var replies: [String: [NativeReply]] = [:]
    var myAnswers: [String: [NativeAnswer]] = [:]
    var reviewed: [String]? = nil
    var storyExpiry: [String: Double]? = nil
    var replyStory: [String: String]? = nil
    var answerOwnership: Set<String>? = nil
    var replyOwnership: Set<String>? = nil
    var seenIncomingReplies: Set<String>? = nil
    var blockedAuthorIDs: Set<String>? = nil
    var blockedRecords: [NativeBlockedRecord]? = nil

    func isBlocked(_ authorID: String?) -> Bool {
        authorID.map { blockedAuthorIDs?.contains($0) == true } ?? false
    }

    func filteringBlockedAuthors(in story: NativeStory) -> NativeStory? {
        guard !isBlocked(story.authorID) else { return nil }
        var visible = story
        visible.answers = story.answers.filter { !isBlocked($0.authorID) }.map { answer in
            var answer = answer
            answer.replies.removeAll { isBlocked($0.authorID) }
            return answer
        }
        return visible
    }

    mutating func rememberExpiry(of story: NativeStory) {
        var expiry = storyExpiry ?? [:]
        expiry[story.id] = story.created/1000+86400
        storyExpiry = expiry
    }

    mutating func visibleStories(merging sourceStories: [NativeStory], at now: Double) -> ([NativeStory], Bool) {
        let originals = localStories + sourceStories
        var changed = false
        var visible: [NativeStory] = []
        for var story in originals where story.created/1000+86400 > now {
            let originals = story.answers
            let originalIDs = Set(originals.map(\.id))
            if let saved = myAnswers[story.id] {
                let owned = saved.filter { !originalIDs.contains($0.id) }
                if owned.count != saved.count { myAnswers[story.id] = owned; changed = true }
                let known = answerOwnership ?? []
                let ids = known.subtracting(originalIDs).union(owned.map(\.id))
                if ids != known { answerOwnership = ids; changed = true }
                if !owned.isEmpty && storyExpiry?[story.id] == nil { rememberExpiry(of: story); changed = true }
                var visibleAnswerIDs = originalIDs
                story.answers.append(contentsOf: owned.filter { visibleAnswerIDs.insert($0.id).inserted })
            }
            for index in story.answers.indices {
                let answer = story.answers[index]
                guard let saved = replies[answer.id] else { continue }
                let source = originals.first { $0.id == answer.id }?.replies ?? []
                let originalReplyIDs = Set(source.compactMap(\.id))
                let local = saved.filter { reply in
                    guard let id = reply.id else { return false }
                    return !originalReplyIDs.contains(id)
                }
                if local.count != saved.count { replies[answer.id] = local; changed = true }
                let known = replyOwnership ?? []
                let verified = known.subtracting(originalReplyIDs)
                if known != verified { replyOwnership = verified; changed = true }
                if !local.isEmpty && replyStory?[answer.id] == nil {
                    var parents = replyStory ?? [:]
                    parents[answer.id] = story.id
                    replyStory = parents
                    rememberExpiry(of: story)
                    changed = true
                }
                var ids = Set(answer.replies.compactMap(\.id))
                story.answers[index].replies.append(contentsOf: local.filter { reply in
                    reply.id.map { ids.insert($0).inserted } ?? false
                })
            }
            if !hidden.contains(story.id), let filtered = filteringBlockedAuthors(in:story) { visible.append(filtered) }
        }
        return (visible, changed)
    }

    mutating func renameOwnedContent(to name: String) {
        let answersOwned = answerOwnership ?? []
        let repliesOwned = replyOwnership ?? []
        myAnswers = myAnswers.mapValues { answers in
            answers.map { answer in
                guard answersOwned.contains(answer.id) else { return answer }
                return NativeAnswer(id:answer.id,author:name,side:answer.side,text:answer.text,likes:answer.likes,replies:answer.replies)
            }
        }
        replies = replies.mapValues { replies in
            replies.map { reply in
                guard let id = reply.id, repliesOwned.contains(id) else { return reply }
                return NativeReply(id:id,author:name,text:reply.text)
            }
        }
    }

    mutating func migrateLocalStories() -> Bool {
        var changed = false
        for index in localStories.indices where !localStories[index].answers.isEmpty {
            let story = localStories[index]
            var saved = myAnswers[story.id] ?? []
            var ids = Set(saved.map(\.id))
            for answer in story.answers where ids.insert(answer.id).inserted { saved.append(answer) }
            answerOwnership = (answerOwnership ?? []).union(story.answers.map(\.id))
            myAnswers[story.id] = saved
            localStories[index].answers = []
            changed = true
        }
        return changed
    }

    mutating func prune(at now: Double, expiredStoryIDs: Set<String> = []) -> Bool {
        var expiry = storyExpiry ?? [:]
        for story in localStories + snapshots { expiry[story.id] = story.created/1000+86400 }
        let expired = expiredStoryIDs.union(expiry.filter { $0.value <= now }.keys)
        guard !expired.isEmpty else { return false }
        var parents = replyStory ?? [:]
        let answerIDs = Set(expired.flatMap { id in (myAnswers[id] ?? []).map(\.id) })
        let replyKeys = Set(parents.filter { expired.contains($0.value) }.keys).union(answerIDs)
        answerOwnership?.subtract(answerIDs)
        for id in replyKeys {
            replyOwnership?.subtract((replies[id] ?? []).compactMap(\.id))
            replies[id] = nil; parents[id] = nil; liked[id] = nil
        }
        for id in expired { myAnswers[id] = nil; updates[id] = nil; expiry[id] = nil }
        best = best.filter { key, _ in !expired.contains(String(key.prefix { $0 != "|" })) }
        localStories.removeAll { expired.contains($0.id) }
        snapshots.removeAll { expired.contains($0.id) }
        hidden.removeAll { expired.contains($0) }
        storyExpiry = expiry
        replyStory = parents
        return true
    }
}
enum NativeLocalStorage {
    static let legacyGuestKey = "native.local.v1"
    private static let recoverySuffix = ".recovery"
    private struct Recovery: Codable {
        let bytes: Data
        let created: Double
    }

    static func load(from store: UserDefaults, key: String, useLegacyGuest: Bool,
                     now: Double = Date().timeIntervalSince1970) -> (state: NativeLocalState, recoveredUnreadableData: Bool) {
        let recoveryKey = key + recoverySuffix
        if let blob = store.data(forKey:recoveryKey),
           let archive = try? JSONDecoder().decode(Recovery.self,from:blob),
           now-archive.created >= 86400 {
            store.removeObject(forKey:recoveryKey)
        }
        let current = store.data(forKey:key)
        if let current, let state = try? JSONDecoder().decode(NativeLocalState.self,from:current) {
            return (state,false)
        }
        let legacy = useLegacyGuest ? store.data(forKey:legacyGuestKey) : nil
        if let unreadable = current ?? legacy,
           (try? JSONDecoder().decode(NativeLocalState.self,from:unreadable)) == nil,
           store.data(forKey:recoveryKey) == nil,
           let archive = try? JSONEncoder().encode(Recovery(bytes:unreadable,created:now)) {
            store.set(archive,forKey:recoveryKey)
            if store.data(forKey:recoveryKey) == archive {
                store.removeObject(forKey:current == nil ? legacyGuestKey : key)
            }
        }
        if let legacy, let state = try? JSONDecoder().decode(NativeLocalState.self,from:legacy) {
            store.set(legacy,forKey:key)
            if store.data(forKey:key) == legacy { store.removeObject(forKey:legacyGuestKey) }
            return (state,current != nil)
        }
        return (NativeLocalState(),current != nil || legacy != nil)
    }

    static func remove(from store: UserDefaults, key: String) {
        store.removeObject(forKey:key)
        store.removeObject(forKey:key+recoverySuffix)
    }
}

struct NativeFeed: Decodable { let stories: [NativeStory]; let next_offset: Int? }
enum NativeCamp: String {
    case devil, angel
    var accent: Color { Color(hex: self == .devil ? 0xc6786d : 0x628fa9) }
    var background: Color { Color(hex: self == .devil ? 0xfff2ef : 0xeef8ff) }
    var sign: CGFloat { self == .angel ? -1 : 1 }
}
@MainActor final class NativeFeedModel: ObservableObject {
    @Published var stories: [NativeStory] = []
    @Published var loading = false
    @Published var error = false
    @Published var index = 0
    @Published var nextOffset: Int? = nil
    @Published var loadingMore = false
    @Published var pageError = false
    private(set) var loadedLanguage: String?
    private var revision = 0
    private var loadedViewer = "guest"
    private let session: URLSession
    private let apiBase: String

    init(session: URLSession = .shared, apiBase: String = BetweenAPI.base) {
        self.session = session
        self.apiBase = apiBase
    }
    private(set) var sourceStories: [NativeStory] = []
    var current: NativeStory? { stories.indices.contains(index) ? stories[index] : nil }
    var preview: Bool { BetweenPreviewMode.enabled && !BetweenPreviewMode.live }
    private var deviceMarkers: [String: String] = [:]
    var discussionToken: ((String) -> String?)?
    @discardableResult
    func load(_ language: String, viewer: String = "guest") async -> Bool {
        revision += 1; let version = revision
        loadedViewer = viewer
        loadingMore = false
        pageError = false
        if preview {
            loadedLanguage = language
            sourceStories = Self.fixtures(language)
            if BetweenPreviewMode.device, !sourceStories.isEmpty {
                let zh = language == "zh"
                let reply = NativeReply(id:"fixture-incoming-reply",author:zh ? "阿岸":"Rowan",
                    text:zh ? "这个建议帮到我了，谢谢你。":"This helped me. Thank you.",authorID:"fixture-rowan",publicAuthorID:"R5W2A8")
                sourceStories[0].answers.append(NativeAnswer(id:"fixture-own-answer",author:zh ? "晚风":"Nightfall",
                    side:"angel",text:zh ? "可以先说你会想念对方。":"You could start by saying you’ll miss them.",likes:0,replies:[reply],mine:true))
            }
            return true
        }
        loading = true; error = false
        defer { if version == revision { loading = false } }
        do {
            let result = try await fetchPage(language:language,offset:0,viewer:viewer)
            guard version == revision, !Task.isCancelled else { return false }
            var ids = Set<String>()
            sourceStories = result.stories.filter { story in
                story.hoursRemaining() > 0 && !story.id.isEmpty && ids.insert(story.id).inserted
            }
            loadedLanguage = language
            nextOffset = result.next_offset.flatMap { $0 > 0 ? $0 : nil }
            return true
        } catch {
            if version == revision && !Task.isCancelled { self.error = true }
            return false
        }
    }
    private var refreshing = false

    func refresh(_ language: String, viewer: String) async -> Bool {
        guard !preview, !loading, !loadingMore, !refreshing else { return false }
        refreshing = true
        defer { refreshing = false }
        let version = revision
        do {
            let pages = max(1,(sourceStories.count+99)/100)
            var offset = 0
            var seen = Set<String>()
            var updated: [NativeStory] = []
            var next: Int?
            for _ in 0..<pages {
                let page = try await fetchPage(language:language,offset:offset,viewer:viewer)
                guard version == revision, !Task.isCancelled else { return false }
                updated += page.stories.filter { $0.hoursRemaining() > 0 && !$0.id.isEmpty && seen.insert($0.id).inserted }
                next = page.next_offset.flatMap { $0 > offset ? $0 : nil }
                guard let next else { break }
                offset = next
            }
            sourceStories = updated
            loadedLanguage = language
            loadedViewer = viewer
            nextOffset = next
            error = false
            return true
        } catch { return false }
    }

    func loadNext() async -> Bool {
        guard !preview, !refreshing, let offset = nextOffset, let language = loadedLanguage, !loadingMore, !loading else { return false }
        let version = revision
        loadingMore = true
        pageError = false
        defer { if version == revision { loadingMore = false } }
        do {
            var cursor = offset
            var seen = Set(sourceStories.map(\.id))
            for _ in 0..<5 {
                let result = try await fetchPage(language:language,offset:cursor,viewer:loadedViewer)
                guard version == revision, !Task.isCancelled else { return false }
                let next = result.next_offset.flatMap { $0 > cursor ? $0 : nil }
                let additions = result.stories.filter { story in
                    story.hoursRemaining() > 0 && !story.id.isEmpty && seen.insert(story.id).inserted
                }
                nextOffset = next
                if !additions.isEmpty {
                    sourceStories.append(contentsOf:additions)
                    return true
                }
                guard let next else { return false }
                cursor = next
            }
            return false
        } catch {
            if version == revision && !Task.isCancelled { pageError = true }
            return false
        }
    }

    private func fetchPage(language: String, offset: Int, viewer: String) async throws -> NativeFeed {
        guard let base = URL(string:apiBase), base.host != nil,
              var url = URLComponents(url:base.appendingPathComponent("stories"),resolvingAgainstBaseURL:false) else {
            throw URLError(.badURL)
        }
        url.queryItems = [URLQueryItem(name:"language",value:language),URLQueryItem(name:"scope",value:"feed"),URLQueryItem(name:"offset",value:String(offset))]
        guard let endpoint = url.url else { throw URLError(.badURL) }
        var request = URLRequest(url:endpoint,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:15)
        request.setValue(deviceMarker(viewer),forHTTPHeaderField:"X-Between-Device")
        try applyDiscussionSession(to:&request,viewer:viewer)
        request.httpShouldHandleCookies = false
        let (data,response) = try await session.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(NativeFeed.self,from:data)
    }

    private func deviceMarker(_ viewer: String) -> String {
        if let cached = deviceMarkers[viewer] { return cached }
        let key = "native.server-device.v1." + viewer
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey:key), saved.count == 43 {
            deviceMarkers[viewer] = saved
            return saved
        }
        var first = UUID().uuid
        var second = UUID().uuid
        var bytes = withUnsafeBytes(of:&first) { Data($0) }
        bytes.append(withUnsafeBytes(of:&second) { Data($0) })
        let marker = bytes.base64EncodedString().replacingOccurrences(of:"+",with:"-")
            .replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
        defaults.set(marker,forKey:key)
        deviceMarkers[viewer] = marker
        return marker
    }

    struct RemoteBlock: Decodable, Identifiable {
        let id: String
        let blockedAt: Double
    }

    struct ReportFeedback: Decodable, Identifiable {
        let id: String
        let outcome: String
        let message: String
    }

    func fetchReportFeedback(viewer: String) async throws -> [ReportFeedback] {
        struct Envelope: Decodable { let feedback: [ReportFeedback] }
        guard let base = URL(string:apiBase), base.host != nil else { throw URLError(.badURL) }
        var request = URLRequest(url:base.appendingPathComponent("feedback"),cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:15)
        request.httpShouldHandleCookies = false
        request.setValue(deviceMarker(viewer),forHTTPHeaderField:"X-Between-Device")
        try applyDiscussionSession(to:&request,viewer:viewer)
        let (data,response) = try await session.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Envelope.self,from:data).feedback
    }

    func fetchBlockedUsers(viewer: String) async throws -> [RemoteBlock] {
        struct BlockList: Decodable { let users: [RemoteBlock] }
        guard let base = URL(string:apiBase), base.host != nil else { throw URLError(.badURL) }
        var request = URLRequest(url:base.appendingPathComponent("blocked-users"),cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:15)
        request.httpShouldHandleCookies = false
        request.setValue(deviceMarker(viewer),forHTTPHeaderField:"X-Between-Device")
        try applyDiscussionSession(to:&request,viewer:viewer)
        let (data,response) = try await session.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(BlockList.self,from:data).users
    }

    struct MutationResult: Decodable {
        let ok: Bool
        let id: String?
        let pending: Bool?
    }

    struct MutationFailure: Error {
        let status: Int
    }

    func mutate(_ path: String, fields: [String:String], viewer: String) async throws -> MutationResult {
        guard let base = URL(string:apiBase), base.host != nil else { throw URLError(.badURL) }
        let endpoint = path.split(separator:"/").reduce(base) { $0.appendingPathComponent(String($1)) }
        var request = URLRequest(url:endpoint,timeoutInterval:25)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue(deviceMarker(viewer),forHTTPHeaderField:"X-Between-Device")
        try applyDiscussionSession(to:&request,viewer:viewer)
        request.httpBody = try JSONEncoder().encode(fields)
        let (data,response) = try await session.data(for:request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw MutationFailure(status:status) }
        let result = try JSONDecoder().decode(MutationResult.self,from:data)
        guard result.ok else { throw MutationFailure(status:status) }
        return result
    }

    private func applyDiscussionSession(to request: inout URLRequest, viewer: String) throws {
        guard viewer != "guest", !BetweenPreviewMode.enabled else { return }
        guard let token = discussionToken?(viewer) else { throw MutationFailure(status:401) }
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
    }

    static func officialExamples(_ language: String, created: Double) -> [NativeStory] {
        let entries: [(Int, String, String)] = [
            (4, "房东问我要不要续租。我喜欢楼下那个修车摊，也认识了邻居，可下一次涨租我是真扛不住。", "My landlord asked if I’m renewing. I know the neighbors now, and the bike repair guy downstairs knows me by name. One more rent hike and I’m out, though."),
            (12, "下班坐过了两站，耳机里还是那首歌。以前总把它发给一个人，现在连聊天框都找不着了。", "I missed my stop by two stations with the same song on repeat. I used to send it to someone. I can’t even find our chat now."),
            (27, "我爸学会发语音以后，一条能讲两分钟。我有时候开两倍速，听到他问我有没有好好吃饭，又切回来了。", "Dad learned to send voice notes. Two minutes each. I play them at double speed until he asks if I’ve been eating properly, then I slow it back down."),
            (43, "摊位隔壁的新店比我便宜两块。老客今天去那边买了，还隔着马路跟我招手。我笑着挥手，回家翻了一遍账本。", "The new stall charges less than I do. A regular bought from them today and waved at me across the street. I waved back, then went home and checked the books."),
            (58, "同事说团建唱歌不准带家属。我不是想带人，我是想知道不去行不行，总不能每回都借口猫吐了吧。", "My coworker said karaoke is staff only. I don’t want to bring anyone. I want to know if I can skip it without claiming my cat threw up again."),
            (81, "左耳听不清以后，我最怕别人边走边跟我讲话。叫他们再说一遍不难，难的是第三遍。", "Since losing some hearing in my left ear, I dread walk-and-talk conversations. Asking someone to repeat themselves isn’t hard. Asking a third time is."),
            (103, "我姐每次回来都买好多东西给孩子，我负责看牙、接放学。今天孩子画全家福，偏偏把我画得最小。", "My sister brings the kids gifts whenever she visits. I do the dentist and school pickups. Guess who got drawn smallest in today’s family portrait."),
            (129, "试了三次才做出像样的馒头，拍完照才想起我奶奶早就看不清手机了。寄过去又怕路上坏。", "It took me three tries to get the steamed buns right. I took a photo, then remembered my grandma can’t see her phone screen anymore. They’d go bad in the mail."),
            (156, "刚换了名字，老同学聚会还是喊我以前那个。我知道他们不见得有恶意，可我也没法当没听见。", "I changed my name recently. At the reunion everyone used the old one. They probably didn’t mean anything by it, but I couldn’t pretend not to hear it."),
            (190, "夜班保安大哥总给我留着侧门，今天听说他要被调走。想请他喝杯热的，又怕人家以为我有事求他。", "The night guard always leaves the side door open for me. He’s transferring. I want to bring him something hot to drink without making it look like I need a favor."),
            (226, "练了半年的贝斯，排练时还是追不上鼓。大家说下次再试，可我听得出来他们在等我自己开口退出。", "Six months on bass and I still can’t keep up with the drums. They say we’ll try again next week. It feels like they’re waiting for me to quit first."),
            (263, "退休以后我每天也定七点的闹钟。不定的话，醒来就不知道第一件事该做什么。", "I still set my alarm for seven since retiring. If I don’t, I wake up without a clue what to do first."),
            (302, "两个人合租，冰箱冻饺子可以随便吃，说好了的。但她这星期把我带回来的那盒也吃了，我妈包的。", "My roommate and I share whatever dumplings are in the freezer. That was the deal. This week she ate the ones I brought home. My mom made those."),
            (353, "周末去看球，儿子没上场。回家他倒挺乐呵，路上问我怎么不说话。我是不是比他还在意？", "My son sat on the bench the whole game. He was cheerful on the way home and asked why I was so quiet. Maybe I care about it more than he does."),
            (407, "看到以前一起跑外卖的伙计发了毕业照，点了赞，打的那句恭喜还是删了。我们都两年没说过话了。", "Someone I used to deliver food with posted graduation photos. I liked one, typed congrats, then deleted it. We haven’t spoken in two years."),
            (475, "想领养那只三条腿的狗。实话是，我连自己加班到几点都决定不了。每次路过救助站我还是会看一眼。", "I want to adopt the three-legged dog. Truth is, I don’t even get to decide when I leave work. I still look in every time I pass the shelter."),
            (548, "每次开会我都把想说的写在纸上。等轮到我，别人已经提过了。回工位的时候我还舍不得把纸扔掉。", "I write down what I want to say in meetings. By the time it’s my turn, someone else has said it. I still can’t quite throw the paper away."),
            (641, "和爸妈视频，我说这儿挺好，挂了电话才发现窗外下雪了。到这儿三个月，还没找到能顺手发张照片的人。", "I told my parents on video that things are good here. After hanging up I noticed it was snowing. Three months in, I still don’t have someone here I’d casually send a photo to."),
            (787, "二手平台有人来问旧相机，出价也合理。我回了一句还在，之后就一直没再点开。相机三年没用了。", "Someone made a fair offer for my old camera. I said it was still available and haven’t opened the chat since. I haven’t used it in three years."),
            (982, "邻居家孩子在练那首我考级时最讨厌的曲子。今天她终于没弹错，我差点在墙这边鼓掌。明天还得跟她家商量练琴时间。", "The kid next door is learning the piece I hated most at piano exams. Today she finally got it right and I almost applauded through the wall. I still need to ask her parents about practice hours tomorrow.")
        ]
        let zh = language == "zh"
        return entries.enumerated().map { index, entry in
            let label = zh ? "官方示例" : "Official example"
            return NativeStory(id:"example-\(index)",text:label + "\n" + (zh ? entry.1 : entry.2),
                created:created-Double(entry.0)*60_000,answers:[],author:label)
        }
    }

    static func fixtures(_ language:String,created:Double = Date().timeIntervalSince1970*1000) -> [NativeStory] {
        let zh = language == "zh"
        let titles = zh ? ["最好的朋友要搬去另一座城市了。我该告诉他，我其实很难过吗？","毕业后大家好像都有方向，只有我还不知道自己想过什么样的生活。","如果一个选择没有标准答案，我到底该听理智的，还是听自己的？","朋友每次约见面都迟到。我该直接告诉他这让我不舒服吗？","我想给自己放个周末，做家务和回消息却一直占满时间。我应该从哪件事开始拒绝？"] : ["My best friend is moving away. Do I tell them how much it hurts?","Everyone seems to have a plan after graduation. I still have no idea what kind of life I want.","When there is no right answer, do I trust my head or follow what I actually want?","My friend is always late when we meet. Should I tell them how it makes me feel?","I want one weekend to rest, but chores and messages always fill it. Where do I start saying no?"]
        return titles.enumerated().map { i,text in
            var answers = [
                NativeAnswer(id:"a\(i)",author:zh ? "小满":"Mia",side:"angel",text:zh ? "可以告诉他你会想念他，也约定下次见面的时间。难过和为他开心可以同时存在。":"Tell them you will miss them, and make a plan to stay close. You can be happy for them and sad about the distance at the same time.",likes:2,replies:[]),
                NativeAnswer(id:"d\(i)",author:zh ? "阿岸":"Rowan",side:"devil",text:zh ? "想说就说。装作没事并不会让告别好过一点，别等人走了才把真心话发给聊天框。":"Say it now. Pretending you are fine will not make the goodbye easier. Do not save the honest part for a message after they have already left.",likes:1,replies:[])
            ]
            if i >= 3 {
                let angel = i == 3
                    ? (zh ? "选个不赶时间的时候，说清楚你在意的是一直等，可以一起约一个更现实的时间。" : "Pick a quiet moment. Explain that waiting is hard for you, then agree on a time that works for both of you.")
                    : (zh ? "先留出两小时给自己，再决定哪些消息可以等到周一回。" : "Block out two hours for yourself, then pick which messages can wait until Monday.")
                let devil = i == 3
                    ? (zh ? "直接说下次只等十五分钟，之后就按自己的安排走。" : "Say you'll wait fifteen minutes next time, then go ahead with your own plans.")
                    : (zh ? "从关掉一个群的提醒开始。有些事不在周末做，也不会出什么问题。" : "Mute one group chat. Some things can sit untouched until the weekend is over.")
                answers = [
                    NativeAnswer(id:"a\(i)",author:zh ? "小满":"Mia",side:"angel",text:angel,likes:0,replies:[]),
                    NativeAnswer(id:"d\(i)",author:zh ? "阿岸":"Rowan",side:"devil",text:devil,likes:0,replies:[])
                ]
            }
            if i == 1 { answers.append(NativeAnswer(id:"extra-devil",author:zh ? "青禾":"June",side:"devil",text:zh ? "先试一件你真的好奇的事。别人有计划不代表你必须照着走。":"Try one thing you are actually curious about. Someone else's plan does not have to become your deadline.",likes:0,replies:[])) }
            for index in answers.indices {
                answers[index].authorID = answers[index].id == "extra-devil" ? "fixture-june"
                    : answers[index].side == "angel" ? "fixture-mia" : "fixture-rowan"
                answers[index].publicAuthorID = answers[index].id == "extra-devil" ? "J8N4C2"
                    : answers[index].side == "angel" ? "M7K2Q9" : "R5W2A8"
            }
            return NativeStory(id:"fixture-\(i)",text:text,created:created,answers:answers,
                author:i.isMultiple(of:2) ? (zh ? "小满":"Mia") : (zh ? "青禾":"June"),
                authorID:i.isMultiple(of:2) ? "fixture-mia":"fixture-june",
                publicAuthorID:i.isMultiple(of:2) ? "M7K2Q9":"J8N4C2")
        }
    }
}

enum BetweenPreviewMode {
    static var live: Bool {
        #if BETWEEN_LIVE_PLAYTEST
        return true
        #else
        return false
        #endif
    }

    static var device: Bool {
        #if BETWEEN_DEVICE_PREVIEW
        return true
        #else
        return false
        #endif
    }

    static var enabled: Bool {
        #if BETWEEN_DEVICE_PREVIEW || BETWEEN_LIVE_PLAYTEST
        return true
        #elseif DEBUG
        return ProcessInfo.processInfo.arguments.contains("-preview-fixture")
        #else
        return false
        #endif
    }
}


struct SharedMusicLink {
    let url: URL
    let platform: String
    let range: Range<String.Index>

    private static let urls = try! NSRegularExpression(pattern: #"https?://[^\s<>"，。！？；、）」】]+"#,options:.caseInsensitive)

    static func links(in text: String) -> [Self] {
        let trailing = CharacterSet(charactersIn:".,;!?)]}’”")
        return urls.matches(in:text,range:NSRange(text.startIndex...,in:text)).compactMap { match in
            guard let range = Range(match.range,in:text) else { return nil }
            let raw = text[range].trimmingCharacters(in:trailing)
            guard let url = URL(string:raw), let host = url.host?.lowercased(),
                  url.user == nil, url.password == nil,
                  ["http","https"].contains(url.scheme?.lowercased() ?? ""),
                  let platform = platform(host:host,url:url) else { return nil }
            return Self(url:url,platform:platform,
                        range:range.lowerBound..<text.index(range.lowerBound,offsetBy:raw.count))
        }
    }

    private static func platform(host: String,url: URL) -> String? {
        let path = url.path.lowercased()
        switch host {
        case "open.spotify.com": return path.range(of:#"/track/[^/]+"#,options:.regularExpression) != nil ? "Spotify" : nil
        case "spotify.link": return path.count > 1 ? "Spotify" : nil
        case "music.apple.com":
            return path.contains("/song/") || (path.contains("/album/") && URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.contains { $0.name == "i" && $0.value?.isEmpty == false } == true) ? "Apple Music" : nil
        case "music.163.com", "y.music.163.com":
            return path.contains("/song") || url.fragment?.hasPrefix("/song") == true || path.hasPrefix("/m/song") ? "网易云音乐" : nil
        case "163cn.tv": return path.count > 1 ? "网易云音乐" : nil
        case "y.qq.com", "i.y.qq.com", "c.y.qq.com":
            return path.contains("/song") || path.contains("songdetail") || path.contains("playsong") ? "QQ 音乐" : nil
        case "music.douyin.com":
            let track = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?
                .first { $0.name == "track_id" }?.value
            return path == "/qishui/share/track" && track?.isEmpty == false ? "汽水音乐" : nil
        case "qishui.douyin.com":
            return path.hasPrefix("/s/") && path.count > 3 ? "汽水音乐" : nil
        case "kuwo.cn", "www.kuwo.cn", "m.kuwo.cn", "h5.kuwo.cn":
            return path.hasPrefix("/play_detail/") || path.hasPrefix("/yinyue/")
                || path.hasPrefix("/song/") || path.contains("/single/") ? "酷我音乐" : nil
        case "www.kugou.com", "m.kugou.com", "www3.kugou.com", "t1.kugou.com", "t2.kugou.com":
            return path.contains("/song") || path.contains("/share") || path.count > 1 && host.hasPrefix("t") ? "酷狗音乐" : nil
        case "music.youtube.com":
            return path == "/watch" && URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.contains { $0.name == "v" && $0.value?.isEmpty == false } == true ? "YouTube Music" : nil
        case "soundcloud.com", "www.soundcloud.com":
            return url.pathComponents.count == 3 && !path.contains("/sets/") ? "SoundCloud" : nil
        case "on.soundcloud.com": return path.count > 1 ? "SoundCloud" : nil
        case "www.deezer.com", "deezer.com": return path.contains("/track/") ? "Deezer" : nil
        case "deezer.page.link", "link.deezer.com": return path.count > 1 ? "Deezer" : nil
        case "tidal.com", "listen.tidal.com": return path.contains("/track/") ? "TIDAL" : nil
        case "music.amazon.com": return path.contains("/tracks/") ? "Amazon Music" : nil
        case "streetvoice.com", "www.streetvoice.com": return path.contains("/songs/") ? "StreetVoice" : nil
        default: return nil
        }
    }
}


struct MusicDraft: Equatable {
    let id = UUID()
    let url: URL
    let platform: String
    var title = ""
    var artist = ""
    var showTitle = false

    struct Metadata: Decodable {
        let title: String?
        let artist: String?
    }

    static func clean(_ text: String) -> String {
        String(text.replacingOccurrences(of:"】",with:"")
            .components(separatedBy:.newlines).joined(separator:" ")
            .trimmingCharacters(in:.whitespacesAndNewlines).prefix(80))
    }

    func appending(to text: String) -> String {
        let title = Self.clean(self.title)
        let artist = Self.clean(self.artist)
        return [text,url.absoluteString,
            showTitle && !title.isEmpty ? "【歌曲名：\(title)】" : "",
            showTitle && !title.isEmpty && !artist.isEmpty ? "【歌手：\(artist)】" : ""]
            .filter { !$0.isEmpty }.joined(separator:"\n")
    }

    func lookup() async -> Metadata? {
        guard let base = URL(string:BetweenAPI.base),
              var link = URLComponents(url:base.appendingPathComponent("music-track"),resolvingAgainstBaseURL:false)
        else { return nil }
        link.queryItems = [URLQueryItem(name:"url",value:url.absoluteString)]
        guard let endpoint = link.url else { return nil }
        do {
            let (data,response) = try await URLSession.shared.data(for:URLRequest(url:endpoint,timeoutInterval:8))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(Metadata.self,from:data)
        } catch { return nil }
    }

    static func pasted(_ text: String, link: SharedMusicLink) -> (MusicDraft,String) {
        var draft = MusicDraft(url:link.url,platform:link.platform)
        let copy = text.replacingCharacters(in:link.range,with:"")
        var lines = copy.components(separatedBy:.newlines)
        if let index = lines.firstIndex(where: {
            let line = $0.trimmingCharacters(in:.whitespaces)
            return line.hasPrefix("歌曲名：") || line.hasPrefix("分享《") || line.hasPrefix("分享歌曲《")
        }) {
            let line = lines[index].trimmingCharacters(in:.whitespaces)
            if line.hasPrefix("歌曲名：") {
                draft.title = clean(String(line.dropFirst(4)))
            } else if let opening = line.firstIndex(of:"《"), let closing = line.firstIndex(of:"》"), opening < closing {
                draft.title = clean(String(line[line.index(after:opening)..<closing]))
                let suffix = line[line.index(after:closing)...].trimmingCharacters(in:CharacterSet(charactersIn:" -—–·"))
                draft.artist = clean(suffix)
            }
            if !draft.title.isEmpty {
                lines.remove(at:index)
                if let artist = lines.firstIndex(where:{ $0.trimmingCharacters(in:.whitespaces).hasPrefix("歌手：") }) {
                    draft.artist = clean(String(lines.remove(at:artist).trimmingCharacters(in:.whitespaces).dropFirst(3)))
                }
                draft.showTitle = true
            }
        }
        return (draft,lines.joined(separator:"\n").trimmingCharacters(in:.whitespacesAndNewlines))
    }

    static func display(_ text: String) -> (body: String, link: SharedMusicLink?, title: String?, artist: String?) {
        var lines = text.components(separatedBy:"\n")
        func take(_ prefix: String) -> String? {
            guard let line = lines.last, line.hasPrefix(prefix), line.hasSuffix("】") else { return nil }
            lines.removeLast()
            return clean(String(line.dropFirst(prefix.count).dropLast()))
        }
        let artist = take("【歌手：")
        let title = take("【歌曲名：")
        let body = lines.joined(separator:"\n")
        guard let link = SharedMusicLink.links(in:body).first else { return (text,nil,nil,nil) }
        return (body.replacingCharacters(in:link.range,with:"").trimmingCharacters(in:.whitespacesAndNewlines),
                link,title,artist)
    }
}
