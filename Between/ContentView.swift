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
        LinearGradient(colors: [Color(red: 0.961, green: 0.667, blue: 0.655), Color(red: 0.973, green: 0.82, blue: 0.769), Color(red: 0.965, green: 0.898, blue: 0.863), Color(red: 0.863, green: 0.922, blue: 0.949), Color(red: 0.718, green: 0.851, blue: 0.922)], startPoint: .leading, endPoint: .trailing)
    }
    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Text("between.").font(.system(size: 23, weight: .heavy, design: .rounded)).foregroundColor(Color(red: 0.26, green: 0.21, blue: 0.25))
                    Spacer()
                    Button(chinese ? "EN" : "中") { language = chinese ? "en" : "zh"; side = nil; Task { await model.load(language) } }
                        .font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44).background(.white.opacity(0.55), in: Circle())
                }.padding(.horizontal, 24)
                Text(chinese ? "原生预览 · 功能开发中" : "NATIVE PREVIEW · WORK IN PROGRESS")
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
                    else { RoundedRectangle(cornerRadius: 30).fill(.white.opacity(0.82)).overlay(Text(chinese ? "暂时没有烦恼" : "No stories yet").foregroundColor(.secondary)) }
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
        .task {
            if ProcessInfo.processInfo.arguments.contains("-preview-fixture") {
                model.stories = [Story(id: "preview", text: "My best friend is moving away. Do I tell them how much it hurts?", created: 0, answers: [])]
            } else { await model.load(language) }
        }
    }
    @ViewBuilder private func storyCard(_ story: Story) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(LinearGradient(colors: [.white.opacity(0.93), Color(red: 1, green: 0.973, blue: 0.957).opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.8), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.65), lineWidth: 1).padding(7))
                .shadow(color: Color(red: 0.65, green: 0.41, blue: 0.45).opacity(0.17), radius: 24, y: 14)
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
                        Text(story.text).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(Color(red: 0.19, green: 0.17, blue: 0.19)).multilineTextAlignment(.center)
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
    @State private var blink = false
    @State private var floating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var face: Color { angel ? Color(red: 0.608, green: 0.784, blue: 0.863) : Color(red: 0.914, green: 0.576, blue: 0.525) }
    private var ink: Color { angel ? Color(red: 0.259, green: 0.404, blue: 0.475) : Color(red: 0.38, green: 0.278, blue: 0.294) }
    var body: some View {
        ZStack {
            if angel {
                HStack(spacing: 42) { Ellipse(); Ellipse() }.fill(Color(red: 1, green: 0.992, blue: 0.973)).frame(width: 72, height: 25).offset(y: 7)
            } else {
                HStack(spacing: 25) {
                    RoundedRectangle(cornerRadius: 9).rotationEffect(.degrees(-25))
                    RoundedRectangle(cornerRadius: 9).rotationEffect(.degrees(25))
                }.fill(Color(red: 0.835, green: 0.431, blue: 0.404)).frame(width: 58, height: 22).offset(y: -25)
            }
            Ellipse().fill(face).frame(width: 62, height: 60).shadow(color: ink.opacity(0.14), radius: 5, y: 4)
            HStack(spacing: 12) { Capsule().frame(width: 8, height: 2); Capsule().frame(width: 8, height: 2) }.foregroundColor(ink.opacity(0.68)).offset(y: -10)
            HStack(spacing: 14) { Ellipse().frame(width: 6, height: blink ? 1 : 10); Ellipse().frame(width: 6, height: blink ? 1 : 10) }.foregroundColor(ink).offset(y: 0)
            Smile().stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round)).frame(width: 12, height: 7).offset(y: 14)
            if angel { Ellipse().stroke(Color(red: 0.902, green: 0.741, blue: 0.459), lineWidth: 4).frame(width: 42, height: 11).rotationEffect(.degrees(-8)).offset(y: -38) }
        }
        .frame(width: 82, height: 82)
        .offset(y: floating ? -3 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: angel ? 3.7 : 2.6).repeatForever(autoreverses: true)) { floating = true }
            Timer.scheduledTimer(withTimeInterval: angel ? 3.4 : 2.8, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.1)) { blink = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { withAnimation(.easeInOut(duration: 0.1)) { blink = false } }
            }
        }
        .accessibilityLabel(angel ? "Angel" : "Devil")
    }
}
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: CGPoint(x: 0, y: 0)); path.addQuadCurve(to: CGPoint(x: rect.width, y: 0), control: CGPoint(x: rect.midX, y: rect.height * 1.4)); return path
    }
}
