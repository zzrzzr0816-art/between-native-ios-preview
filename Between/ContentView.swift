import SwiftUI

private struct Answer: Decodable, Identifiable {
    let id: String
    let author: String
    let side: String
    let text: String
}
private struct Story: Decodable, Identifiable {
    let id: String
    let text: String
    let created: Double
    let answers: [Answer]
}
private struct Feed: Decodable { let stories: [Story] }

@MainActor
private final class FeedModel: ObservableObject {
    @Published var stories: [Story] = []
    @Published var loading = false
    @Published var error = false
    @Published var index = 0
    var current: Story? { stories.indices.contains(index) ? stories[index] : nil }
    func load(_ language: String) async {
        loading = true; error = false
        defer { loading = false }
        do {
            var components = URLComponents(string: "https://minglimaster.com/between/api/stories")!
            components.queryItems = [URLQueryItem(name: "language", value: language), URLQueryItem(name: "scope", value: "feed"), URLQueryItem(name: "offset", value: "0")]
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
            let result = try JSONDecoder().decode(Feed.self, from: data)
            stories = result.stories; index = 0
        } catch { self.error = true }
    }
    func move(_ delta: Int) { guard !stories.isEmpty else { return }; index = min(max(index + delta, 0), stories.count - 1) }
}

struct ContentView: View {
    @StateObject private var model = FeedModel()
    @State private var language = "en"
    @State private var side: String? = nil
    @GestureState private var translation: CGSize = .zero
    private var chinese: Bool { language == "zh" }
    private var gradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.96, green: 0.68, blue: 0.66), Color(red: 0.98, green: 0.88, blue: 0.81), Color(red: 0.76, green: 0.88, blue: 0.93)], startPoint: .leading, endPoint: .trailing)
    }
    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Text("between.").font(.system(size: 31, weight: .heavy, design: .rounded))
                    Spacer()
                    Button(chinese ? "EN" : "中") { language = chinese ? "en" : "zh"; side = nil; Task { await model.load(language) } }
                        .font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44).background(.white.opacity(0.55), in: Circle())
                }.padding(.horizontal, 24)
                Text(chinese ? "原生首页预览 · 功能开发中" : "NATIVE PREVIEW · WORK IN PROGRESS")
                    .font(.caption).foregroundColor(.black.opacity(0.48))
                HStack {
                    Mascot(angel: false).opacity(side == "angel" ? 0.15 : 1).scaleEffect(side == "devil" ? 1.15 : 1)
                    Spacer()
                    Mascot(angel: true).opacity(side == "devil" ? 0.15 : 1).scaleEffect(side == "angel" ? 1.15 : 1)
                }.padding(.horizontal, 35).frame(height: 82)
                Group {
                    if model.loading { ProgressView() }
                    else if model.error { VStack(spacing: 14) { Text(chinese ? "暂时无法加载" : "Could not load stories"); Button(chinese ? "重试" : "Retry") { Task { await model.load(language) } } } }
                    else if let story = model.current { storyCard(story) }
                    else { Text(chinese ? "暂时没有烦恼" : "No stories yet") }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Label(chinese ? "烦恼" : "Stories", systemImage: "house")
                    Spacer()
                    Text(chinese ? "发布 · 开发中" : "Post · soon").foregroundColor(.secondary)
                    Spacer()
                    Text(chinese ? "我的 · 开发中" : "Me · soon").foregroundColor(.secondary)
                }.font(.caption).padding(.horizontal, 30).padding(.vertical, 16)
                 .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22))
            }.padding(.top, 8).padding(.horizontal, 12)
        }
        .task { await model.load(language) }
    }
    @ViewBuilder private func storyCard(_ story: Story) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30).fill(.white.opacity(0.85))
            if let selected = side {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button { withAnimation(.easeInOut(duration: 0.25)) { side = nil } } label: { Image(systemName: "chevron.left").padding(8) }
                        Text(selected == "devil" ? (chinese ? "恶魔的建议" : "Devil's side") : (chinese ? "天使的建议" : "Angel's side")).font(.headline)
                        Spacer()
                    }
                    ScrollView {
                        let answers = story.answers.filter { $0.side == selected }
                        if answers.isEmpty { Text(chinese ? "还没有建议" : "No responses yet").foregroundColor(.secondary).padding() }
                        ForEach(answers) { answer in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(answer.author).font(.caption.bold()).foregroundColor(.secondary)
                                Text(answer.text).frame(maxWidth: .infinity, alignment: .leading)
                            }.padding().background(.white, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }.padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 26) {
                        Text("✦").font(.largeTitle).foregroundColor(.pink.opacity(0.6))
                        Text(story.text).font(.system(size: 25, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                        Text(chinese ? "左右滑动，看不同的建议" : "Swipe left or right for another perspective")
                            .font(.footnote).foregroundColor(.secondary)
                        Text("\(model.index + 1) / \(model.stories.count)").font(.caption).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(26)
                }.frame(maxHeight: .infinity)
            }
        }
        .offset(x: translation.width * 0.14, y: translation.height * 0.08)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 18).updating($translation) { value, state, _ in state = value.translation }.onEnded { value in
            let x = value.translation.width, y = value.translation.height
            withAnimation(.easeInOut(duration: 0.25)) {
                if abs(x) > abs(y), abs(x) > 70 { side = side == nil ? (x < 0 ? "devil" : "angel") : nil }
                else if side == nil, abs(y) > 70 { model.move(y < 0 ? 1 : -1) }
            }
        })
    }
}

private struct Mascot: View {
    let angel: Bool
    var body: some View {
        ZStack {
            if angel {
                Ellipse().stroke(Color.yellow.opacity(0.8), lineWidth: 4).frame(width: 52, height: 13).offset(y: -45).rotationEffect(.degrees(-10))
            } else {
                HStack(spacing: 24) { Image(systemName: "triangle.fill"); Image(systemName: "triangle.fill") }.font(.system(size: 20)).foregroundColor(.red.opacity(0.65)).offset(y: -36)
            }
            Circle().fill(angel ? Color(red: 0.52, green: 0.76, blue: 0.84) : Color(red: 0.91, green: 0.53, blue: 0.50)).frame(width: 70, height: 70)
            HStack(spacing: 16) { Capsule().frame(width: 7, height: 12); Capsule().frame(width: 7, height: 12) }.offset(y: -4)
            Text("⌣").font(.system(size: 21, weight: .bold)).offset(y: 12)
        }.foregroundColor(Color.black.opacity(0.55)).accessibilityLabel(angel ? "Angel" : "Devil")
    }
}
