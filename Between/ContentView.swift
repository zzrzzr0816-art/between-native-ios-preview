import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @StateObject var model = NativeFeedModel()
    @AppStorage("native.language") var language = "en"
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var camp: NativeCamp? = nil
    @State var campProgress: CGFloat = 0
    @State var axis: Int? = nil
    @State var verticalTarget: Int? = nil
    @State var verticalProgress: CGFloat = 0
    @State var verticalSign: CGFloat = -1
    @State var edgeOffset: CGFloat = 0
    @State var settling = false
    @State var composer = ""
    @State var utility: String? = nil
    @State var selectedReply: NativeAnswer? = nil
    @State var replyText = ""
    @State var snapshots: [NativeStory] = []
    @State var reports: [String] = []
    @State var hidden: [String] = []
    @State var liked: [String:Bool] = [:]
    @State var best: [String:String] = [:]
    @State var updates: [String:[String]] = [:]
    @State var detailStory: NativeStory? = nil
    @State var reportReason = "harassment"
    @State var keyboardHeight: CGFloat = 0
    @State var toastText: String? = nil
    @State var writePeek: NativeCamp = .devil
    @State var hintVisible = false
    @State var hintToken = 0
    @State var guideVisible = false
    @State var composerHeight: CGFloat = 48
    @State var replyHeight: CGFloat = 46
    @State var likePulse: [String: Bool] = [:]
    @State var reportType = "story"
    @State var reportId = ""
    @State var snapshotStory: NativeStory? = nil
    @State var reviewed: [String] = []
    private static let expiryTimer = Timer.publish(every:1,on:.main,in:.common).autoconnect()
    @AppStorage("native.motion") var motionOn = true
    @FocusState var composerFocused: Bool
    var zh: Bool { language == "zh" }
    func l(_ a:String,_ b:String)->String { zh ? a:b }
    var transitionAnimation: Animation? { (reduceMotion || !motionOn) ? nil:H5Design.settling }
    var devilCount:Int { model.current?.answers.filter { $0.side == "devil" }.count ?? 0 }
    var angelCount:Int { model.current?.answers.filter { $0.side == "angel" }.count ?? 0 }
    var body: some View {
        GeometryReader { proxy in
            let top = proxy.safeAreaInsets.top, bottom = proxy.safeAreaInsets.bottom
            let w = proxy.size.width, h = proxy.size.height+top+bottom
            ZStack(alignment:.topLeading) {
                H5Design.background
                homeHeader(width:w,top:top)
                feed(width:w,area:h-265).frame(width:w,height:h-265).position(x:w/2,y:100+(h-265)/2)
                idleHints(width:w,height:h,bottom:bottom)
                bottomNav(width:w,height:h,bottom:bottom)
                if let chosen = camp {
                    Color.black.opacity(0.12*Double(campProgress)).allowsHitTesting(false).zIndex(detailStory != nil ? 22.5:0.5)
                    comments(chosen,width:w,height:h,top:top,bottom:bottom).offset(x:-chosen.sign*w*(1-campProgress)).allowsHitTesting((campProgress>0.99 || axis==2) && !settling).zIndex(detailStory != nil ? 23:2)
                }
                companions(width:w,top:top,height:h).zIndex(companionsLayer)
                if let page = utility, page == "write" || page == "more" {
                    Color(hex:0x302532).opacity(0.40).zIndex(detailStory != nil ? 23.5:5).contentShape(Rectangle()).onTapGesture{closeUtility()}.transition(.opacity)
                }
                if let page = utility { utilityPage(page,width:w,height:h,top:top,bottom:bottom).zIndex(detailStory != nil ? 24:10).transition(.opacity.combined(with:.offset(y:12))) }
                if let answer = selectedReply { replyOverlay(answer,width:w,height:h,top:top,bottom:bottom).zIndex(27).transition(.scale(scale:0.94,anchor:.bottomTrailing).combined(with:.opacity)) }
                if let story = detailStory { detailPage(story,width:w,height:h,top:top,bottom:bottom).zIndex(22).transition(.scale(scale:0.96).combined(with:.opacity)) }
                if detailStory != nil && camp == nil && utility == nil { detailHandles(width:w,height:h).zIndex(26) }
                if let story = snapshotStory { snapshotPage(story,width:w,height:h,top:top,bottom:bottom).zIndex(22).transition(.opacity) }
                if guideVisible { guideCard(width:w,bottom:bottom).zIndex(29) }
                if let text = toastText { toastView(text,bottom:bottom).zIndex(30) }
            }.frame(width:w,height:h).clipped().offset(y:-top)
                .animation(reduceMotion ? nil:.easeInOut(duration:0.45),value:devilCount)
                .animation(reduceMotion ? nil:.easeInOut(duration:0.45),value:angelCount)
        }.foregroundColor(H5Design.ink).tint(H5Design.ink).buttonStyle(.plain)
            .task { if ProcessInfo.processInfo.arguments.contains("-ui-zh"){language="zh"};await model.load(language);restoreLocal();applyPreviewRoute();resetIdleHints();scheduleGuide() }
            .onReceive(Self.expiryTimer){ _ in pruneExpired() }
            .onReceive(NotificationCenter.default.publisher(for:UIResponder.keyboardWillChangeFrameNotification)){ note in
                guard let frame=note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else{return}
                keyboardHeight=max(0,UIScreen.main.bounds.height-frame.origin.y)
            }
            .onReceive(NotificationCenter.default.publisher(for:UIResponder.keyboardWillHideNotification)){ _ in keyboardHeight=0 }
    }
    func applyPreviewRoute(){
        let args=ProcessInfo.processInfo.arguments
        if args.contains("-ui-profile") {utility = "profile"}
        if args.contains("-ui-write") {utility = "write"}
        if args.contains("-ui-more") {utility = "more"}
        if args.contains("-ui-comments") {camp = .angel; campProgress = 1}
        if args.contains("-ui-reply") {camp = .angel; campProgress = 1; selectedReply = model.current?.answers.first{$0.side=="angel"}}
        if args.contains("-ui-detail") {detailStory = model.current}
    }
    func toast(_ text:String){
        withAnimation(reduceMotion || !motionOn ? nil:.easeOut(duration:0.2)){toastText=text}
        DispatchQueue.main.asyncAfter(deadline:.now()+2.5){if toastText==text{withAnimation(nil){toastText=nil}}}
    }
    func toastView(_ text:String,bottom:CGFloat)->some View {
        Text(text).font(.system(size:12)).foregroundColor(.white).padding(.horizontal,18).padding(.vertical,11)
            .background(Color(hex:0x443a43),in:Capsule()).fixedSize()
            .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.bottom).padding(.bottom,120+bottom).allowsHitTesting(false)
            .transition(.opacity)
    }
    func restoreLocal(){
        guard let data=UserDefaults.standard.data(forKey:"native.local.v1"),let state=try? JSONDecoder().decode(NativeLocalState.self,from:data) else{return}
        snapshots=state.snapshots;reports=state.reports;hidden=state.hidden;liked=state.liked;best=state.best;updates=state.updates;reviewed=state.reviewed ?? []
        let local=state.localStories.filter{!hidden.contains($0.id) && $0.created/1000+86400 > Date().timeIntervalSince1970}
        if !local.isEmpty { model.stories.insert(contentsOf:local,at:0) }
        model.stories.removeAll{hidden.contains($0.id) || (!$0.id.hasPrefix("local-") && $0.created/1000+86400 <= Date().timeIntervalSince1970)}
        for (sid,answers) in state.myAnswers { guard let si=model.stories.firstIndex(where:{$0.id==sid}) else{continue}
            for a in answers where !model.stories[si].answers.contains(where:{$0.id==a.id}) { model.stories[si].answers.append(a) } }
        for (aid,reps) in state.replies { for si in model.stories.indices {
            guard let ai=model.stories[si].answers.firstIndex(where:{$0.id==aid}) else{continue}
            for r in reps where !model.stories[si].answers[ai].replies.contains(where:{$0.id==r.id}) { model.stories[si].answers[ai].replies.append(r) } } }
    }
    func persistLocal(){
        var state=NativeLocalState()
        state.localStories=model.stories.filter{$0.id.hasPrefix("local-")}
        state.snapshots=snapshots;state.reports=reports;state.hidden=hidden;state.liked=liked;state.best=best;state.updates=updates
        state.myAnswers=Dictionary(uniqueKeysWithValues:model.stories.map{($0.id,$0.answers.filter{$0.author==l("你 · 预览","You · preview")})}.filter{!$0.1.isEmpty})
        state.reviewed=reviewed
        var reps:[String:[NativeReply]]=[:]
        for story in model.stories { for a in story.answers where a.author==l("你 · 预览","You · preview") || !a.replies.isEmpty { reps[a.id]=a.replies } }
        state.replies=reps.filter{!$0.value.isEmpty}
        if let data=try? JSONEncoder().encode(state){UserDefaults.standard.set(data,forKey:"native.local.v1")}
    }
    func homeHeader(width:CGFloat,top:CGFloat)->some View {
        ZStack(alignment:.topLeading) {
            (Text("between").foregroundColor(Color(hex:0x42353f))+Text(".").foregroundColor(Color(hex:0xe0776e))).font(.system(size:23,weight:.heavy)).tracking(-1.5).frame(height:42).position(x:69,y:top+37)
            HStack(spacing:7){
                Button(zh ? "中文":"EN"){language=zh ? "en":"zh";Task{await model.load(language);restoreLocal()}}.accessibilityLabel("Switch language")
                Button {withAnimation(transitionAnimation){utility="more"}} label:{Text("•••")}.accessibilityLabel(l("更多","More"))
            }.font(.system(size:14)).buttonStyle(HeaderButtonStyle()).position(x:width-67.5,y:top+37)
            Text(l("交互原型 · 内容仅保存在当前浏览器","PROTOTYPE · Data stays in this browser")).font(.system(size:10)).foregroundColor(Color(hex:0x89757b)).frame(width:width).position(x:width/2,y:top+72.5)
        }.opacity(1-Double(campProgress)).allowsHitTesting(campProgress<0.01)
    }
    func feed(width:CGFloat,area:CGFloat)->some View {
        ZStack {
            if let story=model.current {
                let cardH=H5Design.cardHeight(story.text,width:width,available:area)
                let next=verticalTarget.flatMap {model.stories.indices.contains($0) ? model.stories[$0]:nil}
                let nextH=next.map {H5Design.cardHeight($0.text,width:width,available:area)} ?? cardH
                let travel=H5Design.verticalTravel(area:area,current:cardH,next:nextH)
                storyCard(story,width:width,height:cardH,interactive:true).scaleEffect(1-0.025*campProgress).offset(x:(camp?.sign ?? 0)*width*0.3*campProgress,y:verticalSign*travel*verticalProgress+edgeOffset).opacity(1-Double(H5Design.fade(verticalProgress)))
                if let nextStory=next {storyCard(nextStory,width:width,height:nextH).offset(y:-verticalSign*travel*(1-verticalProgress)).opacity(Double(H5Design.fade(verticalProgress))).allowsHitTesting(false)}
                Text("\(model.index+1) / \(model.stories.count)").font(.system(size:11)).tracking(2).foregroundColor(Color(hex:0x8c787f)).rotationEffect(.degrees(90)).position(x:width-24,y:area/2)
            } else if model.loading {ProgressView().tint(H5Design.muted)}
            else {VStack(spacing:14){Text(model.error ? l("暂时无法加载","Could not load stories"):l("暂时没有烦恼","No more stories to show")).font(.system(size:24,weight:.bold));if model.error {Button(l("重试","Retry")){Task{await model.load(language)}}}}.padding(30).background(H5Design.card,in:RoundedRectangle(cornerRadius:30))}
        }.frame(width:width,height:area).contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance:8).onChanged{value in feedChanged(value,width:width,area:area)}.onEnded{value in feedEnded(value,width:width,area:area)})
            .mask(LinearGradient(stops:[.init(color:.clear,location:0),.init(color:.black,location:0.035),.init(color:.black,location:0.965),.init(color:.clear,location:1)],startPoint:.top,endPoint:.bottom))
    }
    func feedChanged(_ value:DragGesture.Value,width:CGFloat,area:CGFloat){
        guard !settling,utility==nil,selectedReply==nil else{return}
        resetIdleHints()
        if axis==nil {axis=abs(value.translation.width)>abs(value.translation.height) ? 0:1}
        if axis==0 {camp=value.translation.width<0 ? .devil:.angel;campProgress=min(1,abs(value.translation.width)/width)}
        else if campProgress==0,let story=model.current {
            let sign:CGFloat=value.translation.height<0 ? -1:1,target=model.index+(sign<0 ? 1:-1)
            if model.stories.indices.contains(target){
                verticalSign=sign;verticalTarget=target
                let a=H5Design.cardHeight(story.text,width:width,available:area),b=H5Design.cardHeight(model.stories[target].text,width:width,available:area)
                verticalProgress=H5Design.verticalProgress(raw:value.translation.height,travel:H5Design.verticalTravel(area:area,current:a,next:b));edgeOffset=0
            } else {verticalTarget=nil;edgeOffset=sign*32*(1-exp(-abs(value.translation.height)/100));if abs(value.translation.height)>40 {toast(l("这是最后一条啦","You’re all caught up"))}}
        }
    }
    func feedEnded(_ value:DragGesture.Value,width:CGFloat,area:CGFloat){
        guard !settling else{return}
        if axis==0 {
            let commit=abs(value.translation.width)>max(65,width*0.23);settling=true
            withAnimation(transitionAnimation){campProgress=commit ? 1:0}
            DispatchQueue.main.asyncAfter(deadline:.now()+0.35){if !commit {camp=nil};axis=nil;settling=false}
        } else if let target=verticalTarget,let story=model.current {
            let a=H5Design.cardHeight(story.text,width:width,available:area),b=H5Design.cardHeight(model.stories[target].text,width:width,available:area)
            let travel=H5Design.verticalTravel(area:area,current:a,next:b)
            let commit=abs(value.translation.height)>max(65,travel*0.16) || (abs(value.translation.height)>35 && abs(value.predictedEndTranslation.height)>travel*0.5)
            settling=true
            withAnimation(reduceMotion ? nil:.interpolatingSpring(stiffness:170,damping:23)){verticalProgress=commit ? 1:0}
            DispatchQueue.main.asyncAfter(deadline:.now()+0.55){var transaction=Transaction();transaction.disablesAnimations=true;withTransaction(transaction){if commit {model.index=target;if model.index>=model.stories.count-2,model.nextOffset != nil {Task{await model.loadNext(language)}}};verticalTarget=nil;verticalProgress=0;axis=nil;settling=false}}
        } else {withAnimation(transitionAnimation){edgeOffset=0};axis=nil}
    }
    func storyCard(_ story:NativeStory,width:CGFloat,height:CGFloat,interactive:Bool = false)->some View {
        let hours = max(0,Int(ceil((story.created/1000+86400-Date().timeIntervalSince1970)/3600)))
        let long = story.text.count > 180
        return VStack(spacing:0){
            Text("✦").font(.system(size:27)).foregroundColor(Color(hex:0xd7958c)).frame(height:32).padding(.top,34)
            if long {
                ScrollView(.vertical,showsIndicators:false){
                    Text(story.text).font(.system(size:H5Design.titleSize(width),weight:.bold)).tracking(-0.8).lineSpacing(max(0,H5Design.titleSize(width)*1.35-UIFont.systemFont(ofSize:H5Design.titleSize(width),weight:.bold).lineHeight)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity)
                }.frame(maxHeight:H5Design.titleSize(width)*4.05).padding(.top,20)
                Text(l("上下拖动阅读全文","Drag to read")).font(.system(size:11)).foregroundColor(H5Design.muted).padding(.top,8)
            } else {
                Text(story.text).font(.system(size:H5Design.titleSize(width),weight:.bold)).tracking(-0.8).lineSpacing(max(0,H5Design.titleSize(width)*1.35-UIFont.systemFont(ofSize:H5Design.titleSize(width),weight:.bold).lineHeight)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.top,20).frame(maxWidth:.infinity)
            }
            if let detail = story.detail, !detail.isEmpty {
                Text(detail).font(.system(size:15)).foregroundColor(Color(hex:0x5e5259)).lineSpacing(max(0,15*1.65-UIFont.systemFont(ofSize:15).lineHeight)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.top,12).frame(maxWidth:370).frame(maxHeight:UIScreen.main.bounds.height*0.24,alignment:.top).clipped()
            }
            if let update = updates[story.id]?.last, !update.isEmpty {
                Text(l("后续进展","Update")+" · "+update).font(.system(size:12)).foregroundColor(Color(hex:0x816e75)).multilineTextAlignment(.center).lineLimit(2).padding(.top,14).frame(maxWidth:330)
            }
            Text("◷ \(hours) \(l("小时后消失","hours left"))  ·  \(story.answers.count) \(l("条建议","responses"))").font(.system(size:12)).foregroundColor(H5Design.muted).padding(.top,18).padding(.bottom,34)
        }.padding(.horizontal,26).frame(width:width-52,height:height).clipped().background(H5Design.card,in:RoundedRectangle(cornerRadius:30))
            .overlay(RoundedRectangle(cornerRadius:30).stroke(Color.white.opacity(0.79),lineWidth:1)).overlay(RoundedRectangle(cornerRadius:24).stroke(Color.white.opacity(0.67),lineWidth:1).padding(7)).shadow(color:Color(hex:0xa46872).opacity(0.17),radius:24,x:0,y:20).shadow(color:Color(hex:0x896d7b).opacity(0.08),radius:6,x:0,y:4)
            .contentShape(RoundedRectangle(cornerRadius:30))
            .onTapGesture {if interactive{openDetail(story)}}
    }
    func openDetail(_ story:NativeStory){
        if let i=model.stories.firstIndex(where:{$0.id==story.id}){model.index=i}
        withAnimation(reduceMotion ? nil:.timingCurve(0.22,1,0.36,1,duration:0.38)){detailStory=story}
    }
    func companions(width:CGFloat,top:CGFloat,height:CGFloat)->some View {
        let reaction = camp == .devil ? "devil" : camp == .angel ? "angel" : ""
        let gesture = camp == nil ? 0 : campProgress
        let strong = abs(devilCount-angelCount) > 1
        let place = CompanionPlacement(width:width,top:top,height:height,mode:companionMode)
        return ZStack(alignment:.topLeading){
            CompanionRig(angel:false,cheer:devilCount>angelCount ? 1:0,reply:devilCount<angelCount ? 1:0,strong:strong,chinese:zh,reaction:reaction,gesture:gesture,settling:settling,stageScale:place.scale,buddyScale:place.buddyScale).position(x:place.devilX,y:place.y).opacity(place.devilVisible ? 1:0)
            CompanionRig(angel:true,cheer:angelCount>devilCount ? 1:0,reply:angelCount<devilCount ? 1:0,strong:strong,chinese:zh,reaction:reaction,gesture:gesture,settling:settling,stageScale:place.scale,buddyScale:place.buddyScale).position(x:place.angelX,y:place.y).opacity(place.angelVisible ? 1:0)
        }.allowsHitTesting(!settling && campProgress == 0 && detailStory == nil && (utility == nil || utility == "write" || ["profile-stories","profile-answers","saved","activity"].contains(utility ?? "")))
            .opacity(keyboardHeight > 0 ? 0:1)
            .animation(reduceMotion || !motionOn ? nil:.easeInOut(duration:0.25),value:keyboardHeight)
            .animation(reduceMotion ? nil:.timingCurve(0.3,0.05,0.25,1,duration:0.68),value:place)
    }
    var companionMode:CompanionMode {
        if let c = camp { return selectedReply == nil ? .sheet(c) : .reply(c) }
        if detailStory != nil { return .detail }
        if utility == "write" { return .write(writePeek) }
        if utility == "profile" { return .profile }
        if let u = utility, ["profile-stories","profile-answers","saved","activity"].contains(u) { return .library }
        return .home
    }
    var companionsLayer:Double {
        if selectedReply != nil { return 28 }
        if detailStory != nil { return 25 }
        if utility != nil { return 11 }
        if camp != nil { return 12 }
        return 1
    }
    func bottomNav(width:CGFloat,height:CGFloat,bottom:CGFloat)->some View {
        HStack(spacing:0){navItem(l("烦恼","Stories"),icon:"house",active:true){goHome()};navItem(l("发布","Post"),icon:"plus",active:false){openWrite()};navItem(l("我的","Me"),icon:"person",active:false){withAnimation(transitionAnimation){utility="profile"}}}.padding(.horizontal,24).padding(.bottom,bottom).frame(width:width,height:70+bottom).background(ZStack{BlurView();Color(hex:0xfff8fc).opacity(0.53)}).overlay(Rectangle().fill(Color.white.opacity(0.5)).frame(height:1),alignment:.top).position(x:width/2,y:height-(70+bottom)/2)
    }
    func goHome(){
        replyText=""
        withAnimation(transitionAnimation){utility=nil;detailStory=nil;selectedReply=nil}
        resetIdleHints()
    }
    func closeUtility(){
        replyText=""
        withAnimation(transitionAnimation){utility=nil}
        resetIdleHints()
    }
    func openWrite(){
        writePeek = Bool.random() ? .devil:.angel
        replyText=""
        resetIdleHints()
        withAnimation(transitionAnimation){utility="write"}
    }
    func scheduleGuide(){
        guard !UserDefaults.standard.bool(forKey:"native.guide.v1") else{return}
        DispatchQueue.main.asyncAfter(deadline:.now()+1.8){
            guard camp == nil,utility == nil,detailStory == nil,selectedReply == nil else{return}
            withAnimation(.easeOut(duration:0.35)){guideVisible=true}
        }
    }
    func dismissGuide(){
        UserDefaults.standard.set(true,forKey:"native.guide.v1")
        withAnimation(.easeOut(duration:0.25)){guideVisible=false}
    }
    func guideCard(width:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:5){
            Text(l("第一次来？","New here?")).font(.system(size:15,weight:.bold))
            Text(l("上下滑动看烦恼，左右滑动选择天使或恶魔，进入评论区再分享你的想法。","Swipe up or down for stories. Swipe left or right to choose a side and share your thoughts.")).font(.system(size:14)).lineSpacing(3).fixedSize(horizontal:false,vertical:true)
            Text(l("匿名交流 · 烦恼、评论和收藏在 24 小时后删除","Anonymous · Stories, replies and saves expire after 24 hours")).font(.system(size:11)).foregroundColor(Color(hex:0x917e80)).padding(.top,2)
        }.foregroundColor(Color(hex:0x514348)).padding(.leading,17).padding(.trailing,38).padding(.vertical,15)
            .frame(width:min(340,width-36),alignment:.leading)
            .background(Color(hex:0xfffaf8).opacity(0.96),in:RoundedRectangle(cornerRadius:21))
            .overlay(RoundedRectangle(cornerRadius:21).stroke(Color.white.opacity(0.85),lineWidth:1))
            .shadow(color:Color(hex:0x5a4348).opacity(0.18),radius:16,y:10)
            .overlay(Button(action:dismissGuide){Text("×").font(.system(size:24,weight:.light)).foregroundColor(Color(hex:0x78676a)).frame(width:38,height:38)}.padding(.trailing,2).padding(.top,2),alignment:.topTrailing)
            .padding(.bottom,bottom+88).frame(width:width).frame(maxHeight:.infinity,alignment:.bottom)
            .transition(.move(edge:.bottom).combined(with:.opacity))
    }
    func detailHandles(width:CGFloat,height:CGFloat)->some View {
        let y = height*0.46+29
        return ZStack{
            detailHandle(.devil,width:width,y:y)
            detailHandle(.angel,width:width,y:y)
        }.frame(width:width,height:height).allowsHitTesting(true)
    }
    func detailHandle(_ side:NativeCamp,width:CGFloat,y:CGFloat)->some View {
        let sign:CGFloat = side == .devil ? 1:-1
        return Rectangle().fill(Color.white.opacity(0.001)).frame(width:64,height:140)
            .contentShape(Rectangle())
            .position(x: side == .devil ? 15:width-15, y:y)
            .highPriorityGesture(DragGesture(minimumDistance:6).onChanged{value in
                guard selectedReply == nil else{return}
                let drag = value.translation.width*sign
                if drag > 0 {camp=side;campProgress=min(1,drag/width)}
            }.onEnded{value in
                guard camp != nil else{return}
                let drag = value.translation.width*sign
                if drag > 65 {settling=true;withAnimation(transitionAnimation){campProgress=1};DispatchQueue.main.asyncAfter(deadline:.now()+0.35){settling=false}}
                else {withAnimation(transitionAnimation){campProgress=0};DispatchQueue.main.asyncAfter(deadline:.now()+0.35){if campProgress==0{camp=nil}}}
            })
            .onTapGesture {withAnimation(transitionAnimation){camp=side;campProgress=1}}
    }
    func pruneExpired(){
        let now=Date().timeIntervalSince1970
        let expired=model.stories.filter{$0.created/1000+86400 <= now}.map{$0.id}
        guard !expired.isEmpty else{return}
        var t=Transaction();t.disablesAnimations=true
        withTransaction(t){
            model.stories.removeAll{expired.contains($0.id)}
            if model.index >= model.stories.count {model.index=max(0,model.stories.count-1)}
            if let d=detailStory,expired.contains(d.id){detailStory=nil}
            if let s=snapshotStory,expired.contains(s.id){snapshotStory=nil}
            let before=snapshots.count
            snapshots.removeAll{expired.contains($0.id)}
            if snapshots.count != before {persistLocal()}
            if let a=selectedReply,!model.stories.contains(where:{story in story.answers.contains{$0.id==a.id}}){selectedReply=nil}
            if camp != nil, model.current == nil {camp=nil;campProgress=0}
        }
    }
    func resetIdleHints(_ delay:Double = 4.2){
        hintToken += 1
        let token = hintToken
        hintVisible = false
        DispatchQueue.main.asyncAfter(deadline:.now()+delay){
            guard token == hintToken else{return}
            if camp != nil || utility != nil || selectedReply != nil || detailStory != nil {resetIdleHints(12);return}
            withAnimation(.easeInOut(duration:0.55)){hintVisible = true}
            DispatchQueue.main.asyncAfter(deadline:.now()+2.8){
                guard token == hintToken else{return}
                withAnimation(.easeInOut(duration:0.55)){hintVisible = false}
                resetIdleHints(12)
            }
        }
    }
    func idleHints(width:CGFloat,height:CGFloat,bottom:CGFloat)->some View {
        let show = hintVisible && camp == nil && utility == nil && selectedReply == nil && !settling && verticalProgress < 0.001
        return HStack(spacing:8){
            Text("← " + l("恶魔","Devil"))
            Spacer(minLength:8)
            Text("↑ " + l("下一个","Next"))
            Spacer(minLength:8)
            Text(l("天使","Angel") + " →")
        }.font(.system(size:11)).foregroundColor(Color(hex:0x6e5964)).padding(.horizontal,26).frame(width:width).opacity(show ? 0.68:0).offset(y:show ? 0:4).position(x:width/2,y:height-bottom-94.5).allowsHitTesting(false)
    }
    func navItem(_ title:String,icon:String,active:Bool,action:@escaping ()->Void)->some View {
        let post = icon == "plus"
        let kind:NavGlyph.Kind = post ? .plus : icon == "person" ? .person : .house
        let color = Color(hex: active ? 0x6c4c58 : 0x8d8085)
        return Button(action:action){
            VStack(spacing:3){
                ZStack{
                    RoundedRectangle(cornerRadius: post ? 11:12).fill(post ? Color(hex:0xdf9b90) : active ? Color(hex:0xf6e5e2) : Color.clear)
                    NavGlyph(kind:kind).stroke(post ? Color.white:color, style:StrokeStyle(lineWidth:post ? 2*22/24:1.8*21/24,lineCap:.round,lineJoin:.round)).frame(width:post ? 22:21,height:post ? 22:21)
                }.frame(width:post ? 39:34,height:post ? 30:29)
                Text(title).font(.system(size:11,weight:.semibold)).foregroundColor(color)
            }.frame(maxWidth:.infinity,minHeight:56)
        }
    }
}
private struct BlurView:UIViewRepresentable {
    func makeUIView(context:Context)->UIVisualEffectView { UIVisualEffectView(effect:UIBlurEffect(style:.systemUltraThinMaterial)) }
    func updateUIView(_ view:UIVisualEffectView,context:Context) {}
}
struct PressScale:ButtonStyle {
    func makeBody(configuration:Configuration)->some View { configuration.label.scaleEffect(configuration.isPressed ? 0.95:1).animation(.easeOut(duration:0.12),value:configuration.isPressed) }
}
private struct NavGlyph:Shape {
    enum Kind { case house, plus, person }
    let kind:Kind
    func path(in r:CGRect)->Path {
        let s = r.width/24
        func p(_ x:CGFloat,_ y:CGFloat)->CGPoint { CGPoint(x:x*s,y:y*s) }
        var path = Path()
        switch kind {
        case .house:
            path.move(to:p(4.5,11.2));path.addLine(to:p(12,5));path.addLine(to:p(19.5,11.2));path.addLine(to:p(19.5,18.3))
            path.addQuadCurve(to:p(18.6,19.2),control:p(19.5,19.2));path.addLine(to:p(5.4,19.2))
            path.addQuadCurve(to:p(4.5,18.3),control:p(4.5,19.2));path.closeSubpath()
            path.move(to:p(9.2,19));path.addLine(to:p(9.2,13.6));path.addLine(to:p(14.8,13.6));path.addLine(to:p(14.8,19))
        case .plus:
            path.move(to:p(12,5));path.addLine(to:p(12,19));path.move(to:p(5,12));path.addLine(to:p(19,12))
        case .person:
            path.addEllipse(in:CGRect(x:8.8*s,y:5*s,width:6.4*s,height:6.4*s))
            path.move(to:p(5.6,19));path.addCurve(to:p(12,14.3),control1:p(6.3,16.05),control2:p(8.75,14.3))
            path.addCurve(to:p(18.4,19),control1:p(15.25,14.3),control2:p(17.7,16.05))
        }
        return path
    }
}
enum CompanionMode:Equatable {
    case home
    case sheet(NativeCamp)
    case reply(NativeCamp)
    case profile
    case library
    case write(NativeCamp)
    case detail
}
private struct CompanionPlacement:Equatable {
    var devilX:CGFloat = 63
    var angelX:CGFloat = 0
    var y:CGFloat = 0
    var scale:CGFloat = 1
    var buddyScale:CGFloat = 1.15
    var devilVisible = true
    var angelVisible = true
    init(width:CGFloat,top:CGFloat,height:CGFloat,mode:CompanionMode) {
        switch mode {
        case .home:
            angelX = width-63
            y = top+137
        case .sheet(let side), .reply(let side):
            angelX = width-63
            y = top+137
            buddyScale = 1.47
            devilVisible = side == .devil
            angelVisible = side == .angel
        case .profile:
            scale = 0.82
            y = top+99.8
            devilX = width/2-38.5
            angelX = width/2+38.5
        case .library:
            scale = 0.53
            y = top+33.4
            devilX = width-51.5
            angelX = width-31.4
        case .write(let side):
            buddyScale = 0.94
            y = top+137
            angelX = width-63
            devilVisible = side == .devil
            angelVisible = side == .angel
        case .detail:
            devilX = 11
            angelX = width-11
            y = height*0.46+29
        }
    }
}
private struct HeaderButtonStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {configuration.label.frame(width:42,height:42).background(Color.white.opacity(0.47),in:Circle()).scaleEffect(configuration.isPressed ? 0.94:1)}
}
