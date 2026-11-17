import SwiftUI

extension ContentView {
    func comments(_ chosen:NativeCamp,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:12){
                Button {closeComments()} label:{Image(systemName:"chevron.left").font(.system(size:17,weight:.light)).frame(width:42,height:44)}.accessibilityLabel(l("返回烦恼","Back to story"))
                Text(l("大家的建议","The conversation")).font(.system(size:19,weight:.bold));Spacer()
            }.padding(.leading,14).padding(.top,top+20).padding(.bottom,115)
            HStack(spacing:8){campTab(.devil,chosen:chosen,count:devilCount);campTab(.angel,chosen:chosen,count:angelCount)}.padding(.horizontal,20).padding(.top,14).padding(.bottom,12)
            ScrollView {
                VStack(spacing:10){
                    let answers=model.current?.answers.filter {$0.side==chosen.rawValue} ?? []
                    if answers.isEmpty {Text(l("还没有建议，来做第一个吧","No responses yet. Start the conversation")).font(.system(size:14)).foregroundColor(.secondary).padding(.top,35)}
                    ForEach(answers){answer in commentCard(answer)}
                }.padding(.horizontal,20).padding(.top,10).padding(.bottom,18)
            }
            Spacer(minLength:0)
            HStack(spacing:9){
                TextField(l("说点什么…","Say something kind…"),text:$composer).font(.system(size:16)).padding(.horizontal,13).frame(height:42).background(Color(hex:0xf7f4f1),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xeee8e4),lineWidth:1)).focused($composerFocused)
                Button {sendPreview(chosen)} label:{HStack(spacing:5){Text(l("发送","Send"));Text("↑").font(.system(size:17))}.font(.system(size:13,weight:.bold)).foregroundColor(.white).frame(width:74,height:46).background(chosen.accent,in:RoundedRectangle(cornerRadius:15))}
            }.padding(.horizontal,16).padding(.top,11).padding(.bottom,bottom+12).background(Color(hex:0xfffdfb))
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
            HStack(spacing:7){Circle().fill(value.accent.opacity(0.8)).frame(width:7,height:7);Text(value == .devil ? l("恶魔","Devil"):l("天使","Angel"));Text("\(count)").opacity(0.7)}
                .font(.system(size:13,weight:.bold)).foregroundColor(Color(hex:chosen==value ? (value == .devil ? 0x994d49:0x426d88):0x756a6b)).padding(.horizontal,16).frame(height:36)
                .background(chosen==value ? Color(hex:value == .devil ? 0xf8d5ce:0xd8eaf5):Color(hex:0xf4efed),in:Capsule())
        }
    }
    func commentCard(_ answer:NativeAnswer)->some View {
        Button {withAnimation(transitionAnimation){selectedReply=answer}} label:{
            VStack(alignment:.leading,spacing:12){
                Text(answer.author).font(.system(size:12,weight:.bold)).foregroundColor(Color(hex:0x9a8888))
                Text(answer.text).font(.system(size:14)).lineSpacing(6).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading)
                HStack(spacing:5){Image(systemName:"heart").font(.system(size:16,weight:.light));Text("\(answer.likes)").font(.system(size:12))}.foregroundColor(Color(hex:0x877a7a)).padding(.horizontal,11).frame(height:38).background(Color(hex:0xf8f4f2),in:Capsule())
            }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
                .background(LinearGradient(colors:[.white,Color(hex:0xfffaf7)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:18))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(.white,lineWidth:1)).shadow(color:Color(hex:0xaa8e85).opacity(0.12),radius:12,y:8)
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
    func utilityPage(_ page:String,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->AnyView {
        if page == "profile" { return AnyView(profilePage(width:width,height:height,top:top,bottom:bottom)) }
        return AnyView(VStack(alignment:.leading,spacing:18){
            HStack{Button {withAnimation(transitionAnimation){utility=nil}} label:{Image(systemName:"chevron.left").frame(width:44,height:44)};Text(page=="write" ? l("说说你的烦恼","What's on your mind?"):l("更多","More")).font(.system(size:22,weight:.bold));Spacer()}.padding(.top,top+12)
            if page=="write" {
                Text(l("匿名发布","Anonymous")).font(.system(size:12,weight:.bold)).foregroundColor(NativeCamp.devil.accent)
                TextEditor(text:$replyText).font(.system(size:17)).padding(12).background(.white,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(Color(hex:0xf5e6df),lineWidth:1))
                Text(l("原生发布页面预览，内容不会提交服务器。","Native compose preview. This draft is not sent to the server.")).font(.system(size:12)).foregroundColor(H5Design.muted)
            }else{
                Text(l("你的小天地，都在这里。","Your little corner, all in one place.")).font(.system(size:15)).padding(20).frame(maxWidth:.infinity,alignment:.leading).background(H5Design.background,in:RoundedRectangle(cornerRadius:21))
            }
        }.padding(.horizontal,22).padding(.bottom,bottom+24).frame(width:width,height:height).background(Color(hex:0xfffaf8)))
    }
    func profilePage(width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        let me = l("你 · 预览","You · preview")
        let answers = model.stories.reduce(0) { $0 + $1.answers.filter { $0.author == me }.count }
        let stories = 0
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
                        profileTile("✎",iconBG:0xfae7e2,iconColor:0xbe7770,label:l("我的烦恼","My stories"),count:stories)
                        profileTile("✧",iconBG:0xe7f1f6,iconColor:0x789fb2,label:l("我的建议","My responses"),count:answers)
                        profileTile("♡",iconBG:0xfaeee6,iconColor:0xc58c78,label:l("收藏","Saved"),count:0)
                        profileTile("◌",iconBG:0xefecf3,iconColor:0xa096b0,label:l("举报审核反馈","Report updates"),count:nil)
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
    func replyOverlay(_ answer:NativeAnswer,width:CGFloat,height:CGFloat,top:CGFloat)->some View {
        ZStack{
            Color.black.opacity(0.35).onTapGesture{withAnimation(transitionAnimation){selectedReply=nil}}
            VStack(spacing:16){
                HStack{Button {withAnimation(transitionAnimation){selectedReply=nil}} label:{Image(systemName:"chevron.left").frame(width:36,height:36)};Text(l("回复","Replies")).font(.headline);Spacer()}
                VStack(alignment:.leading,spacing:12){Text(answer.author).font(.caption.bold()).foregroundColor(H5Design.muted);Text(answer.text).font(.system(size:15)).lineSpacing(6)}.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:18))
                Text(l("还没有回复","No replies yet")).font(.system(size:14)).foregroundColor(H5Design.muted).padding(.vertical,25)
                TextField(l("写下回复…","Write a reply…"),text:$replyText).font(.system(size:16)).padding(14).background(Color(hex:0xf7f4f1),in:RoundedRectangle(cornerRadius:16))
                Text(l("回复层交互预览","Reply interaction preview")).font(.caption).foregroundColor(H5Design.muted)
            }.padding(18).frame(width:width-36).background(Color(hex:0xfffaf8),in:RoundedRectangle(cornerRadius:26)).position(x:width/2,y:min(height/2,top+320))
        }.frame(width:width,height:height)
    }
}
