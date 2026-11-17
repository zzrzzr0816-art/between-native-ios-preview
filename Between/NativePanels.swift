import SwiftUI

extension ContentView {
    // MARK: - Conversation side panel
    func comments(_ chosen:NativeCamp,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                Text(l("大家的建议","The conversation")).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                Spacer()
                Button {closeComments()} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("关闭","Close"))
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,91)
            HStack(spacing:8){campTab(.devil,chosen:chosen,count:devilCount);campTab(.angel,chosen:chosen,count:angelCount)}.padding(.horizontal,20).padding(.bottom,12)
            ScrollView {
                VStack(spacing:10){
                    let answers=model.current?.answers.filter {$0.side==chosen.rawValue} ?? []
                    if answers.isEmpty {
                        Text(l("还没有建议，来做第一个吧 ✨","No responses yet. Start the conversation ✨")).font(.system(size:14)).foregroundColor(Color(hex:0xa09494)).padding(.vertical,35)
                    }
                    ForEach(answers){answer in commentCard(answer)}
                }.padding(.horizontal,20).padding(.top,10).padding(.bottom,18)
            }
            HStack(spacing:9){
                TextField(l("说点什么…","Say something kind…"),text:$composer).font(.system(size:16)).padding(.horizontal,13).padding(.vertical,13).frame(minHeight:48).background(Color(hex:0xf3efed),in:RoundedRectangle(cornerRadius:16)).focused($composerFocused)
                Button {sendPreview(chosen)} label:{Text(l("发送","Send")).font(.system(size:15,weight:.bold)).foregroundColor(.white).padding(.horizontal,16).frame(minHeight:44).background(Color(hex:0x413942),in:RoundedRectangle(cornerRadius:16))}
            }.padding(.horizontal,20).padding(.top,12).padding(.bottom,bottom+12).background(chosen.background).overlay(Rectangle().fill(Color(hex:0xeee5e2)).frame(height:1),alignment:.top)
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
        Button {composerFocused=false;withAnimation(reduceMotion ? nil:.easeInOut(duration:0.42)){camp=value}} label:{
            HStack(spacing:7){
                Circle().fill(Color(hex:value == .devil ? 0xc9827b:0x83adc3)).frame(width:7,height:7)
                Text(value == .devil ? l("恶魔","Devil"):l("天使","Angel"))
                Text("\(count)").font(.system(size:12,weight:.bold)).opacity(0.7)
            }.font(.system(size:13,weight:.bold))
                .foregroundColor(Color(hex:chosen==value ? (value == .devil ? 0x994d49:0x426d88):0x756a6b))
                .padding(.horizontal,16).padding(.vertical,10)
                .background(Color(hex:chosen==value ? (value == .devil ? 0xf8d5ce:0xd8eaf5):0xf4efed),in:Capsule())
        }
    }
    func commentCard(_ answer:NativeAnswer)->some View {
        Button {withAnimation(transitionAnimation){selectedReply=answer}} label:{
            VStack(alignment:.leading,spacing:0){
                HStack{
                    Text(answer.author).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x9a8888))
                    Spacer()
                    if answer.likes > 30 { Text("✦ " + l("最佳","Best")).font(.system(size:11)).foregroundColor(Color(hex:0xa87336)) }
                }
                Text(answer.text).font(.system(size:14)).lineSpacing(max(0,14*1.6-UIFont.systemFont(ofSize:14).lineHeight)).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,12)
                if let first=answer.replies.first {
                    HStack(alignment:.top,spacing:0){
                        Rectangle().fill(Color(hex:0xe7dedc)).frame(width:2)
                        (Text(first.author).font(.system(size:12,weight:.bold))+Text(" ")+Text(first.text).font(.system(size:12))).foregroundColor(Color(hex:0x817276)).padding(.leading,9)
                    }.fixedSize(horizontal:false,vertical:true)
                }
                HStack(spacing:5){
                    Image(systemName:"heart").font(.system(size:16,weight:.light))
                    Text("\(answer.likes)").font(.system(size:12))
                }.foregroundColor(Color(hex:0x897a7a)).padding(.horizontal,11).frame(height:38).background(Color(hex:0xf8f4f2),in:Capsule()).padding(.top,12)
            }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
                .background(Color.white,in:RoundedRectangle(cornerRadius:18))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(Color(hex:0xf0e9e7),lineWidth:1))
                .shadow(color:Color(hex:0x806a68).opacity(0.06),radius:8,y:4)
        }
    }
    func closeComments(){
        composerFocused=false;settling=true
        withAnimation(transitionAnimation){campProgress=0}
        DispatchQueue.main.asyncAfter(deadline:.now()+0.35){camp=nil;settling=false;axis=nil}
    }
    func sendPreview(_ chosen:NativeCamp){
        let text=composer.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty else{return}
        guard text.count<=1000 else{notice=l("最多输入 1000 字","Limit: 1,000 characters");return}
        guard model.preview else{notice=l("原生发布接口尚未接入审核，此预览暂不提交内容。","Posting and moderation are not connected in this native preview.");return}
        guard model.stories.indices.contains(model.index) else{return}
        model.stories[model.index].answers.append(NativeAnswer(id:UUID().uuidString,author:l("你 · 预览","You · preview"),side:chosen.rawValue,text:text,likes:0,replies:[]));composer="";composerFocused=false
    }

    // MARK: - Utility sheets
    func utilityPage(_ page:String,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->AnyView {
        switch page {
        case "profile": return AnyView(profilePage(width:width,height:height,top:top,bottom:bottom))
        case "write": return AnyView(writePage(width:width,height:height,top:top,bottom:bottom))
        case "more": return AnyView(morePage(width:width,height:height,top:top,bottom:bottom))
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
        return VStack(spacing:0){
            sheetHead(l("说说你的烦恼","What's on your mind?"),top:top,padBottom:66)
            VStack(alignment:.leading,spacing:0){
                HStack{
                    HStack(spacing:5){Text("✦");Text(l("匿名发布","Anonymous"))}.font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0xa8737a)).padding(.horizontal,11).padding(.vertical,6).background(Color(hex:0xf7e6e0),in:Capsule())
                    Spacer()
                    Text("✳").font(.system(size:17)).foregroundColor(Color(hex:0xd9a89c))
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
                Button {publishStory()} label:{HStack(spacing:6){Text(l("匿名发布","Share anonymously"));Text("↗")}.font(.system(size:15,weight:.bold)).foregroundColor(.white).frame(maxWidth:.infinity,minHeight:48).background(Color(hex:0xc8786d),in:RoundedRectangle(cornerRadius:15))}
            }.padding(.horizontal,20).padding(.bottom,bottom+20)
        }.frame(width:width,height:height*0.88,alignment:.top).background(Color(hex:0xfffbf9)).clipShape(TopRoundedShape(radius:26)).position(x:width/2,y:height-height*0.88/2)
    }
    func publishStory(){
        let text=replyText.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else{notice=l("请先写点内容","Write something first");return}
        model.stories.insert(NativeStory(id:"local-\(UUID().uuidString)",text:text,created:Date().timeIntervalSince1970*1000,answers:[]),at:0)
        model.index=0;replyText="";withAnimation(transitionAnimation){utility=nil}
        notice=l("已发布","Story shared")
    }
    func morePage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:10){
            sheetHead(l("更多","More"),top:top,padBottom:14)
            VStack(spacing:10){
                moreRow("♡ "+l("保存完整讨论","Save discussion")){saveSnapshot()}
                moreRow("⚑ "+l("举报内容","Report content")){reportStory()}
                moreRow("⊘ "+l("屏蔽这条","Hide story")){hideStory()}
            }.padding(.horizontal,20)
            Spacer(minLength:0)
        }.padding(.bottom,bottom+20).frame(width:width,height:height*0.62,alignment:.top).background(Color(hex:0xfffbf9)).clipShape(TopRoundedShape(radius:26)).position(x:width/2,y:height-height*0.62/2)
    }
    func moreRow(_ title:String,action:@escaping ()->Void)->some View {
        Button(action:action) label:{
            HStack{Text(title);Spacer()}.font(.system(size:15)).foregroundColor(Color(hex:0x59484b)).padding(15).frame(maxWidth:.infinity)
                .background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xeee7e4),lineWidth:1))
        }
    }
    func saveSnapshot(){
        guard let story=model.current else{return}
        if !snapshots.contains(where:{$0.id==story.id}) { snapshots.append(story) }
        withAnimation(transitionAnimation){utility=nil}
        notice=l("快照已保存","Snapshot saved")
    }
    func reportStory(){
        guard let story=model.current else{return}
        if !reports.contains(story.id) { reports.append(story.id) }
        withAnimation(transitionAnimation){utility=nil}
        notice=l("已记录举报","Report recorded")
    }
    func hideStory(){
        guard model.stories.indices.contains(model.index) else{return}
        var t=Transaction();t.disablesAnimations=true
        withTransaction(t){ model.stories.remove(at:model.index); if model.index >= model.stories.count { model.index = max(0,model.stories.count-1) } }
        withAnimation(transitionAnimation){utility=nil}
        notice=l("已屏蔽这条烦恼","Story hidden")
    }

    // MARK: - Profile
    func profilePage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let me = l("你 · 预览","You · preview")
        let answers = model.stories.reduce(0) { $0 + $1.answers.filter { $0.author == me }.count }
        let columns = [GridItem(.flexible(),spacing:10),GridItem(.flexible(),spacing:10)]
        return VStack(spacing:0){
            HStack{
                Text(l("我的","Me")).font(.system(size:19,weight:.bold)).foregroundColor(Color(hex:0x302b32))
                Spacer()
                Button {withAnimation(transitionAnimation){utility=nil}} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x75666d)).frame(width:44,height:44)}.accessibilityLabel(l("关闭","Close"))
            }.padding(.horizontal,16).padding(.top,top+12).padding(.bottom,86)
            ScrollView {
                VStack(alignment:.leading,spacing:0){
                    VStack(alignment:.leading,spacing:8){
                        Text(l("留给自己的一角","A LITTLE SPACE FOR YOU")).font(.system(size:10)).kerning(0.8).foregroundColor(Color(hex:0xbb8b82))
                        Text(l("你的小天地，都在这里。","Your little corner, all in one place.")).font(.system(size:15,weight:.semibold)).foregroundColor(Color(hex:0x6a5152))
                    }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
                        .background(LinearGradient(stops:[.init(color:Color(hex:0xf9e5df),location:0),.init(color:Color(hex:0xf5eeea),location:0.55),.init(color:Color(hex:0xe6f1f3),location:1)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:21)).padding(.top,14)
                    LazyVGrid(columns:columns,spacing:10){
                        Button {openUtility("profile-stories")} label:{profileTile("✎",iconBG:0xfae7e2,iconColor:0xbe7770,label:l("我的烦恼","My stories"),count:model.stories.filter{$0.id.hasPrefix("local-")}.count)}
                        Button {openUtility("profile-answers")} label:{profileTile("✧",iconBG:0xe7f1f6,iconColor:0x789fb2,label:l("我的建议","My responses"),count:answers)}
                        Button {openUtility("saved")} label:{profileTile("♡",iconBG:0xfaeee6,iconColor:0xc58c78,label:l("收藏","Saved"),count:snapshots.count)}
                        Button {openUtility("activity")} label:{profileTile("◌",iconBG:0xefecf3,iconColor:0xa096b0,label:l("举报审核反馈","Report updates"),count:reports.isEmpty ? nil:reports.count)}
                    }.padding(.top,15)
                    HStack(spacing:10){
                        Text("◈").font(.system(size:18)).foregroundColor(Color(hex:0xba9087))
                        Text(l("审核界面演示","Moderation preview"))
                        Spacer(minLength:0)
                        Text("↗").foregroundColor(Color(hex:0xc7b2ab))
                    }.font(.system(size:12)).foregroundColor(Color(hex:0x76635f)).padding(.horizontal,15).padding(.vertical,13)
                        .background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xf1e7e2),lineWidth:1)).padding(.top,14)
                    Text(l("原型无账号、服务器或真实审核","Prototype: no account, server, or live moderation")).font(.system(size:10)).foregroundColor(Color(hex:0xb8aaa5)).padding(.top,17).padding(.horizontal,2)
                }.padding(.horizontal,20).padding(.bottom,bottom+20)
            }
        }.frame(width:width,height:height).background(Color(hex:0xfffbf9))
    }
    func openUtility(_ page:String){withAnimation(reduceMotion ? nil:.easeInOut(duration:0.32)){utility=page}}
    func profileTile(_ icon:String,iconBG:UInt32,iconColor:UInt32,label:String,count:Int?)->some View {
        VStack(alignment:.leading,spacing:0){
            Text(icon).font(.system(size:20)).foregroundColor(Color(hex:iconColor)).frame(width:34,height:34).background(Color(hex:iconBG),in:RoundedRectangle(cornerRadius:12))
            Spacer(minLength:12)
            HStack(alignment:.firstTextBaseline,spacing:7){
                Text(label).font(.system(size:13,weight:.bold)).foregroundColor(Color(hex:0x59484b))
                if let count { Text("\(count)").font(.system(size:11,weight:.medium)).foregroundColor(Color(hex:0xb5a39e)) }
            }
        }.padding(14).frame(maxWidth:.infinity,minHeight:132,alignment:.leading)
            .background(.white,in:RoundedRectangle(cornerRadius:19)).overlay(RoundedRectangle(cornerRadius:19).stroke(Color(hex:0xf2e8e3),lineWidth:1))
            .overlay(Text("↗").font(.system(size:15)).foregroundColor(Color(hex:0xc5b5af)).padding(.top,15).padding(.trailing,15),alignment:.topTrailing)
    }
    func libraryPage(_ page:String,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let me = l("你 · 预览","You · preview")
        let title:String, intro:String, empty:String
        switch page {
        case "profile-stories": title=l("我的烦恼","My stories");intro=l("写下的心事，会在这里停留 24 小时。","Your stories stay here for 24 hours.");empty=l("还没有发布过烦恼。","You haven’t shared a story yet.")
        case "profile-answers": title=l("我的建议","My responses");intro=l("你留下的建议，都在这里。","The conversations you have joined.");empty=l("还没有发表过建议。","You haven’t shared a response yet.")
        case "saved": title=l("我的私密快照","Your private snapshots");intro=l("只属于你的讨论留存，烦恼到期或被移除时一同删除。","Your private snapshots are deleted when their stories expire or are removed.");empty=l("还没有收藏过讨论。","No saved discussions yet.")
        default: title=l("举报审核反馈","Report updates");intro=l("这里会显示你提交过的反馈。","Your reports appear here.");empty=l("暂时没有新动态","Nothing new here yet")
        }
        var items:[(String,String)] = []
        if page=="profile-answers" { for story in model.stories { for answer in story.answers where answer.author==me { items.append((answer.text,story.text)) } } }
        if page=="profile-stories" { for story in model.stories where story.id.hasPrefix("local-") { items.append((story.text,l("原生预览 · 仅本机","Native preview · this device only"))) } }
        if page=="saved" { for story in snapshots { items.append((story.text,l("快照 · 只读","Snapshot · read only"))) } }
        if page=="activity" { for id in reports { items.append((model.stories.first{$0.id==id}?.text ?? l("已移除的烦恼","A removed story"),l("举报已记录 · 原型不进入真实审核","Report recorded · prototype only"))) } }
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
                    }
                }.padding(.horizontal,20).padding(.bottom,bottom+20)
            }
        }.frame(width:width,height:height).background(Color(hex:0xfffaf8))
    }

    // MARK: - Reply layer
    func replyOverlay(_ answer:NativeAnswer,width:CGFloat,height:CGFloat,top:CGFloat)->some View {
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                Button {withAnimation(transitionAnimation){selectedReply=nil}} label:{Text("‹").font(.system(size:32,weight:.light)).foregroundColor(Color(hex:0x5d5055)).frame(width:42,height:42).background(Color(hex:0xf2eae6),in:Circle())}.accessibilityLabel(l("返回评论","Back to comments"))
                Text(l("回复","Replies")).font(.system(size:19,weight:.bold))
                Spacer()
            }.padding(.horizontal,20).padding(.top,top+18).padding(.bottom,16)
            ScrollView {
                VStack(alignment:.leading,spacing:12){
                    VStack(alignment:.leading,spacing:0){
                        Text(answer.author).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x9a8888))
                        Text(answer.text).font(.system(size:14)).lineSpacing(max(0,14*1.6-UIFont.systemFont(ofSize:14).lineHeight)).padding(.vertical,12)
                    }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(Color(hex:0xf0e9e7),lineWidth:1)).shadow(color:Color(hex:0x654c53).opacity(0.09),radius:12,y:8)
                    Text(l("全部回复","Replies")).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x9a8888)).padding(.top,4)
                    if answer.replies.isEmpty {
                        Text(l("还没有回复，来接住这句话吧。","No replies yet. Be the first to respond.")).font(.system(size:14)).foregroundColor(Color(hex:0xa09494)).frame(maxWidth:.infinity).padding(.vertical,30)
                    } else {
                        ForEach(Array(answer.replies.enumerated()),id:\.offset){ _,reply in
                            HStack(alignment:.top,spacing:0){
                                Rectangle().fill(Color(hex:0xe7dedc)).frame(width:2)
                                (Text(reply.author).font(.system(size:12,weight:.bold))+Text(" ")+Text(reply.text).font(.system(size:13))).foregroundColor(Color(hex:0x817276)).padding(.leading,10)
                            }.fixedSize(horizontal:false,vertical:true)
                        }
                    }
                }.padding(.horizontal,20).padding(.bottom,18)
            }
            HStack(spacing:9){
                TextField(l("写下回复…","Write a reply…"),text:$replyText).font(.system(size:16)).padding(.horizontal,13).padding(.vertical,13).frame(minHeight:48).background(Color(hex:0xf3efed),in:RoundedRectangle(cornerRadius:16))
                Button {replyText=""} label:{Text(l("发送","Send")).font(.system(size:15,weight:.bold)).foregroundColor(.white).padding(.horizontal,16).frame(minHeight:44).background(Color(hex:0x413942),in:RoundedRectangle(cornerRadius:16))}
            }.padding(.horizontal,20).padding(.top,12)
        }.frame(width:width,height:height,alignment:.top).background(Color(hex:0xfffaf8))
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
