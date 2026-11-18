import SwiftUI

struct NativeReply: Codable { let id: String?; let author: String; let text: String }
struct NativeAnswer: Codable, Identifiable {
    let id: String
    let author: String
    let side: String
    let text: String
    var likes: Int
    var replies: [NativeReply]
}
struct NativeStory: Codable, Identifiable {
    let id: String
    let text: String
    var detail: String? = nil
    let created: Double
    var answers: [NativeAnswer]
}
struct NativeLocalState: Codable {
    var localStories: [NativeStory] = []
    var snapshots: [NativeStory] = []
    var reports: [String] = []
    var hidden: [String] = []
    var liked: [String: Bool] = [:]
    var best: [String: String] = [:]
    var updates: [String: [String]] = [:]
    var replies: [String: [NativeReply]] = [:]
    var myAnswers: [String: [NativeAnswer]] = [:]
    var reviewed: [String]? = nil
}
struct NativeFeed: Decodable { let stories: [NativeStory]; let next_offset: Int? }
enum NativeCamp: String {
    case devil, angel
    var accent: Color { Color(hex: self == .devil ? 0xc6786d : 0x628fa9) }
    var background: Color { Color(hex: self == .devil ? 0xfff2ef : 0xeef8ff) }
    var sign: CGFloat { self == .devil ? -1 : 1 }
}
@MainActor final class NativeFeedModel: ObservableObject {
    @Published var stories: [NativeStory] = []
    @Published var loading = false
    @Published var error = false
    @Published var index = 0
    @Published var nextOffset: Int? = nil
    @Published var loadingMore = false
    private var revision = 0
    var current: NativeStory? { stories.indices.contains(index) ? stories[index] : nil }
    var preview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-preview-fixture")
        #else
        return false
        #endif
    }
    func load(_ language: String) async {
        revision += 1; let version = revision
        if preview { stories = Self.fixtures(language); index = 0; return }
        loading = true; error = false
        do {
            var url = URLComponents(string: "https://minglimaster.com/between/api/stories")!
            url.queryItems = [URLQueryItem(name:"language",value:language),URLQueryItem(name:"scope",value:"feed"),URLQueryItem(name:"offset",value:"0")]
            let (data,response) = try await URLSession.shared.data(from:url.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let result = try JSONDecoder().decode(NativeFeed.self,from:data)
            guard version == revision else { return }
            let previous = current?.id
            stories = result.stories.filter { $0.created/1000+86400 > Date().timeIntervalSince1970 }
            nextOffset = result.next_offset
            index = previous.flatMap { id in stories.firstIndex { $0.id == id } } ?? 0
        } catch { if version == revision { self.error = true } }
        if version == revision { loading = false }
    }
    func loadNext(_ language: String) async {
        guard !preview, let offset = nextOffset, !loadingMore, !loading else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            var url = URLComponents(string: "https://minglimaster.com/between/api/stories")!
            url.queryItems = [URLQueryItem(name:"language",value:language),URLQueryItem(name:"scope",value:"feed"),URLQueryItem(name:"offset",value:"\(offset)")]
            let (data,response) = try await URLSession.shared.data(from:url.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let result = try JSONDecoder().decode(NativeFeed.self,from:data)
            nextOffset = result.next_offset
            let now = Date().timeIntervalSince1970
            for story in result.stories where story.created/1000+86400 > now && !stories.contains(where:{$0.id==story.id}) {
                stories.append(story)
            }
        } catch { nextOffset = nil }
    }
    static func fixtures(_ language:String) -> [NativeStory] {
        let zh = language == "zh"
        let titles = zh ? ["最好的朋友要搬去另一座城市了。我该告诉他，我其实很难过吗？","毕业后大家好像都有方向，只有我还不知道自己想过什么样的生活。","如果一个选择没有标准答案，我到底该听理智的，还是听自己的？"] : ["My best friend is moving away. Do I tell them how much it hurts?","Everyone seems to have a plan after graduation. I still have no idea what kind of life I want.","When there is no right answer, do I trust my head or follow what I actually want?"]
        return titles.enumerated().map { i,text in
            var answers = [
                NativeAnswer(id:"a\(i)",author:zh ? "小满":"Mia",side:"angel",text:zh ? "可以告诉他你会想念他，也约定下次见面的时间。难过和为他开心可以同时存在。":"Tell them you will miss them, and make a plan to stay close. You can be happy for them and sad about the distance at the same time.",likes:2,replies:[]),
                NativeAnswer(id:"d\(i)",author:zh ? "阿岸":"Rowan",side:"devil",text:zh ? "想说就说。装作没事并不会让告别好过一点，别等人走了才把真心话发给聊天框。":"Say it now. Pretending you are fine will not make the goodbye easier. Do not save the honest part for a message after they have already left.",likes:1,replies:[])
            ]
            if i == 1 { answers.append(NativeAnswer(id:"extra-devil",author:zh ? "青禾":"June",side:"devil",text:zh ? "先试一件你真的好奇的事。别人有计划不代表你必须照着走。":"Try one thing you are actually curious about. Someone else's plan does not have to become your deadline.",likes:0,replies:[])) }
            return NativeStory(id:"fixture-\(i)",text:text,created:Date().timeIntervalSince1970*1000,answers:answers)
        }
    }
}
