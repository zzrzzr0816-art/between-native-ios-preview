import SwiftUI

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
    @State var notice: String? = nil
    @FocusState var composerFocused: Bool
    var zh: Bool { language == "zh" }
    func l(_ a:String,_ b:String)->String { zh ? a:b }
    var transitionAnimation: Animation? { reduceMotion ? nil:H5Design.settling }
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
                    Color.black.opacity(0.12*Double(campProgress)).allowsHitTesting(false)
                    comments(chosen,width:w,height:h,top:top,bottom:bottom).offset(x:-chosen.sign*w*(1-campProgress)).allowsHitTesting((campProgress>0.99 || axis==2) && !settling)
                }
                companions(width:w,top:top)
                if let page = utility { utilityPage(page,width:w,height:h,top:top,bottom:bottom).zIndex(10).transition(.opacity.combined(with:.offset(y:12))) }
                if utility == "profile" { companions(width:w,top:top,compact:true).zIndex(11) }
                if let answer = selectedReply { replyOverlay(answer,width:w,height:h,top:top).zIndex(20).transition(.opacity) }
            }.frame(width:w,height:h).clipped().offset(y:-top)
                .animation(reduceMotion ? nil:.easeInOut(duration:0.45),value:devilCount)
                .animation(reduceMotion ? nil:.easeInOut(duration:0.45),value:angelCount)
        }.foregroundColor(H5Design.ink).tint(H5Design.ink).buttonStyle(.plain)
            .task { await model.load(language) }
            .alert(l("提示","Notice"),isPresented:Binding(get:{notice != nil},set:{if !$0 {notice=nil}})) { Button(l("知道了","OK")){notice=nil} } message:{Text(notice ?? "")}
    }
    func homeHeader(width:CGFloat,top:CGFloat)->some View {
        ZStack(alignment:.topLeading) {
            (Text("between").foregroundColor(Color(hex:0x42353f))+Text(".").foregroundColor(Color(hex:0xe0776e))).font(.system(size:23,weight:.heavy)).tracking(-1.5).frame(height:42).position(x:69,y:top+37)
            HStack(spacing:7){
                Button(zh ? "中文":"EN"){language=zh ? "en":"zh";Task{await model.load(language)}}.accessibilityLabel("Switch language")
                Button {withAnimation(transitionAnimation){utility="more"}} label:{Image(systemName:"ellipsis").font(.system(size:17,weight:.bold))}.accessibilityLabel(l("更多","More"))
            }.font(.system(size:14)).buttonStyle(HeaderButtonStyle()).position(x:width-67.5,y:top+37)
            Text(model.preview ? l("原生交互预览 · 测试内容","NATIVE INTERACTION PREVIEW · SAMPLE CONTENT"):l("体验版 · 讨论 24 小时后删除","TRIAL · Discussions expire after 24 hours")).font(.system(size:10)).foregroundColor(Color(hex:0x89757b)).frame(width:width).position(x:width/2,y:top+72.5)
        }.opacity(1-Double(campProgress)).allowsHitTesting(campProgress<0.01)
    }
    func feed(width:CGFloat,area:CGFloat)->some View {
        ZStack {
            if let story=model.current {
                let cardH=H5Design.cardHeight(story.text,width:width,available:area)
                let next=verticalTarget.flatMap {model.stories.indices.contains($0) ? model.stories[$0]:nil}
                let nextH=next.map {H5Design.cardHeight($0.text,width:width,available:area)} ?? cardH
                let travel=H5Design.verticalTravel(area:area,current:cardH,next:nextH)
                storyCard(story,width:width,height:cardH).scaleEffect(1-0.025*campProgress).offset(x:(camp?.sign ?? 0)*width*0.3*campProgress,y:verticalSign*travel*verticalProgress+edgeOffset).opacity(1-Double(H5Design.fade(verticalProgress)))
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
        if axis==nil {axis=abs(value.translation.width)>abs(value.translation.height) ? 0:1}
        if axis==0 {camp=value.translation.width<0 ? .devil:.angel;campProgress=min(1,abs(value.translation.width)/width)}
        else if campProgress==0,let story=model.current {
            let sign:CGFloat=value.translation.height<0 ? -1:1,target=model.index+(sign<0 ? 1:-1)
            if model.stories.indices.contains(target){
                verticalSign=sign;verticalTarget=target
                let a=H5Design.cardHeight(story.text,width:width,available:area),b=H5Design.cardHeight(model.stories[target].text,width:width,available:area)
                verticalProgress=H5Design.verticalProgress(raw:value.translation.height,travel:H5Design.verticalTravel(area:area,current:a,next:b));edgeOffset=0
            } else {verticalTarget=nil;edgeOffset=sign*32*(1-exp(-abs(value.translation.height)/100))}
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
            DispatchQueue.main.asyncAfter(deadline:.now()+0.55){var transaction=Transaction();transaction.disablesAnimations=true;withTransaction(transaction){if commit {model.index=target};verticalTarget=nil;verticalProgress=0;axis=nil;settling=false}}
        } else {withAnimation(transitionAnimation){edgeOffset=0};axis=nil}
    }
    func storyCard(_ story:NativeStory,width:CGFloat,height:CGFloat)->some View {
        VStack(spacing:0){
            Text("✦").font(.system(size:27)).foregroundColor(Color(hex:0xd7958c)).frame(height:32).padding(.top,34)
            Text(story.text).font(.system(size:H5Design.titleSize(width),weight:.bold)).tracking(-0.8).lineSpacing(max(0,H5Design.titleSize(width)*1.35-UIFont.systemFont(ofSize:H5Design.titleSize(width),weight:.bold).lineHeight)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.top,20).frame(maxWidth:.infinity)
            if let detail = story.detail, !detail.isEmpty {
                Text(detail).font(.system(size:15)).foregroundColor(Color(hex:0x5e5259)).lineSpacing(max(0,15*1.65-UIFont.systemFont(ofSize:15).lineHeight)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.top,12).frame(maxWidth:370).frame(maxHeight:UIScreen.main.bounds.height*0.24,alignment:.top).clipped()
            }
            Text("◷ 24 \(l("小时后消失","hours left"))  ·  \(story.answers.count) \(l("条建议","responses"))").font(.system(size:12)).foregroundColor(H5Design.muted).padding(.top,18).padding(.bottom,34)
        }.padding(.horizontal,26).frame(width:width-52,height:height).clipped().background(H5Design.card,in:RoundedRectangle(cornerRadius:30))
            .overlay(RoundedRectangle(cornerRadius:30).stroke(Color.white.opacity(0.79),lineWidth:1)).overlay(RoundedRectangle(cornerRadius:24).stroke(Color.white.opacity(0.67),lineWidth:1).padding(7)).shadow(color:Color(hex:0xa46872).opacity(0.17),radius:24,x:0,y:20).shadow(color:Color(hex:0x896d7b).opacity(0.08),radius:6,x:0,y:4)
    }
    func companions(width:CGFloat,top:CGFloat,compact:Bool=false)->some View {
        let reaction = compact ? "" : camp == .devil ? "devil" : camp == .angel ? "angel" : ""
        let gesture = (camp == nil || compact) ? 0 : campProgress
        let strong = abs(devilCount-angelCount) > 1
        let y = compact ? top+33 : top+137
        return ZStack(alignment:.topLeading){
            CompanionRig(angel:false,cheer:devilCount>angelCount ? 1:0,reply:devilCount<angelCount ? 1:0,strong:strong,chinese:zh,reaction:reaction,gesture:gesture,settling:settling,stageScale:compact ? 0.53:1).position(x:compact ? width-60:63,y:y)
            CompanionRig(angel:true,cheer:angelCount>devilCount ? 1:0,reply:angelCount<devilCount ? 1:0,strong:strong,chinese:zh,reaction:reaction,gesture:gesture,settling:settling,stageScale:compact ? 0.53:1).position(x:compact ? width-40:width-63,y:y)
        }.allowsHitTesting(!settling)
    }
    func bottomNav(width:CGFloat,height:CGFloat,bottom:CGFloat)->some View {
        HStack(spacing:0){navItem(l("烦恼","Stories"),icon:"house",active:true){};navItem(l("发布","Post"),icon:"plus",active:false){withAnimation(transitionAnimation){utility="write"}};navItem(l("我的","Me"),icon:"person",active:false){withAnimation(transitionAnimation){utility="profile"}}}.padding(.horizontal,24).padding(.bottom,bottom).frame(width:width,height:70+bottom).background(Color(hex:0xfffcf8).opacity(0.81)).overlay(Rectangle().fill(Color.white.opacity(0.7)).frame(height:1),alignment:.top).position(x:width/2,y:height-(70+bottom)/2)
    }
    func idleHints(width:CGFloat,height:CGFloat,bottom:CGFloat)->some View {
        let show = camp == nil && utility == nil && selectedReply == nil && !settling && verticalProgress < 0.001
        return HStack(spacing:8){
            Text("← " + l("恶魔","Devil"))
            Spacer(minLength:8)
            Text("↑ " + l("下一个","Next"))
            Spacer(minLength:8)
            Text(l("天使","Angel") + " →")
        }.font(.system(size:11)).tracking(0.22).foregroundColor(Color(hex:0x6e5964)).padding(.horizontal,26).frame(width:width).opacity(show ? 0.68:0).offset(y:show ? 0:4).position(x:width/2,y:height-bottom-94.5).allowsHitTesting(false)
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
private struct HeaderButtonStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {configuration.label.frame(width:42,height:42).background(Color.white.opacity(0.47),in:Circle()).scaleEffect(configuration.isPressed ? 0.94:1)}
}
