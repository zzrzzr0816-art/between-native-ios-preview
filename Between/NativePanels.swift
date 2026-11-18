import SwiftUI
import UIKit

extension ContentView {
    // MARK: - Conversation side panel
    func comments(_ chosen:NativeCamp,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                Text(l("大家的建议","The conversation")).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                Spacer()
                Button {closeComments()} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("关闭","Close"))
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,115)
            HStack(spacing:8){campTab(.devil,chosen:chosen,count:devilCount);campTab(.angel,chosen:chosen,count:angelCount)}.padding(.horizontal,20).padding(.bottom,12)
            ScrollView {
                VStack(spacing:10){
                    let answers=model.current?.answers.filter {$0.side==chosen.rawValue} ?? []
                    if answers.isEmpty {
                        Text(l("还没有建议，来做第一个吧 ✨","No responses yet. Start the conversation ✨")).font(.system(size:14)).foregroundColor(Color(hex:0xa09494)).padding(.vertical,35)
                    }
                    ForEach(answers){answer in commentCard(answer)}
                }.padding(.horizontal,20).padding(.top,10).padding(.bottom,18)
                    .id(chosen)
                    .transition(.asymmetric(insertion:.move(edge: chosen == .angel ? .trailing:.leading).combined(with:.opacity),removal:.opacity))
            }
            HStack(spacing:9){
                ZStack(alignment:.topLeading){
                    if composer.isEmpty { Text(l("说点什么…","Say something kind…")).font(.system(size:16)).foregroundColor(Color(hex:0xb3a5a0)).padding(.leading,13).padding(.top,13).allowsHitTesting(false) }
                    GrowField(text:$composer,height:$composerHeight,focused:Binding(get:{composerFocused},set:{composerFocused=$0}))
                }.frame(height:composerHeight).background(Color(hex:0xf7f4f1),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xeee8e4),lineWidth:1))
                Button {sendPreview(chosen)} label:{HStack(spacing:4){Text(l("发送","Send"));Text("↑")}.font(.system(size:15,weight:.bold)).foregroundColor(.white).padding(.horizontal,16).frame(minHeight:44).background(Color(hex:chosen == .devil ? 0xc6786d:0x628fa9),in:RoundedRectangle(cornerRadius:16))}.buttonStyle(PressScale())
            }.padding(.horizontal,16).padding(.top,10).padding(.bottom,max(bottom+12,keyboardHeight+8)).background(chosen.background).overlay(Rectangle().fill(Color(hex:0xeee5e2)).frame(height:1),alignment:.top)
        }.frame(width:width,height:height).background(chosen.background)
            .simultaneousGesture(DragGesture(minimumDistance:14).onChanged{value in
                guard abs(value.translation.width)>abs(value.translation.height),!composerFocused,!settling else{return}
                axis=2;let distance=max(0,value.translation.width * -chosen.sign);campProgress=max(0,1-distance/width)
            }.onEnded{value in
                guard abs(value.translation.width)>abs(value.translation.height),!composerFocused,!settling else{return}
                if value.translation.width * -chosen.sign > max(65,width*0.23){closeComments()}else{withAnimation(transitionAnimation){campProgress=1};axis=nil}
            })
    }
    func campTab(_ value:NativeCamp,chosen:NativeCamp,count:Int)->some View {
        Button {composerFocused=false;withAnimation(transitionAnimation){camp=value}} label:{
            HStack(spacing:7){
                Circle().fill(Color(hex:value == .devil ? 0xc9827b:0x83adc3)).frame(width:7,height:7)
                Text(value == .devil ? l("恶魔","Devil"):l("天使","Angel"))
                Text("\(count)").font(.system(size:12,weight:.bold)).opacity(0.7)
            }.font(.system(size:13,weight:.bold))
                .foregroundColor(Color(hex:chosen==value ? (value == .devil ? 0x994d49:0x426d88):0x756a6b))
                .padding(.horizontal,16).padding(.vertical,10)
                .background(Color(hex:chosen==value ? (value == .devil ? 0xf8d5ce:0xd8eaf5):0xf4efed),in:Capsule())
        }.buttonStyle(PressScale())
    }
    func commentCard(_ answer:NativeAnswer)->some View {
        let sid = model.current?.id ?? ""
        let mine = sid.hasPrefix("local-")
        let isBest = best["\(sid)|\(answer.side)"] == answer.id
        let isLiked = liked[answer.id] ?? false
        return VStack(alignment:.leading,spacing:0){
            HStack{
                Text(answer.author).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x9a8888))
                if answer.author.contains("AI") { Text("AI").font(.system(size:9,weight:.bold)).foregroundColor(Color(hex:0xa87336)).padding(.horizontal,5).padding(.vertical,2).background(Color(hex:0xf7ead6),in:Capsule()) }
                Spacer()
                if isBest { Text("✦ " + l("最佳","Best")).font(.system(size:11)).foregroundColor(Color(hex:0xa87336)) }
                Button {openReport("answer",answer.id)} label:{Text("⚑ "+l("举报","Report")).font(.system(size:11)).foregroundColor(Color(hex:0xb0a29d)).padding(.leading,8).frame(height:26)}.buttonStyle(.plain)
            }
            Text(answer.text).font(.system(size:14)).lineSpacing(max(0,14*1.6-UIFont.systemFont(ofSize:14).lineHeight)).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,12)
            ForEach(Array(answer.replies.enumerated()),id:\.offset){ _,reply in
                HStack(alignment:.top,spacing:0){
                    Rectangle().fill(Color(hex:0xe7dedc)).frame(width:2)
                    (Text(reply.author).font(.system(size:12,weight:.bold))+Text(" ")+Text(reply.text).font(.system(size:12))).foregroundColor(Color(hex:0x817276)).padding(.leading,9)
                }.fixedSize(horizontal:false,vertical:true).padding(.bottom,6)
            }
            HStack(spacing:8){
                Button {
                    guard requireLogin("like") else{return}
                    let next = !isLiked
                    liked[answer.id]=next;persistLocal()
                    if next {
                        withAnimation(reduceMotion || !motionOn ? nil:.easeOut(duration:0.16)){likePulse[answer.id]=true}
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.18){withAnimation(.easeOut(duration:0.18)){likePulse[answer.id]=false}}
                    }
                } label:{
                    HStack(spacing:5){Image(systemName:isLiked ? "heart.fill":"heart").font(.system(size:15,weight:.light)).scaleEffect(likePulse[answer.id]==true ? 1.45:1);Text("\(answer.likes + (isLiked ? 1:0))").font(.system(size:12))}
                        .foregroundColor(isLiked ? Color(hex:0xb85657):Color(hex:0x897a7a)).padding(.horizontal,11).frame(height:38)
                        .background(Color(hex:isLiked ? 0xf9e6e2:0xf8f4f2),in:Capsule()).animation(.easeOut(duration:0.18),value:isLiked)
                }.buttonStyle(PressScale())
                if mine {
                    Button {guard requireLogin("best") else{return};if isBest {best["\(sid)|\(answer.side)"]=nil}else{best["\(sid)|\(answer.side)"]=answer.id};persistLocal()} label:{
                        Text(isBest ? "✦ "+l("取消最佳","Remove best"):l("选为最佳","Choose best")).font(.system(size:12))
                            .foregroundColor(Color(hex:0xa87336)).padding(.horizontal,8).frame(height:38)
                    }.buttonStyle(PressScale())
                }
                Spacer(minLength:0)
                Button {withAnimation(transitionAnimation){selectedReply=answer}} label:{
                    Text(l("回复","Reply")).font(.system(size:12)).foregroundColor(Color(hex:0x897a7a)).padding(.horizontal,11).frame(height:38).background(Color(hex:0xf8f4f2),in:Capsule())
                }.buttonStyle(PressScale())
            }.padding(.top,12)
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color.white,in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).stroke(Color(hex:0xf0e9e7),lineWidth:1))
            .shadow(color:Color(hex:0x806a68).opacity(0.06),radius:8,y:4)
            .contentShape(RoundedRectangle(cornerRadius:18))
            .onTapGesture {withAnimation(transitionAnimation){selectedReply=answer}}
    }
    func closeComments(){
        composerFocused=false;settling=true
        withAnimation(transitionAnimation){campProgress=0}
        DispatchQueue.main.asyncAfter(deadline:.now()+0.35){
            camp=nil;axis=nil;resetIdleHints()
            withAnimation(reduceMotion || !motionOn ? nil:.easeOut(duration:0.2)){settling=false}
        }
    }
    func sendPreview(_ chosen:NativeCamp){
        let text=composer.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty else{return}
        guard requireLogin("respond") else{return}
        guard text.count<=1000 else{toast(l("最多输入 1000 字","Limit: 1,000 characters"));return}
        guard model.stories.indices.contains(model.index) else{return}
        model.stories[model.index].answers.append(NativeAnswer(id:UUID().uuidString,author:myName,side:chosen.rawValue,text:text,likes:0,replies:[]));composer="";composerFocused=false;persistLocal();toast(l("已发送","Sent"))
    }

    // MARK: - Utility sheets
    func utilityPage(_ page:String,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->AnyView {
        switch page {
        case "profile": return AnyView(profilePage(width:width,height:height,top:top,bottom:bottom))
        case "write": return AnyView(writePage(width:width,height:height,top:top,bottom:bottom))
        case "more": return AnyView(morePage(width:width,height:height,top:top,bottom:bottom))
        case "report": return AnyView(reportPage(width:width,height:height,top:top,bottom:bottom))
        case "update": return AnyView(updatePage(width:width,height:height,top:top,bottom:bottom))
        default: return AnyView(libraryPage(page,width:width,height:height,top:top,bottom:bottom))
        }
    }
    func sheetHead(_ title:String,top:CGFloat,padBottom:CGFloat=4)->some View {
        HStack(spacing:10){
            Text(title).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
            Spacer()
            Button {withAnimation(transitionAnimation){utility=nil}} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("关闭","Close"))
        }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,padBottom)
    }
    func writePage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let count = replyText.count
        let sheetH = keyboardHeight > 0 ? (height-keyboardHeight)*0.88:height*0.88
        let sheetBottom = keyboardHeight > 0 ? height-keyboardHeight:height
        return VStack(spacing:0){
            sheetHead(l("说说你的烦恼","What's on your mind?"),top:0,padBottom:8)
            VStack(alignment:.leading,spacing:0){
                HStack{
                    HStack(spacing:5){Text("✦");Text(l("匿名发布","Anonymous"))}.font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0xa8737a)).padding(.horizontal,11).padding(.vertical,6).background(Color(hex:0xf7e6e0),in:Capsule())
                    Spacer()
                }
                TextEditor(text:$replyText).font(.system(size:16)).lineSpacing(4).padding(12).frame(minHeight:146,alignment:.topLeading).background(Color(hex:0xf7f1ee),in:RoundedRectangle(cornerRadius:17)).overlay(RoundedRectangle(cornerRadius:17).stroke(Color(hex:0xf0e7e2),lineWidth:1)).padding(.top,10)
                    .overlay(alignment:.topLeading){ if replyText.isEmpty { Text(l("最近有什么让你纠结的事？","What's been on your mind lately?")).font(.system(size:16)).foregroundColor(Color(hex:0xb3a5a0)).padding(.leading,17).padding(.top,22).allowsHitTesting(false) } }
                HStack{
                    Text(l("说你想说的","In your own words"))
                    Spacer()
                    Text("\(count) / 1500")
                }.font(.system(size:12)).foregroundColor(Color(hex:0xa29490)).padding(.top,8)
                HStack(alignment:.top,spacing:7){
                    Text("◷").font(.system(size:12))
                    Text(l("烦恼和公开讨论将在 24 小时后消失。其他人可以在到期前保存私密快照。","The public story and discussion disappear after 24 hours. Others can save a private snapshot before then."))
                }.font(.system(size:12)).foregroundColor(Color(hex:0x8c7b72)).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Color(hex:0xf8f2ec),in:RoundedRectangle(cornerRadius:13)).padding(.top,14)
                Spacer(minLength:12)
                Button {publishStory()} label:{HStack(spacing:6){Text(l("匿名发布","Share anonymously"));Text("↗")}.font(.system(size:15,weight:.bold)).foregroundColor(.white).frame(maxWidth:.infinity,minHeight:48).background(Color(hex:0xc8786d),in:RoundedRectangle(cornerRadius:15))}.buttonStyle(PressScale())
            }.padding(.horizontal,20).padding(.bottom,bottom+20)
        }.frame(width:width,height:sheetH,alignment:.top).background(Color(hex:0xfffbf9)).clipShape(TopRoundedShape(radius:26)).position(x:width/2,y:sheetBottom-sheetH/2)
    }
    func publishStory(){
        let text=replyText.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else{toast(l("请先写点内容","Write something first"));return}
        guard requireLogin("publish") else{return}
        model.stories.insert(NativeStory(id:"local-\(UUID().uuidString)",text:text,created:Date().timeIntervalSince1970*1000,answers:[]),at:0)
        model.index=0;replyText="";persistLocal();withAnimation(transitionAnimation){utility=nil}
        toast(l("已发布","Story shared"))
    }
    func morePage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:10){
            sheetHead(l("更多","More"),top:0,padBottom:14)
            VStack(spacing:10){
                moreRow("♡ "+l("保存完整讨论","Save discussion")){saveSnapshot()}
                moreRow("✎ "+l("补充进展","Add an update")){openUtility("update")}
                moreRow("⚑ "+l("举报内容","Report content")){openReport("story",model.current?.id ?? "")}
                moreRow("⊘ "+l("屏蔽这条","Hide story")){hideStory()}
                Toggle(isOn:$motionOn){Text(l("角色动效","Companion motion")).font(.system(size:15)).foregroundColor(Color(hex:0x59484b))}.tint(Color(hex:0xc8786d)).padding(.horizontal,15).padding(.vertical,12).background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xeee7e4),lineWidth:1))
            }.padding(.horizontal,20)
            Spacer(minLength:0)
        }.padding(.bottom,bottom+20).frame(width:width,height:height*0.62,alignment:.top).background(Color(hex:0xfffbf9)).clipShape(TopRoundedShape(radius:26)).position(x:width/2,y:height-height*0.62/2)
    }
    func moreRow(_ title:String,action:@escaping ()->Void)->some View {
        Button(action:action,label:{
            HStack{Text(title);Spacer()}.font(.system(size:15)).foregroundColor(Color(hex:0x59484b)).padding(15).frame(maxWidth:.infinity)
                .background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xeee7e4),lineWidth:1))
        }).buttonStyle(PressScale())
    }
    func saveSnapshot(){
        guard let story=model.current,requireLogin("save") else{return}
        if !snapshots.contains(where:{$0.id==story.id}) { snapshots.append(story) }
        persistLocal()
        withAnimation(transitionAnimation){utility=nil}
        toast(l("快照已保存","Snapshot saved"))
    }
    func hideStory(){
        guard model.stories.indices.contains(model.index) else{return}
        let id=model.stories[model.index].id
        if !hidden.contains(id) { hidden.append(id) }
        var t=Transaction();t.disablesAnimations=true
        withTransaction(t){ model.stories.remove(at:model.index); if model.index >= model.stories.count { model.index = max(0,model.stories.count-1) } }
        persistLocal()
        withAnimation(transitionAnimation){utility=nil}
        toast(l("已屏蔽这条烦恼","Story hidden"))
    }
    func reportPage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let reasons = [(l("骚扰或攻击","Harassment or abuse"),"harassment"),(l("仇恨或歧视","Hate or discrimination"),"hate"),(l("涉及人身安全","Safety concern"),"safety"),(l("泄露隐私","Privacy violation"),"privacy"),(l("垃圾信息或其他","Spam or other"),"spam")]
        return VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                Button {closeReport()} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("返回","Back"))
                Text(l("举报内容","Report content")).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                Spacer()
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,10)
            Text(reportType=="answer" ? l("正在举报一条建议","Reporting a response") : reportType=="reply" ? l("正在举报一条回复","Reporting a reply") : l("正在举报这条烦恼","Reporting this story")).font(.system(size:11)).foregroundColor(Color(hex:0xa29490)).padding(.horizontal,20).padding(.bottom,10)
            VStack(spacing:10){
                ForEach(Array(reasons.enumerated()),id:\.offset){ _,reason in
                    Button {reportReason=reason.1} label:{
                        HStack{
                            Text(reason.0).font(.system(size:14)).foregroundColor(Color(hex:0x59484b))
                            Spacer()
                            Image(systemName:reportReason==reason.1 ? "largecircle.fill.circle":"circle").font(.system(size:17)).foregroundColor(Color(hex:reportReason==reason.1 ? 0xc8786d:0xc9b7b2))
                        }.padding(15).frame(maxWidth:.infinity).background(.white,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Color(hex:0xf0e7e2),lineWidth:1))
                    }
                }
                Button {confirmReport()} label:{
                    Text(l("确认举报","Confirm report")).font(.system(size:15,weight:.bold)).foregroundColor(.white).frame(maxWidth:.infinity,minHeight:46).background(Color(hex:0x443a43),in:RoundedRectangle(cornerRadius:14))
                }.padding(.top,4)
                Text(l("举报会提交给管理员处理。遇到紧急危险，请联系当地急救服务。","Reports are sent to the moderators. Contact local emergency services for immediate danger.")).font(.system(size:12)).foregroundColor(Color(hex:0x8a7979)).lineSpacing(4)
            }.padding(.horizontal,20).padding(.bottom,bottom+20)
            Spacer(minLength:0)
        }.frame(width:width,height:height,alignment:.top).background(Color(hex:0xfffbf9))
    }
    func openReport(_ type:String,_ id:String){
        composerFocused=false
        reportFrom = selectedReply != nil ? "reply":(camp != nil ? "comments":(utility == "more" ? "more":nil))
        reportType=type;reportId=id
        openUtility("report")
    }
    func closeReport(){
        let back=reportFrom
        reportFrom=nil
        if back == "more" {openUtility("more")}
        else {withAnimation(transitionAnimation){utility=nil}}
    }
    func confirmReport(){
        guard requireLogin("report") else{return}
        let sid=model.current?.id ?? ""
        let raw=[sid,reportType,reportId,reportReason].joined(separator:"|")
        if !reports.contains(raw){reports.append(raw)}
        persistLocal()
        reportType="story";reportId="";reportFrom=nil
        withAnimation(transitionAnimation){utility=nil}
        toast(l("举报已提交","Report submitted"))
    }
    func updatePage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                Button {openUtility("more")} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("返回","Back"))
                Text(l("补充进展","Add an update")).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                Spacer()
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,14)
            VStack(spacing:12){
                TextEditor(text:$replyText).font(.system(size:16)).padding(12).frame(minHeight:150,alignment:.topLeading).background(Color(hex:0xf7f1ee),in:RoundedRectangle(cornerRadius:17)).overlay(RoundedRectangle(cornerRadius:17).stroke(Color(hex:0xf0e7e2),lineWidth:1))
                    .overlay(alignment:.topLeading){if replyText.isEmpty{Text(l("后来怎么样了？","What happened next?")).font(.system(size:16)).foregroundColor(Color(hex:0xb3a5a0)).padding(.leading,17).padding(.top,22).allowsHitTesting(false)}}
                Button {saveUpdate()} label:{Text(l("保存进展","Save update")).font(.system(size:15,weight:.bold)).foregroundColor(.white).frame(maxWidth:.infinity,minHeight:46).background(Color(hex:0xc8786d),in:RoundedRectangle(cornerRadius:14))}
            }.padding(.horizontal,20).padding(.bottom,max(bottom+20,keyboardHeight+16))
            Spacer(minLength:0)
        }.frame(width:width,height:height,alignment:.top).background(Color(hex:0xfffbf9))
    }
    func saveUpdate(){
        let text=replyText.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,requireLogin("update"),let story=model.current else{return}
        updates[story.id,default:[]].append(text)
        replyText="";persistLocal()
        withAnimation(transitionAnimation){utility=nil}
        toast(l("进展已保存","Update saved"))
    }
    func appendReply(_ answer:NativeAnswer){
        let text=replyText.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,requireLogin("reply") else{return}
        guard let sid=model.current?.id,let si=model.stories.firstIndex(where:{$0.id==sid}),let ai=model.stories[si].answers.firstIndex(where:{$0.id==answer.id}) else{return}
        model.stories[si].answers[ai].replies.append(NativeReply(id:UUID().uuidString,author:myName,text:text))
        selectedReply=model.stories[si].answers[ai]
        replyText=""
        persistLocal()
    }
    func detailPage(_ story:NativeStory,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        ZStack(alignment:.top){
            LinearGradient(stops:[.init(color:Color(hex:0xf0b3ae),location:0),.init(color:Color(hex:0xfacfc7),location:0.34),.init(color:Color(hex:0xf8efe8),location:0.56),.init(color:Color(hex:0xd9ecf4),location:1)],startPoint:.topLeading,endPoint:.bottomTrailing)
            VStack(spacing:0){
                HStack{
                    Button {withAnimation(transitionAnimation){detailStory=nil}} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x6a5457)).frame(width:44,height:44)}.accessibilityLabel(l("返回","Back"))
                    Spacer()
                }.padding(.horizontal,10).padding(.top,top+6)
                ScrollView {
                    VStack(alignment:.leading,spacing:0){
                        Text(l("一则匿名心事","AN ANONYMOUS THOUGHT")).font(.system(size:10,weight:.semibold)).kerning(1.2).foregroundColor(Color(hex:0x8f7274)).padding(.top,10)
                        (Text(story.text)+(story.detail.map{Text("\n\n"+$0)} ?? Text(""))).font(.system(size:20,weight:.semibold)).foregroundColor(Color(hex:0x433539)).lineSpacing(7).fixedSize(horizontal:false,vertical:true).padding(.top,16)
                        Text("✦").font(.system(size:15)).foregroundColor(Color(hex:0xc49a8f)).frame(maxWidth:.infinity).padding(.top,26)
                        ForEach(updates[story.id] ?? [],id:\.self){u in
                            Text(l("后续进展","Update")+" · "+u).font(.system(size:12)).foregroundColor(Color(hex:0x816e75)).padding(.top,10)
                        }
                        Text("◷ \(max(0,Int(ceil((story.created/1000+86400-Date().timeIntervalSince1970)/3600)))) \(l("小时后消失","hours left"))  ·  \(story.answers.count) \(l("条建议","responses"))").font(.system(size:12)).foregroundColor(Color(hex:0x9a8888)).padding(.top,18)
                    }.padding(.horizontal,26).padding(.bottom,40)
                }
                Text(l("拖动小伙伴，看看两边的想法","Drag a friend to see each side")).font(.system(size:11)).foregroundColor(Color(hex:0x8b7678)).padding(.bottom,bottom+22)
            }
        }.frame(width:width,height:height)
    }
    func snapshotPage(_ story:NativeStory,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                Button {withAnimation(transitionAnimation){snapshotStory=nil}} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("返回","Back"))
                VStack(alignment:.leading,spacing:2){
                    Text(l("大家的建议","The conversation")).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                    Text(l("私密快照 · 只读","Private snapshot · read only")).font(.system(size:11)).foregroundColor(Color(hex:0x988b88))
                }
                Spacer()
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,113)
            ScrollView {
                VStack(alignment:.leading,spacing:10){
                    Text(l("这是你保存的私密快照，原始烦恼到期后会一起删除。","A private copy; it is deleted when the original story expires.")).font(.system(size:11)).foregroundColor(Color(hex:0x9b8f8b)).padding(.bottom,2)
                    Text(story.text).font(.system(size:16,weight:.semibold)).foregroundColor(Color(hex:0x433539)).fixedSize(horizontal:false,vertical:true)
                    if let detail=story.detail,!detail.isEmpty { Text(detail).font(.system(size:14)).foregroundColor(Color(hex:0x6d5f66)).fixedSize(horizontal:false,vertical:true) }
                    ForEach(updates[story.id] ?? [],id:\.self){u in Text(l("后续进展","Update")+" · "+u).font(.system(size:12)).foregroundColor(Color(hex:0x816e75)) }
                    Divider().padding(.vertical,4)
                    ForEach(story.answers){a in
                        VStack(alignment:.leading,spacing:6){
                            Text((a.side=="angel" ? l("天使","Angel"):l("恶魔","Devil")) + " · " + a.author).font(.system(size:11,weight:.bold)).foregroundColor(a.side=="angel" ? Color(hex:0x628fa9):Color(hex:0xc6786d))
                            Text(a.text).font(.system(size:14)).foregroundColor(Color(hex:0x59484b)).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
                            ForEach(Array(a.replies.enumerated()),id:\.offset){ _,r in
                                Text("✦ "+r.text).font(.system(size:12)).foregroundColor(Color(hex:0x817276)).padding(.leading,8).fixedSize(horizontal:false,vertical:true)
                            }
                        }.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xf0e9e7),lineWidth:1))
                    }
                }.padding(.horizontal,20).padding(.bottom,bottom+20)
            }
        }.frame(width:width,height:height,alignment:.top).background(Color(hex:0xeef8ff))
    }

    // MARK: - Profile
    func profilePage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let me = myName
        let answers = model.stories.reduce(0) { $0 + $1.answers.filter { $0.author == me }.count }
        let columns = [GridItem(.flexible(),spacing:10),GridItem(.flexible(),spacing:10)]
        return VStack(spacing:0){
            HStack{
                Text(l("我的","Me")).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                Spacer()
                Button {withAnimation(transitionAnimation){utility=nil}} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("关闭","Close"))
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,58)
            ScrollView {
                VStack(alignment:.leading,spacing:0){
                    accountSection.padding(.top,8)
                    LazyVGrid(columns:columns,spacing:10){
                        Button {openUtility("profile-stories")} label:{profileTile("✎",iconBG:0xfae7e2,iconColor:0xbe7770,label:l("我的烦恼","My stories"),count:model.stories.filter{$0.id.hasPrefix("local-")}.count)}
                        Button {openUtility("profile-answers")} label:{profileTile("✧",iconBG:0xe7f1f6,iconColor:0x789fb2,label:l("我的建议","My responses"),count:answers)}
                        Button {openUtility("saved")} label:{profileTile("♡",iconBG:0xfaeee6,iconColor:0xc58c78,label:l("收藏","Saved"),count:snapshots.count)}
                        Button {openUtility("activity")} label:{profileTile("◌",iconBG:0xefecf3,iconColor:0xa096b0,label:l("举报审核反馈","Report updates"),count:reports.isEmpty ? nil:reports.count)}
                    }.padding(.top,12)
                }.padding(.horizontal,18).padding(.bottom,bottom+20)
            }
        }.frame(width:width,height:height).background(Color(hex:0xfffbf9))
            .alert(isPresented:$confirmDeleteAccount){
                Alert(
                    title:Text(l("删除账号？","Delete account?")),
                    message:Text(l("账号、昵称和你的内容都会被删除，且无法恢复。","Your account, nickname, and content will be deleted permanently.")),
                    primaryButton:.destructive(Text(l("删除","Delete"))){deleteAccountAndData()},
                    secondaryButton:.cancel(Text(l("取消","Cancel")))
                )
            }
    }
    var accountSection: some View {
        Group {
            if let account=auth.account, let nickname=account.nickname, !nickname.isEmpty {
                VStack(alignment:.leading,spacing:0){
                    HStack(alignment:.top,spacing:10){
                        VStack(alignment:.leading,spacing:5){
                            Text(nickname).font(.system(size:20,weight:.bold)).foregroundColor(Color(hex:0x3a3038))
                            HStack(spacing:5){
                                Text("ID").font(.system(size:9,weight:.bold)).foregroundColor(Color(hex:0xb08a83)).padding(.horizontal,5).padding(.vertical,2).background(Color(hex:0xf7ece8),in:Capsule())
                                Text(account.id).font(.system(size:12,weight:.medium,design:.monospaced)).foregroundColor(Color(hex:0x8d7c7d))
                            }
                        }
                        Spacer(minLength:0)
                        Button {openNicknameEditor()} label:{
                            Text(l("修改昵称","Edit")).font(.system(size:12)).foregroundColor(Color(hex:0x9a7d78)).padding(.horizontal,11).frame(height:32).background(Color(hex:0xf6efec),in:Capsule())
                        }.buttonStyle(PressScale())
                    }
                    HStack(spacing:9){
                        Button {auth.signOut();toast(l("已退出登录","Signed out"))} label:{
                            Text(l("退出登录","Sign out")).font(.system(size:12)).foregroundColor(Color(hex:0x6d5f66)).padding(.horizontal,13).frame(height:36).background(Color(hex:0xf4efed),in:Capsule())
                        }.buttonStyle(PressScale())
                        Button {confirmDeleteAccount=true} label:{
                            Text(l("删除账号","Delete account")).font(.system(size:12)).foregroundColor(Color(hex:0xb85657)).padding(.horizontal,13).frame(height:36).background(Color(hex:0xfbecea),in:Capsule())
                        }.buttonStyle(PressScale())
                        Spacer(minLength:0)
                    }.padding(.top,12)
                    if let error=auth.errorText { Text(error).font(.system(size:11)).foregroundColor(Color(hex:0xb85657)).padding(.top,8) }
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading)
                    .background(.white,in:RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).stroke(Color(hex:0xf1e7e2),lineWidth:1))
                    .transition(.opacity)
            } else {
                VStack(alignment:.leading,spacing:0){
                    Text(l("你正在以游客身份浏览","You’re browsing as a guest")).font(.system(size:18,weight:.bold)).foregroundColor(Color(hex:0x3a3038))
                    Text(l("登录后可以发布、回复、点赞和收藏。","Sign in to share, respond, like and save.")).font(.system(size:12)).foregroundColor(Color(hex:0x8d7c7d)).lineSpacing(4).fixedSize(horizontal:false,vertical:true).padding(.top,8)
                    AppleSignInControl(auth:auth).padding(.top,15)
                    if let error=auth.errorText { Text(error).font(.system(size:11)).foregroundColor(Color(hex:0xb85657)).padding(.top,9) }
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading)
                    .background(.white,in:RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).stroke(Color(hex:0xf1e7e2),lineWidth:1))
                    .transition(.opacity)
            }
        }.animation(transitionAnimation,value:auth.userId)
    }
    func openNicknameEditor(){
        nicknameDraft=auth.account?.nickname ?? ""
        nicknameError=nil
        withAnimation(transitionAnimation){nicknameMode=true}
        DispatchQueue.main.asyncAfter(deadline:.now()+0.32){nicknameFocused=true}
    }
    func deleteAccountAndData(){
        let key="native.local.v2."+(auth.account?.id ?? "guest")
        Task {
            if await auth.deleteAccount() {
                UserDefaults.standard.removeObject(forKey:key)
                reloadLocalForAccount()
                withAnimation(transitionAnimation){utility=nil;nicknameMode=false}
                toast(l("账号已删除","Account deleted"))
            }
        }
    }
    func saveNickname(){
        let oldName=auth.account?.nickname
        Task {
            if let message=await auth.submitNickname(nicknameDraft) {
                nicknameError=message
            } else {
                nicknameError=nil;nicknameFocused=false
                if let oldName, let newName=auth.account?.nickname, oldName != newName {
                    renameLocalAuthor(from:oldName,to:newName)
                }
                withAnimation(transitionAnimation){nicknameMode=false}
            }
        }
    }
    func loginPromptCard(_ reason:String,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let title:String
        switch reason {
        case "publish": title=l("登录后就能发布烦恼","Sign in to share a story")
        case "respond", "reply": title=l("登录后就能加入讨论","Sign in to join the conversation")
        case "like": title=l("登录后就能点赞","Sign in to like")
        case "save": title=l("登录后就能收藏","Sign in to save")
        case "update": title=l("登录后就能补充进展","Sign in to add an update")
        case "best": title=l("登录后就能选出最佳建议","Sign in to choose a best response")
        case "report": title=l("登录后就能举报","Sign in to report")
        default: title=l("登录后继续","Sign in to continue")
        }
        return ZStack(alignment:.bottom){
            Color(hex:0x302532).opacity(0.34).contentShape(Rectangle()).onTapGesture{withAnimation(transitionAnimation){loginPrompt=nil}}.transition(.opacity)
            VStack(alignment:.leading,spacing:0){
                HStack{
                    Text(title).font(.system(size:18,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                    Spacer(minLength:0)
                    Button {withAnimation(transitionAnimation){loginPrompt=nil}} label:{Text("×").font(.system(size:24,weight:.light)).foregroundColor(Color(hex:0x8d7c7d)).frame(width:34,height:34)}.accessibilityLabel(l("关闭","Close"))
                }
                AppleSignInControl(auth:auth).padding(.top,14)
                if let error=auth.errorText { Text(error).font(.system(size:11)).foregroundColor(Color(hex:0xb85657)).padding(.top,9) }
                Button {withAnimation(transitionAnimation){loginPrompt=nil}} label:{
                    Text(l("稍后再说","Not now")).font(.system(size:12)).foregroundColor(Color(hex:0xa29490)).frame(maxWidth:.infinity,minHeight:40)
                }.buttonStyle(PressScale()).padding(.top,6)
            }.padding(20).frame(width:width-36)
                .background(Color(hex:0xfffbf9),in:RoundedRectangle(cornerRadius:22))
                .shadow(color:Color(hex:0x45313a).opacity(0.18),radius:24,y:14)
                .padding(.bottom,max(bottom+22,keyboardHeight+22))
        }.frame(width:width,height:height).transition(.opacity)
    }
    func nicknameSheet(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        ZStack(alignment:.bottom){
            Color(hex:0x302532).opacity(0.34).contentShape(Rectangle()).onTapGesture{closeNicknameSheet()}.transition(.opacity)
            VStack(alignment:.leading,spacing:0){
                HStack{
                    Text(l("修改昵称","Edit nickname")).font(.system(size:18,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                    Spacer(minLength:0)
                    Button {closeNicknameSheet()} label:{Text("×").font(.system(size:24,weight:.light)).foregroundColor(Color(hex:0x8d7c7d)).frame(width:34,height:34)}.accessibilityLabel(l("关闭","Close"))
                }
                ZStack(alignment:.leading){
                    if nicknameDraft.isEmpty { Text(l("例如：晚风","e.g. Nightfall")).font(.system(size:16)).foregroundColor(Color(hex:0xb3a5a0)).padding(.leading,14).allowsHitTesting(false) }
                    TextField("",text:$nicknameDraft).font(.system(size:16)).foregroundColor(Color(hex:0x3a3038)).padding(.horizontal,14).frame(height:50)
                        .disableAutocorrection(true)
                        .focused($nicknameFocused)
                        .onChange(of:nicknameDraft){ value in if value.count>16 {nicknameDraft=String(value.prefix(16))} }
                }.background(Color(hex:0xf7f1ee),in:RoundedRectangle(cornerRadius:15)).overlay(RoundedRectangle(cornerRadius:15).stroke(Color(hex:0xeee4df),lineWidth:1)).padding(.top,16)
                HStack{
                    Text(nicknameError ?? l("2–16 个字符，支持中英文、数字、_ 和 -","2–16 characters: letters, numbers, _ or -")).font(.system(size:11)).foregroundColor(nicknameError==nil ? Color(hex:0xa29490):Color(hex:0xb85657)).lineSpacing(3)
                    Spacer(minLength:0)
                    Text("\(nicknameDraft.count)/16").font(.system(size:10)).foregroundColor(Color(hex:0xb0a29d))
                }.padding(.top,9)
                Button {saveNickname()} label:{
                    HStack(spacing:6){Text(l("保存昵称","Save nickname"));Text("↗")}.font(.system(size:15,weight:.bold)).foregroundColor(.white).frame(maxWidth:.infinity,minHeight:48).background(Color(hex:0xc8786d),in:RoundedRectangle(cornerRadius:15)).opacity(auth.busy ? 0.6:1)
                }.buttonStyle(PressScale()).disabled(auth.busy).padding(.top,16)
            }.padding(20).frame(width:width-36)
                .background(Color(hex:0xfffbf9),in:RoundedRectangle(cornerRadius:22))
                .shadow(color:Color(hex:0x45313a).opacity(0.18),radius:24,y:14)
                .padding(.bottom,max(bottom+22,keyboardHeight+22))
        }.frame(width:width,height:height).transition(.opacity)
    }
    func closeNicknameSheet(){
        nicknameFocused=false
        nicknameError=nil
        withAnimation(transitionAnimation){nicknameMode=false}
    }
    func openUtility(_ page:String){withAnimation(transitionAnimation){utility=page}}
    func profileTile(_ icon:String,iconBG:UInt32,iconColor:UInt32,label:String,count:Int?)->some View {
        VStack(alignment:.leading,spacing:0){
            Text(icon).font(.system(size:20)).foregroundColor(Color(hex:iconColor)).frame(width:34,height:34).background(Color(hex:iconBG),in:RoundedRectangle(cornerRadius:12))
            Spacer(minLength:12)
            HStack(alignment:.firstTextBaseline,spacing:7){
                Text(label).font(.system(size:13,weight:.bold)).foregroundColor(Color(hex:0x59484b))
                if let count { Text("\(count)").font(.system(size:11,weight:.medium)).foregroundColor(Color(hex:0xb5a39e)) }
            }
        }.padding(13).frame(maxWidth:.infinity,minHeight:114,alignment:.leading)
            .background(.white,in:RoundedRectangle(cornerRadius:19)).overlay(RoundedRectangle(cornerRadius:19).stroke(Color(hex:0xf2e8e3),lineWidth:1))
            .overlay(Text("↗").font(.system(size:15)).foregroundColor(Color(hex:0xc5b5af)).padding(.top,15).padding(.trailing,15),alignment:.topTrailing)
    }
    func libraryPage(_ page:String,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let me = myName
        let title:String, intro:String, empty:String
        switch page {
        case "profile-stories": title=l("我的烦恼","My stories");intro=l("写下的心事，会在这里停留 24 小时。","Your stories stay here for 24 hours.");empty=l("还没有发布过烦恼。","You haven’t shared a story yet.")
        case "profile-answers": title=l("我的建议","My responses");intro=l("你留下的建议，都在这里。","The conversations you have joined.");empty=l("还没有发表过建议。","You haven’t shared a response yet.")
        case "saved": title=l("我的私密快照","Your private snapshots");intro=l("只属于你的讨论留存，烦恼到期或被移除时一同删除。","Your private snapshots are deleted when their stories expire or are removed.");empty=l("还没有收藏过讨论。","No saved discussions yet.")
        default: title=l("举报审核反馈","Report updates");intro=l("这里会显示你提交过的反馈。","Your reports appear here.");empty=l("暂时没有新动态","Nothing new here yet")
        }
        var items:[(String,String,NativeStory?,String?)] = []
        if page=="profile-answers" { for story in model.stories { for answer in story.answers where answer.author==me { items.append((answer.text,story.text,story,nil)) } } }
        if page=="profile-stories" { for story in model.stories where story.id.hasPrefix("local-") { items.append((story.text,l("24 小时后消失","Expires in 24 hours"),story,nil)) } }
        if page=="saved" { for story in snapshots { items.append((story.text,l("快照 · 只读","Snapshot · read only"),story,nil)) } }
        if page=="activity" {
            for raw in reports {
                let parts=raw.split(separator:"|").map(String.init)
                let sid=parts.first ?? raw
                let type=parts.count>1 ? parts[1]:"story"
                let story=model.stories.first{$0.id==sid}
                let typeLabel = type=="answer" ? l("建议","response") : type=="reply" ? l("回复","reply") : l("烦恼","story")
                let status = reviewed.contains(raw) ? l("已查看","Reviewed") : l("待查看","Pending")
                items.append((story?.text ?? l("已移除的烦恼","A removed story"),"\(status) · \(typeLabel)",story,raw))
            }
        }
        return VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                Button {openUtility("profile")} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("返回","Back"))
                Text(title).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                Spacer()
                Button {withAnimation(transitionAnimation){utility=nil}} label:{Text("×").font(.system(size:26,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("关闭","Close"))
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,8)
            ScrollView {
                VStack(alignment:.leading,spacing:12){
                    Text(intro).font(.system(size:12)).foregroundColor(Color(hex:0xa29894)).lineSpacing(4).padding(.top,4)
                    if items.isEmpty {
                        Text(empty).font(.system(size:14)).foregroundColor(Color(hex:0xa09494)).frame(maxWidth:.infinity).padding(.vertical,35)
                    }
                    ForEach(Array(items.enumerated()),id:\.offset){ _,item in
                        VStack(alignment:.leading,spacing:8){
                            Text(title).font(.system(size:11)).foregroundColor(Color(hex:0xb0a29d))
                            Text(item.0).font(.system(size:14)).foregroundColor(Color(hex:0x59484b)).fixedSize(horizontal:false,vertical:true)
                            Text(item.1).font(.system(size:12)).foregroundColor(Color(hex:0x9b8d8b)).lineLimit(2)
                        }.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xf0e9e7),lineWidth:1))
                            .contentShape(RoundedRectangle(cornerRadius:16))
                            .onTapGesture {
                                switch page {
                                case "saved": if let story=item.2 {withAnimation(transitionAnimation){snapshotStory=story}}
                                case "activity": if let key=item.3 {if reviewed.contains(key){reviewed.removeAll{$0==key}}else{reviewed.append(key)};persistLocal()}
                                case "profile-stories": if let story=item.2 {openDetail(story);withAnimation(transitionAnimation){utility=nil}}
                                default: if let story=item.2 {detailStory=story}
                                }
                            }
                    }
                }.padding(.horizontal,20).padding(.bottom,bottom+20)
            }
        }.frame(width:width,height:height).background(Color(hex:0xfffaf8))
    }

    // MARK: - Reply layer
    func replyOverlay(_ answer:NativeAnswer,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let topPad = keyboardHeight > 0 ? 12:min(max(height*0.21,150),180)
        let dialogH = max(280,min(600,height-topPad-bottom-28-keyboardHeight))
        let accent = Color(hex:answer.side=="devil" ? 0xc6786d:0x628fa9)
        return ZStack(alignment:.bottom){
            Color(hex:0x302532).opacity(0.30).contentShape(Rectangle()).onTapGesture{withAnimation(transitionAnimation){selectedReply=nil}}
            VStack(alignment:.leading,spacing:0){
                HStack(spacing:13){
                    Button {withAnimation(transitionAnimation){selectedReply=nil}} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x5d5055)).frame(width:42,height:42).background(Color(hex:0xf2eae6),in:Circle())}.accessibilityLabel(l("返回评论","Back to comments"))
                    VStack(alignment:.leading,spacing:3){
                        Text(l("回复","Replies")).font(.system(size:18,weight:.bold))
                        Text("\(answer.replies.count) \(l("条回复","replies"))").font(.system(size:11)).foregroundColor(Color(hex:0x988b88))
                    }
                    Spacer(minLength:0)
                }.padding(.horizontal,20).padding(.top,18).padding(.bottom,103)
                ScrollView {
                    VStack(alignment:.leading,spacing:12){
                        VStack(alignment:.leading,spacing:0){
                            HStack{
                                Text(answer.author).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x9a8888))
                                if answer.author.contains("AI") { Text("AI").font(.system(size:9,weight:.bold)).foregroundColor(Color(hex:0xa87336)).padding(.horizontal,5).padding(.vertical,2).background(Color(hex:0xf7ead6),in:Capsule()) }
                                Spacer()
                                Button {openReport("answer",answer.id)} label:{Text("⚑ "+l("举报","Report")).font(.system(size:11)).foregroundColor(Color(hex:0xb0a29d)).frame(height:26)}.buttonStyle(.plain)
                            }
                            Text(answer.text).font(.system(size:14)).lineSpacing(max(0,14*1.6-UIFont.systemFont(ofSize:14).lineHeight)).fixedSize(horizontal:false,vertical:true).padding(.vertical,12)
                            HStack(spacing:5){
                                Image(systemName:"heart").font(.system(size:14,weight:.light))
                                Text("\(answer.likes)").font(.system(size:12))
                            }.foregroundColor(Color(hex:0x897a7a)).padding(.horizontal,11).frame(height:36).background(Color(hex:0xf8f4f2),in:Capsule())
                        }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(Color(hex:0xf0e9e7),lineWidth:1)).shadow(color:Color(hex:0x654c53).opacity(0.09),radius:12,y:8)
                        Text(l("全部回复","Replies")).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x9a8888)).padding(.top,6)
                        if answer.replies.isEmpty {
                            Text(l("还没有回复，来接住这句话吧。","No replies yet. Be the first to respond.")).font(.system(size:14)).foregroundColor(Color(hex:0xa09494)).frame(maxWidth:.infinity).padding(.vertical,30)
                        } else {
                            ForEach(Array(answer.replies.enumerated()),id:\.offset){ idx,reply in
                                HStack(alignment:.top,spacing:10){
                                    Text("✦").font(.system(size:13)).foregroundColor(Color(hex:0xd9a89c)).frame(width:26,height:26).background(Color(hex:0xfaf0eb),in:Circle())
                                    VStack(alignment:.leading,spacing:4){
                                        HStack{
                                            Text(reply.author).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x817276))
                                            Spacer(minLength:0)
                                            if let rid=reply.id { Button {openReport("reply",rid)} label:{Text("⚑").font(.system(size:10)).foregroundColor(Color(hex:0xb0a29d)).frame(width:24,height:20)}.buttonStyle(.plain) }
                                        }
                                        Text(reply.text).font(.system(size:13)).foregroundColor(Color(hex:0x6d5f66)).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
                                    }
                                    Spacer(minLength:0)
                                }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xf0e9e7),lineWidth:1))
                                    .transition(.move(edge:.bottom).combined(with:.opacity))
                                    .animation(reduceMotion || !motionOn ? nil:.easeOut(duration:0.3).delay(Double(min(idx,6))*0.04),value:answer.replies.count)
                            }
                        }
                    }.padding(.horizontal,20).padding(.bottom,18)
                }
                VStack(spacing:0){
                    Text("↳ \(l("回复","Reply")) \(answer.author)  ·  \(l("匿名","anonymous"))").font(.system(size:11)).foregroundColor(Color(hex:0x9b8f8b)).frame(maxWidth:.infinity,alignment:.leading).padding(.bottom,8)
                    HStack(spacing:9){
                        ZStack(alignment:.topLeading){
                            if replyText.isEmpty { Text(l("写下回复…","Write a reply…")).font(.system(size:16)).foregroundColor(Color(hex:0xb3a5a0)).padding(.leading,13).padding(.top,13).allowsHitTesting(false) }
                            GrowField(text:$replyText,height:$replyHeight,focused:Binding(get:{composerFocused},set:{composerFocused=$0}),maxHeight:104)
                        }.frame(height:replyHeight).background(Color(hex:0xf7f4f1),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xeee8e4),lineWidth:1))
                        Button {appendReply(answer)} label:{HStack(spacing:4){Text(l("发送","Send"));Text("↑")}.font(.system(size:13,weight:.bold)).foregroundColor(.white).padding(.horizontal,13).frame(minWidth:74,minHeight:46).background(accent,in:RoundedRectangle(cornerRadius:15))}.buttonStyle(PressScale())
                    }
                }.padding(.horizontal,16).padding(.top,10).padding(.bottom,max(bottom+12,keyboardHeight+8)).background(Color(hex:0xfffdfb)).overlay(Rectangle().fill(Color(hex:0xeee7e4)).frame(height:1),alignment:.top)
            }.frame(width:width-28,height:dialogH).background(Color(hex:0xfffbf9)).clipShape(RoundedRectangle(cornerRadius:23)).shadow(color:Color(hex:0x45313a).opacity(0.19),radius:26,y:18).padding(.bottom,bottom+14)
        }.frame(width:width,height:height)
    }
}
struct GrowField:UIViewRepresentable {
    @Binding var text:String
    @Binding var height:CGFloat
    @Binding var focused:Bool
    var maxHeight:CGFloat = 112
    func makeUIView(context:Context)->UITextView {
        let v=UITextView()
        v.backgroundColor = .clear
        v.font = .systemFont(ofSize:16)
        v.textContainerInset = UIEdgeInsets(top:13,left:8,bottom:13,right:8)
        v.textContainer.lineFragmentPadding = 4
        v.isScrollEnabled = false
        v.delegate = context.coordinator
        v.text = text
        v.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
        return v
    }
    func updateUIView(_ v:UITextView,context:Context){
        if v.text != text { v.text = text }
        if focused && !v.isFirstResponder { v.becomeFirstResponder() }
        if !focused && v.isFirstResponder { v.resignFirstResponder() }
        measure(v)
    }
    func makeCoordinator()->Coordinator { Coordinator(self) }
    func measure(_ v:UITextView){
        let w = v.bounds.width
        guard w > 10 else { return }
        let h = min(maxHeight,max(46,ceil(v.sizeThatFits(CGSize(width:w,height:10000)).height)))
        if abs(h-height) > 0.5 { DispatchQueue.main.async { height = h } }
    }
    final class Coordinator:NSObject,UITextViewDelegate {
        var parent:GrowField
        init(_ p:GrowField){parent=p}
        func textViewDidChange(_ tv:UITextView){parent.text=tv.text;parent.measure(tv)}
        func textViewDidBeginEditing(_ tv:UITextView){parent.focused=true}
        func textViewDidEndEditing(_ tv:UITextView){parent.focused=false}
    }
}
private struct TopRoundedShape:Shape {
    let radius:CGFloat
    func path(in r:CGRect)->Path {
        var p=Path()
        p.move(to:CGPoint(x:0,y:r.height))
        p.addLine(to:CGPoint(x:0,y:radius))
        p.addQuadCurve(to:CGPoint(x:radius,y:0),control:CGPoint(x:0,y:0))
        p.addLine(to:CGPoint(x:r.width-radius,y:0))
        p.addQuadCurve(to:CGPoint(x:r.width,y:radius),control:CGPoint(x:r.width,y:0))
        p.addLine(to:CGPoint(x:r.width,y:r.height))
        p.closeSubpath()
        return p
    }
}
