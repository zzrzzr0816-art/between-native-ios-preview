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
    func utilityPage(_ page:String,width:CGFloat,height:CGFloat,top:CGFloat,bottom:CGFloat)->some View {
        VStack(alignment:.leading,spacing:18){
            HStack{Button {withAnimation(transitionAnimation){utility=nil}} label:{Image(systemName:"chevron.left").frame(width:44,height:44)};Text(page=="write" ? l("说说你的烦恼","What's on your mind?"):page=="profile" ? l("我的","Me"):l("更多","More")).font(.system(size:22,weight:.bold));Spacer()}.padding(.top,top+12)
            if page=="write" {
                Text(l("匿名发布","Anonymous")).font(.system(size:12,weight:.bold)).foregroundColor(NativeCamp.devil.accent)
                TextEditor(text:$replyText).font(.system(size:17)).padding(12).background(.white,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(Color(hex:0xf5e6df),lineWidth:1))
                Text(l("原生发布页面预览，内容不会提交服务器。","Native compose preview. This draft is not sent to the server.")).font(.system(size:12)).foregroundColor(H5Design.muted)
            }else{
                Text(l("你的小天地，都在这里。","Your little corner, all in one place.")).font(.system(size:15)).padding(20).frame(maxWidth:.infinity,alignment:.leading).background(H5Design.background,in:RoundedRectangle(cornerRadius:21))
                ForEach([l("我的烦恼","My stories"),l("我的建议","My responses"),l("收藏","Saved"),l("举报审核反馈","Report updates")],id:\.self){title in
                    HStack{Text(title);Spacer();Image(systemName:"chevron.right").font(.system(size:12))}.font(.system(size:15,weight:.medium)).padding(18).background(.white,in:RoundedRectangle(cornerRadius:18))
                }
                Text(l("原生页面布局预览，个人功能尚未接入。","Native layout preview. Personal features are not connected yet.")).font(.system(size:12)).foregroundColor(H5Design.muted);Spacer()
            }
        }.padding(.horizontal,22).padding(.bottom,bottom+24).frame(width:width,height:height).background(Color(hex:0xfffaf8))
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
