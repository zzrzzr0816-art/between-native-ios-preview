import SwiftUI
import WebKit

/// The companions are rendered with the H5's own character markup, CSS and
/// keyframes so shape, proportions, expressions and idle motion stay identical
/// to the design. Native only forwards leader state and pointer gestures.
struct CompanionRig: View {
    let angel: Bool
    var cheer: CGFloat
    var reply: CGFloat
    var strong: Bool
    var chinese: Bool
    var reaction: String
    var gesture: CGFloat
    var settling: Bool = false
    var stageScale: CGFloat = 1
    var buddyScale: CGFloat = 1.15
    var peek: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bridge = BuddyBridge()
    @State private var dragging = false

    private var leader: String {
        if cheer > 0 { return angel ? "angel" : "devil" }
        if reply > 0 { return angel ? "devil" : "angel" }
        return "tie"
    }
    private var gap: String { leader == "tie" ? "tie" : (strong ? "strong" : "slight") }

    var body: some View {
        ZStack {
            BuddyWebView(angel: angel, leader: leader, gap: gap, motion: !reduceMotion, bridge: bridge)
            Color.clear
                .frame(width: 67, height: 67)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !dragging {
                                dragging = true
                                bridge.run("buddyDown()")
                            }
                            bridge.run("buddyMove(\(value.translation.width),\(value.translation.height))")
                        }
                        .onEnded { value in
                            bridge.run("buddyUp()")
                            if hypot(value.translation.width, value.translation.height) < 5 {
                                let radius = 58.0 * 1.15 / 2
                                let nx = max(-1, min(1, (value.startLocation.x - 33.5) / radius))
                                let ny = max(-1, min(1, (value.startLocation.y - 33.5) / radius))
                                bridge.run("buddyTap(\(nx),\(ny))")
                            }
                            dragging = false
                        }
                )
        }
        .frame(width: 250, height: 250)
        .onAppear {
            push()
            bridge.run("setLang(\(chinese))")
            bridge.run("setBuddyScale(\(Double(buddyScale)))")
            bridge.run("setPeek(\(peek))")
        }
        .onChange(of: leader) { _ in push() }
        .onChange(of: gap) { _ in push() }
        .onChange(of: reaction) { _ in push() }
        .onChange(of: gesture) { _ in push() }
        .onChange(of: settling) { _ in push() }
        .onChange(of: chinese) { _ in bridge.run("setLang(\(chinese))") }
        .onChange(of: reduceMotion) { _ in bridge.run("setMotion(\(!reduceMotion))") }
        .onChange(of: buddyScale) { _ in bridge.run("setBuddyScale(\(Double(buddyScale)))") }
        .onChange(of: peek) { _ in bridge.run("setPeek(\(peek))") }
        .accessibilityLabel(angel ? "Angel companion" : "Devil companion")
    }

    private func push() {
        bridge.run("setState('\(leader)','\(gap)','\(reaction)',\(Double(gesture)),\(settling))")
        bridge.run("setScale(\(Double(stageScale)))")
    }
}

private final class BuddyBridge {
    private weak var web: WKWebView?
    private var ready = false
    private var queue: [String] = []

    func run(_ js: String) {
        guard ready, let web = web else { queue.append(js); return }
        web.evaluateJavaScript(js, completionHandler: nil)
    }

    func attach(_ web: WKWebView) {
        self.web = web
        ready = true
        let pending = queue
        queue.removeAll()
        pending.forEach { web.evaluateJavaScript($0, completionHandler: nil) }
    }

    func detach() {
        web = nil
        ready = false
    }
}

private struct BuddyWebView: UIViewRepresentable {
    let angel: Bool
    let leader: String
    let gap: String
    let motion: Bool
    let bridge: BuddyBridge

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isUserInteractionEnabled = false
        web.navigationDelegate = context.coordinator
        bridge.detach()
        web.loadHTMLString(BuddyHTML.page(angel: angel, leader: leader, gap: gap, motion: motion), baseURL: nil)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let bridge: BuddyBridge
        init(bridge: BuddyBridge) { self.bridge = bridge }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.attach(webView)
        }
    }
}

private enum BuddyHTML {
    static func page(angel: Bool, leader: String, gap: String, motion: Bool) -> String {
        let body = angel
            ? #"<div class="buddy buddy-angel" data-buddy="angel"><span class="halo"></span><span class="wing wing-left"></span><span class="wing wing-right"></span><span class="buddy-face"><i class="eye"></i><i class="eye"></i><i class="smile"></i></span><span class="spark">✧</span></div>"#
            : #"<div class="buddy buddy-devil" data-buddy="devil"><span class="horn horn-left"></span><span class="horn horn-right"></span><span class="buddy-face"><i class="eye"></i><i class="eye"></i><i class="smile"></i></span><span class="spark">✦</span></div>"#
        return #"""
        <!doctype html><html lang="en" data-motion="\#(motion ? "on" : "off")"><head><meta charset="utf-8">
        <meta name="viewport" content="width=250,initial-scale=1,maximum-scale=1,user-scalable=no">
        <style>
        \#(css)
        </style></head><body>
        <div class="app" data-leader="\#(leader)" data-gap="\#(gap)"><div class="companions">\#(body)</div></div>
        <script>
        \#(js)
        </script></body></html>
        """#
    }

    private static let css = #"""
*{box-sizing:border-box}
@property --cheer{syntax:'<number>';inherits:true;initial-value:0}
@property --reply{syntax:'<number>';inherits:true;initial-value:0}
@property --gesture{syntax:'<number>';inherits:true;initial-value:0}
.app.settling-gesture{transition:--gesture .34s cubic-bezier(.22,1,.36,1)}
.buddy{position:relative;width:58px;height:58px;transform:translateY(calc(var(--bob) * -7px));transition:transform .3s cubic-bezier(.22,1,.36,1);animation:buddy-float 3.8s ease-in-out infinite}
.buddy-angel{animation-delay:-1.8s}
.buddy-face{position:absolute;inset:12px 7px 4px;background:#e99386;border-radius:47% 48% 45% 46%;box-shadow:inset 0 -4px 0 #d1766b40,0 5px 12px #a55f6326;display:flex;align-items:center;justify-content:center;gap:10px}
.buddy-angel .buddy-face{background:#9bc8dc;box-shadow:inset 0 -4px 0 #6fa5c433,0 5px 12px #6398b626}
.eye{display:block;width:4px;height:6px;border-radius:50%;background:#61474b;animation:blink 5s infinite}
.buddy-angel .eye{background:#426779;animation-delay:-2s}
.smile{position:absolute;left:50%;bottom:10px;width:9px;height:5px;border-bottom:2px solid #795356;border-radius:0 0 9px 9px;transform:translateX(-50%)}
.buddy-devil .smile{width:10px;border-radius:0 0 8px 2px;transform:translateX(-50%) rotate(-8deg)}
.horn{position:absolute;top:7px;width:13px;height:16px;background:#d56e67;border-radius:90% 5% 30% 20%}
.horn-left{left:9px;transform:rotate(-25deg)}
.horn-right{right:9px;transform:scaleX(-1) rotate(-25deg)}
.halo{position:absolute;z-index:2;top:1px;left:14px;width:30px;height:9px;border:3px solid #e6bd75;border-radius:50%;transform:rotate(-8deg)}
.wing{position:absolute;top:24px;width:16px;height:18px;background:#fffdf8;border-radius:70% 20% 70% 25%;box-shadow:0 2px 5px #7fa6b52b}
.wing-left{left:0;transform:rotate(-28deg)}
.wing-right{right:0;transform:scaleX(-1) rotate(-28deg)}
.spark{position:absolute;right:-2px;top:6px;color:#c88678;font-size:14px;opacity:.7;animation:twinkle 2.8s ease-in-out infinite}
.buddy-angel .spark{color:#6c9db6;left:-4px;right:auto;animation-delay:-1.2s}
.app[data-reaction=devil] .buddy-devil{animation:none;transform:translate(calc(var(--gesture)*12px),calc(var(--gesture)*-10px)) rotate(calc(var(--gesture)*12deg)) scale(calc(1 + var(--gesture)*.18))}
.app[data-reaction=angel] .buddy-angel{animation:none;transform:translate(calc(var(--gesture)*-12px),calc(var(--gesture)*-10px)) rotate(calc(var(--gesture)*-12deg)) scale(calc(1 + var(--gesture)*.18))}
.app[data-reaction=devil] .buddy-devil .smile,.app[data-reaction=angel] .buddy-angel .smile{height:8px;background:#794e51;border:0;border-radius:2px 2px 7px 7px}
.app[data-reaction=devil] .buddy-angel,.app[data-reaction=angel] .buddy-devil{opacity:.55}
.buddy .eye{transform-origin:center}
@keyframes buddy-float{0%,100%{translate:0 0;rotate:-3deg}50%{translate:0 -6px;rotate:3deg}}
@keyframes blink{0%,44%,48%,100%{transform:scaleY(1)}46%{transform:scaleY(.12)}}
@keyframes twinkle{0%,100%{transform:scale(.7);opacity:.45}50%{transform:scale(1.2);opacity:1}}
.eye{height:8px;width:4px;animation:visible-blink 3.8s ease-in-out infinite}
.buddy-angel .eye{animation-delay:-1.7s}
.app[data-leader=devil] .buddy-devil .buddy-face{animation:devil-showoff 2.3s ease-in-out infinite}
.app[data-leader=angel] .buddy-angel .buddy-face{animation:angel-showoff 2.5s ease-in-out infinite}
.app[data-leader=devil] .buddy-devil .spark,.app[data-leader=angel] .buddy-angel .spark{opacity:1;font-size:19px;animation:cheer-spark 1.25s ease-in-out infinite}
.app[data-leader=devil] .buddy-devil .smile,.app[data-leader=angel] .buddy-angel .smile{height:7px;background:#80565b;border:0;border-radius:2px 2px 8px 8px}
.app[data-leader=angel] .buddy-angel .wing{animation:wing-flap 1s ease-in-out infinite alternate}
.app[data-leader=devil] .buddy-devil .horn{animation:horn-tilt 1.15s ease-in-out infinite alternate}
@keyframes visible-blink{0%,39%,53%,100%{transform:scaleY(1)}43%,49%{transform:scaleY(.12)}}
@keyframes devil-showoff{0%,100%{rotate:-4deg;translate:0 0}30%{rotate:10deg;translate:0 -5px}60%{rotate:-8deg;translate:2px -2px}}
@keyframes angel-showoff{0%,100%{rotate:0deg;translate:0 0}35%{rotate:-9deg;translate:0 -6px}65%{rotate:7deg;translate:0 -2px}}
@keyframes cheer-spark{0%,100%{transform:scale(.75) rotate(-10deg)}50%{transform:scale(1.3) rotate(20deg)}}
@keyframes wing-flap{from{translate:0 1px;scale:1 .8}to{translate:0 -3px;scale:1 1.15}}
@keyframes horn-tilt{from{translate:0 1px}to{translate:0 -3px}}
.buddy .eye{height:9px;width:5px;animation:clear-blink 2.8s ease-in-out infinite}
.buddy-angel .eye{animation-delay:-1.25s}
@keyframes clear-blink{0%,25%,45%,100%{transform:scaleY(1)}30%,38%{transform:scaleY(.08)}}
.app[data-leader=devil] .buddy-devil .buddy-face{animation:devil-celebrate 4s ease-in-out infinite}
.app[data-leader=devil] .buddy-angel .buddy-face{animation:angel-reply 4s ease-in-out infinite}
.app[data-leader=angel] .buddy-angel .buddy-face{animation:angel-celebrate 4s ease-in-out infinite}
.app[data-leader=angel] .buddy-devil .buddy-face{animation:devil-reply 4s ease-in-out infinite}
.app[data-leader=devil] .buddy-angel .eye{animation:angel-look 4s ease-in-out infinite}
.app[data-leader=angel] .buddy-devil .eye{animation:devil-look 4s ease-in-out infinite}
.app[data-leader=devil] .buddy-angel .smile,.app[data-leader=angel] .buddy-devil .smile{height:7px;width:7px;border:2px solid #826a70;background:transparent;border-radius:50%;animation:surprised-mouth 4s ease-in-out infinite}
.app[data-leader=devil] .buddy-devil::after,.app[data-leader=angel] .buddy-angel::after{content:'✦';position:absolute;top:-8px;right:-5px;font-size:17px;color:#d9a35f;animation:cheer-pop 4s ease-in-out infinite}
.app[data-leader=devil] .buddy-angel::after,.app[data-leader=angel] .buddy-devil::after{content:'!';position:absolute;top:-6px;right:-4px;font-weight:800;font-size:16px;color:#a67a7e;animation:reply-pop 4s ease-in-out infinite}
@keyframes devil-celebrate{0%,100%{transform:translate(0,0) rotate(0)}15%{transform:translate(3px,-6px) rotate(12deg)}27%{transform:translate(0,-1px) rotate(-7deg)}40%,70%{transform:translate(2px,-3px) rotate(5deg)}}
@keyframes angel-celebrate{0%,100%{transform:translate(0,0) rotate(0)}15%{transform:translate(-3px,-7px) rotate(-11deg)}28%{transform:translate(0,-1px) rotate(7deg)}40%,70%{transform:translate(-2px,-3px) rotate(-5deg)}}
@keyframes angel-reply{0%,18%,100%{transform:translate(0,0) rotate(0)}30%{transform:translate(3px,2px) rotate(9deg)}48%{transform:translate(-3px,-4px) rotate(-8deg)}63%{transform:translate(-1px,0) rotate(-3deg)}}
@keyframes devil-reply{0%,18%,100%{transform:translate(0,0) rotate(0)}30%{transform:translate(-3px,2px) rotate(-9deg)}48%{transform:translate(3px,-4px) rotate(8deg)}63%{transform:translate(1px,0) rotate(3deg)}}
@keyframes angel-look{0%,15%,65%,100%{transform:translateX(0) scaleY(1)}25%,50%{transform:translateX(-3px) scaleY(1)}38%,42%{transform:translateX(-3px) scaleY(.08)}}
@keyframes devil-look{0%,15%,65%,100%{transform:translateX(0) scaleY(1)}25%,50%{transform:translateX(3px) scaleY(1)}38%,42%{transform:translateX(3px) scaleY(.08)}}
@keyframes surprised-mouth{0%,18%,70%,100%{transform:translateX(-50%) scale(.6)}30%,50%{transform:translateX(-50%) scale(1)}}
@keyframes cheer-pop{0%,8%,75%,100%{opacity:0;transform:translateY(4px) scale(.4)}20%,55%{opacity:1;transform:translateY(-5px) scale(1.2)}}
@keyframes reply-pop{0%,18%,65%,100%{opacity:0;transform:translateY(4px) scale(.4)}30%,48%{opacity:1;transform:translateY(-4px) scale(1)}}
html[data-motion=on] .buddy{animation:buddy-float 3.8s ease-in-out infinite!important}
html[data-motion=on] .buddy-angel{animation-delay:-1.8s!important}
html[data-motion=on] .buddy .eye{animation:clear-blink 2.8s ease-in-out infinite!important}
html[data-motion=on] .buddy-angel .eye{animation-delay:-1.25s!important}
html[data-motion=on] .buddy .spark{animation:twinkle 2.8s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=devil] .buddy-devil .buddy-face{animation:devil-celebrate 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=devil] .buddy-angel .buddy-face{animation:angel-reply 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=angel] .buddy-angel .buddy-face{animation:angel-celebrate 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=angel] .buddy-devil .buddy-face{animation:devil-reply 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=devil] .buddy-angel .eye{animation:angel-look 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=angel] .buddy-devil .eye{animation:devil-look 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=devil] .buddy-devil::after,html[data-motion=on] .app[data-leader=angel] .buddy-angel::after{animation:cheer-pop 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=devil] .buddy-angel::after,html[data-motion=on] .app[data-leader=angel] .buddy-devil::after{animation:reply-pop 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader=angel] .buddy-angel .wing{animation:wing-flap 1s ease-in-out infinite alternate!important}
html[data-motion=on] .app[data-leader=devil] .buddy-devil .horn{animation:horn-tilt 1.15s ease-in-out infinite alternate!important}
html[data-motion=off] .buddy,html[data-motion=off] .buddy *,html[data-motion=off] .buddy::after{animation:none!important;transition:none!important}
.companions .buddy{scale:var(--buddy-scale,1.15)}
.app.peek-mode .buddy{clip-path:inset(0 -15px 43% -15px)}
.buddy{--cheer:0;--reply:0;transition:--cheer 1.1s ease,--reply 1.1s ease,transform .3s cubic-bezier(.22,1,.36,1),opacity .3s ease}
.app[data-leader=devil] .buddy-devil,.app[data-leader=angel] .buddy-angel{--cheer:1}
.app[data-leader=devil] .buddy-angel,.app[data-leader=angel] .buddy-devil{--reply:1}
html[data-motion=on] .buddy .buddy-face{animation:companion-conversation 4s ease-in-out infinite!important}
html[data-motion=on] .buddy .eye{animation:continuous-eyes 3.4s ease-in-out infinite!important}
html[data-motion=on] .buddy-angel .eye{animation-delay:-1.25s!important}
html[data-motion=on] .buddy .wing{animation:wing-flap 1.6s ease-in-out infinite alternate!important}
html[data-motion=on] .buddy .horn{animation:horn-tilt 1.8s ease-in-out infinite alternate!important}
.buddy .smile,.app[data-leader] .buddy .smile{width:9px;height:6px;border:0;border-bottom:2px solid #795356;background:transparent;border-radius:0 0 9px 9px;transform:translateX(-50%) scale(calc(1 + var(--reply)*.18));transition:transform 1.1s ease,border-radius 1.1s ease}
.buddy::after,.app[data-leader] .buddy::after{content:'✦';position:absolute;top:-8px;right:-5px;font-size:17px;color:#d9a35f;opacity:var(--cheer);transition:opacity 1.1s ease;pointer-events:none}
html[data-motion=on] .app[data-leader] .buddy::after{animation:continuous-spark 2.8s ease-in-out infinite!important}
@keyframes companion-conversation{0%,100%{transform:translate(0,0) rotate(0)}25%{transform:translate(calc(var(--cheer)*2px - var(--reply)*2px),calc(var(--cheer)*-5px + var(--reply)*2px)) rotate(calc(var(--cheer)*8deg - var(--reply)*6deg))}55%{transform:translate(calc(var(--reply)*2px - var(--cheer)*1px),calc(var(--reply)*-3px)) rotate(calc(var(--reply)*6deg - var(--cheer)*4deg))}80%{transform:translate(0,calc(var(--cheer)*-2px)) rotate(calc(var(--cheer)*3deg))}}
@keyframes continuous-eyes{0%,28%,44%,100%{transform:scaleY(1)}32%,39%{transform:scaleY(.08)}}
@keyframes continuous-spark{0%,100%{transform:scale(.7) rotate(-10deg)}50%{transform:scale(1.15) rotate(15deg)}}
html[data-motion=off] .buddy,html[data-motion=off] .buddy *,html[data-motion=off] .buddy::after{animation:none!important;transition:none!important}
html[data-motion=on] .app[data-leader] .buddy .buddy-face{animation:companion-conversation 4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy .eye{animation:continuous-eyes 3.4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy-angel .eye{animation-delay:-1.25s!important}
html[data-motion=on] .app[data-leader] .buddy .buddy-face{animation:none!important;transition:transform .32s ease,background-color .32s ease}
.buddy .buddy-face{transform:rotate(0);transition:transform .32s ease,background-color .32s ease}
.buddy .eye{transition:width .32s ease,height .32s ease,background-color .32s ease}
.buddy .smile,.app[data-leader] .buddy .smile{position:absolute;width:9px;height:6px;bottom:9px;border:0;border-bottom:2px solid #795356;background:transparent;border-radius:0 0 9px 9px;transform:translateX(-50%);transition:width .32s ease,height .32s ease,bottom .32s ease,border-radius .32s ease,background-color .32s ease,border-color .32s ease}
.app[data-leader=devil] .buddy-devil .buddy-face{transform:rotate(7deg);background:#ef9485}
.app[data-leader=angel] .buddy-angel .buddy-face{transform:rotate(-7deg);background:#a6d8ec}
.app[data-leader=devil] .buddy-devil .smile,.app[data-leader=angel] .buddy-angel .smile{width:12px;height:8px;bottom:8px;background:#80565b;border:0;border-radius:2px 2px 8px 8px}
.app[data-leader=devil] .buddy-angel .buddy-face{transform:rotate(6deg);background:#a9cfe0}
.app[data-leader=angel] .buddy-devil .buddy-face{transform:rotate(-6deg);background:#eaa196}
.app[data-leader=devil] .buddy-angel .eye,.app[data-leader=angel] .buddy-devil .eye{width:6px;height:9px}
.app[data-leader=devil] .buddy-angel .smile,.app[data-leader=angel] .buddy-devil .smile{width:7px;height:7px;bottom:8px;border:2px solid #795356;background:transparent;border-radius:50%}
.app[data-leader] .buddy .smile{animation:none!important}
.app[data-leader] .buddy-devil .buddy-face{background:#e99386}
.app[data-leader] .buddy-angel .buddy-face{background:#9bc8dc}
.buddy .buddy-face{transition:transform .38s ease}
.buddy .eye{position:relative;left:0;transition:left .38s ease,width .38s ease,height .38s ease}
.app[data-leader=devil] .buddy-angel .eye{left:-2px}
.app[data-leader=angel] .buddy-devil .eye{left:2px}
.app[data-leader=devil] .buddy-devil .eye,.app[data-leader=angel] .buddy-angel .eye{height:6px;width:5px}
.buddy .buddy-face::before,.buddy .buddy-face::after{content:'';position:absolute;top:12px;width:7px;height:2px;background:#73565a;border-radius:4px;opacity:0;transition:opacity .38s ease,transform .38s ease}
.buddy .buddy-face::before{left:10px}
.buddy .buddy-face::after{right:10px}
.buddy-angel .buddy-face::before,.buddy-angel .buddy-face::after{background:#55788a}
.app[data-leader=devil] .buddy-angel .buddy-face::before,.app[data-leader=angel] .buddy-devil .buddy-face::before{opacity:.75;transform:translateY(-2px) rotate(-12deg)}
.app[data-leader=devil] .buddy-angel .buddy-face::after,.app[data-leader=angel] .buddy-devil .buddy-face::after{opacity:.75;transform:translateY(-2px) rotate(12deg)}
.app[data-leader=devil] .buddy-devil .buddy-face::before,.app[data-leader=angel] .buddy-angel .buddy-face::after{opacity:.6;transform:translateY(-1px) rotate(-10deg)}
.buddy .buddy-face::before,.buddy .buddy-face::after{opacity:.68!important;transform:translateY(0) rotate(0);transition:transform .38s ease}
.app[data-leader=devil] .buddy-angel .buddy-face::before,.app[data-leader=angel] .buddy-devil .buddy-face::before{transform:translateY(-2px) rotate(-12deg)}
.app[data-leader=devil] .buddy-angel .buddy-face::after,.app[data-leader=angel] .buddy-devil .buddy-face::after{transform:translateY(-2px) rotate(12deg)}
.app[data-leader=devil] .buddy-devil .buddy-face::before,.app[data-leader=angel] .buddy-angel .buddy-face::after{transform:translateY(-1px) rotate(-10deg)}
.buddy .buddy-face::before,.buddy .buddy-face::after{top:9px;width:9px;height:2.5px;opacity:1!important;background:#5a3f42}
.buddy-angel .buddy-face::before,.buddy-angel .buddy-face::after{background:#355b70}
.buddy .buddy-face::before{left:9px}
.buddy .buddy-face::after{right:9px}
.buddy .buddy-face::before,.buddy .buddy-face::after{width:7px;height:2px;opacity:.68!important}
.buddy .buddy-face::before{left:10px}
.buddy .buddy-face::after{right:10px}
.buddy .buddy-face::before,.buddy .buddy-face::after{top:12px;width:7px;height:2px;background:#73565a;opacity:.68!important}
.buddy-angel .buddy-face::before,.buddy-angel .buddy-face::after{background:#55788a}
.buddy .buddy-face::before{left:10px}
.buddy .buddy-face::after{right:10px}
.buddy{--spark-level:0}
.app[data-leader=devil] .buddy-devil,.app[data-leader=angel] .buddy-angel{--spark-level:.48}
.app[data-gap=strong][data-leader=devil] .buddy-devil,.app[data-gap=strong][data-leader=angel] .buddy-angel{--spark-level:.8}
.app[data-leader] .buddy::after{content:none!important;animation:none!important}
.app[data-leader] .buddy .spark{font-size:13px;opacity:0;transition:opacity .7s ease;will-change:transform,opacity}
html[data-motion=on] .app[data-leader] .buddy .spark{animation:gentle-spark 5.5s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy-angel .spark{animation-delay:-2.4s!important}
@keyframes gentle-spark{0%,22%,100%{opacity:0;transform:translateY(2px) scale(.65) rotate(-8deg)}40%,54%{opacity:var(--spark-level);transform:translateY(-3px) scale(1) rotate(8deg)}72%{opacity:0;transform:translateY(-5px) scale(.8) rotate(12deg)}}
html[data-motion=off] .app[data-leader] .buddy .spark{opacity:var(--spark-level);animation:none!important}
.buddy .buddy-face{transition:transform .45s cubic-bezier(.2,.7,.2,1)}
.buddy .smile,.buddy .eye{transition-duration:.45s}
html[data-motion=on] .app[data-leader] .buddy .spark{animation-duration:2.8s!important}
html[data-motion=on] .app[data-leader] .buddy-angel .spark{animation-delay:-1.2s!important}
/* Both characters share one continuous, gentle interaction rhythm. */
html[data-motion=on] .app[data-leader] .buddy .buddy-face{animation:paired-reaction 4.6s ease-in-out infinite!important;will-change:translate,rotate}
.buddy-devil .buddy-face{--toward:1}
.buddy-angel .buddy-face{--toward:-1}
@keyframes paired-reaction{0%,100%{translate:0 0;rotate:0deg}18%{translate:calc(var(--toward)*var(--cheer)*2px) calc(var(--cheer)*-4px);rotate:calc(var(--toward)*var(--cheer)*7deg)}35%{translate:calc(var(--toward)*var(--reply)*2px) calc(var(--reply)*1px);rotate:calc(var(--toward)*var(--reply)*-6deg)}54%{translate:calc(var(--toward)*var(--reply)*-1px) calc(var(--reply)*-2px + var(--cheer)*-1px);rotate:calc(var(--toward)*(var(--reply)*4deg - var(--cheer)*3deg))}75%{translate:0 0;rotate:0deg}}
html[data-motion=off] .app[data-leader] .buddy .buddy-face{animation:none!important}
.tap-bubble{position:absolute;top:-20px;left:50%;z-index:3;min-width:24px;text-align:center;font-size:20px;font-weight:700;color:#a96d69;pointer-events:none;transform:translateX(-50%);animation:tap-bubble 1.1s ease-out forwards}
.buddy-angel .tap-bubble{color:#749bb1}
@keyframes tap-bubble{0%{opacity:0;transform:translate(-50%,8px) scale(.5)}20%,55%{opacity:1;transform:translate(-50%,-4px) scale(1.1)}100%{opacity:0;transform:translate(-50%,-15px) scale(.8)}}
html[data-motion=off] .tap-bubble{animation:none;opacity:1}
.tap-bubble{top:-28px;left:50%;width:max-content;max-width:110px;padding:5px 9px;border-radius:14px;background:#fffdf8;box-shadow:0 4px 13px #815f641f;color:#9b5752;font-size:11px;letter-spacing:0}
.buddy-angel .tap-bubble{color:#507d98}
.tap-bubble{top:100%;margin-top:5px;max-width:130px;white-space:normal;overflow:visible}
.buddy[data-tap=winning] .smile{width:14px!important;height:9px!important;background:#80565b!important;border:0!important;border-radius:2px 2px 9px 9px!important}
.buddy-devil[data-tap=behind] .buddy-face::before{transform:translateY(2px) rotate(22deg)!important}
.buddy-devil[data-tap=behind] .buddy-face::after{transform:translateY(2px) rotate(-22deg)!important}
.buddy-angel[data-tap=behind] .smile{width:8px!important;height:5px!important;background:transparent!important;border:0!important;border-top:2px solid #55788a!important;border-radius:8px 8px 0 0!important}
.buddy[data-tap=together] .eye{height:4px!important;width:6px!important;border-radius:50% 50% 20% 20%}
.buddy-angel .cheek{background:#d38898}
.buddy[data-tap=tickle] .cheek,.buddy[data-tap=together] .cheek{opacity:.62}
.buddy[data-tap=tickle] .eye{height:3px!important;width:7px!important;border-radius:50%}
.buddy[data-tap=tickle] .smile{width:13px!important;height:8px!important;background:#80565b!important;border:0!important;border-radius:2px 2px 9px 9px!important}
html[data-motion=on] .app .buddy-devil{animation:devil-idle 5.2s ease-in-out infinite!important}
html[data-motion=on] .app .buddy-angel{animation:angel-idle 7.4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy-devil .buddy-face{animation:devil-idle-face 6.4s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy-angel .buddy-face{animation:angel-idle-face 7.8s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy-devil .eye{animation:devil-idle-eyes 5.8s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy-angel .eye{animation:angel-idle-eyes 7.2s ease-in-out infinite!important;animation-delay:0s!important}
html[data-motion=on] .app[data-leader] .buddy-devil .horn{animation:devil-idle-horns 4.7s ease-in-out infinite!important}
html[data-motion=on] .app[data-leader] .buddy-angel .wing{animation:angel-idle-wings 3.8s ease-in-out infinite!important}
@keyframes devil-idle{0%,100%{translate:0 0;rotate:-2deg}18%{translate:2px -4px;rotate:5deg}25%{translate:0 0;rotate:-5deg}45%{translate:-1px -3px;rotate:3deg}68%{translate:2px -6px;rotate:6deg}76%{translate:0 0;rotate:-3deg}}
@keyframes angel-idle{0%,100%{translate:0 0;rotate:0deg}35%{translate:-2px -7px;rotate:-3deg}70%{translate:1px -3px;rotate:3deg}}
@keyframes devil-idle-face{0%,100%{translate:0 0;rotate:0deg}16%{translate:2px -1px;rotate:calc(4deg + var(--cheer)*4deg)}27%{translate:0 0;rotate:0deg}48%{translate:calc(var(--reply)*-2px) calc(var(--reply)*2px);rotate:calc(var(--reply)*-7deg)}65%{translate:calc(var(--cheer)*2px) calc(var(--cheer)*-3px);rotate:calc(var(--cheer)*8deg)}83%{translate:0 0;rotate:0deg}}
@keyframes angel-idle-face{0%,100%{translate:0 0;rotate:0deg}25%{translate:-1px -1px;rotate:-3deg}42%{translate:calc(var(--reply)*2px) calc(var(--reply)*2px);rotate:calc(var(--reply)*6deg)}62%{translate:calc(var(--cheer)*-1px) calc(var(--cheer)*-3px);rotate:calc(var(--cheer)*-5deg)}82%{translate:0 0;rotate:0deg}}
@keyframes devil-idle-eyes{0%,15%,32%,60%,100%{transform:translateX(0) scaleY(1)}20%,27%{transform:translateX(2px) scaleY(1)}39%,43%{transform:scaleY(.08)}72%,76%{transform:scaleY(.08)}}
@keyframes angel-idle-eyes{0%,18%,46%,100%{transform:translateX(0) scaleY(1)}25%,38%{transform:translateX(-2px) scaleY(1)}57%,62%{transform:scaleY(.08)}}
@keyframes devil-idle-horns{0%,55%,100%{translate:0 0}62%{translate:0 -3px}68%{translate:0 0}74%{translate:0 -2px}}
@keyframes angel-idle-wings{0%,100%{scale:1 1}35%{scale:1.08 .85}65%{scale:1.05 1.12}}
html[data-motion=off] .app .buddy,html[data-motion=off] .app .buddy *,html[data-motion=off] .app .buddy::after{animation:none!important;transition:none!important}
.companions .buddy{touch-action:none}
.buddy .cheek,.buddy[data-tap=tickle] .cheek,.buddy[data-tap=together] .cheek{display:none}
.buddy .eye{translate:var(--gaze-x,0px) var(--gaze-y,0px);transition:translate .16s ease-out,left .38s ease,width .38s ease,height .38s ease}
html[data-motion=off] .buddy .eye{translate:0 0!important}
.companions .buddy{transition:scale .34s cubic-bezier(.22,1,.36,1),opacity .34s ease,transform .3s ease}
.app[data-reaction=devil] .buddy-devil,.app[data-reaction=angel] .buddy-angel{scale:calc(1.15 + .32 * var(--gesture));opacity:1}
.app[data-reaction=devil] .buddy-angel,.app[data-reaction=angel] .buddy-devil{scale:1.15;opacity:calc(1 - var(--gesture))}
.app[data-reaction=devil] .buddy-devil,.app[data-reaction=angel] .buddy-angel{transform:none}
.app[data-reaction=devil] .buddy-devil .smile,.app[data-reaction=angel] .buddy-angel .smile{transition:width .38s ease,height .38s ease,background-color .38s ease}
.app[data-reaction] .buddy{transition:scale .06s linear,opacity .06s linear}
.app.settling-gesture[data-reaction] .buddy{transition:scale .34s cubic-bezier(.22,1,.36,1),opacity .34s ease}
.app[data-returning] .buddy{transition:scale .06s linear,opacity .06s linear}
.app.settling-gesture[data-returning] .buddy{transition:scale .3s cubic-bezier(.22,1,.36,1),opacity .3s ease}
html[data-motion] .app[data-leader] .buddy[data-grabbed=true] .eye{animation:none!important;transform:none!important}
.app[data-leader] .buddy-angel[data-grabbed=true] .eye{width:5px;height:9px;border-radius:50%}
.app[data-leader] .buddy-angel[data-grabbed=true] .smile{width:6px!important;height:7px!important;bottom:8px!important;border:1.8px solid #55788a!important;background:transparent!important;border-radius:50%!important}
.app[data-leader] .buddy-angel[data-grabbed=true] .buddy-face::before{transform:translateY(-2px) rotate(-13deg)!important}
.app[data-leader] .buddy-angel[data-grabbed=true] .buddy-face::after{transform:translateY(-2px) rotate(13deg)!important}
.app[data-leader] .buddy-devil[data-grabbed=true] .eye{width:6px;height:5px;border-radius:40%}
.app[data-leader] .buddy-devil[data-grabbed=true] .smile{width:10px!important;height:4px!important;bottom:9px!important;border:0!important;border-bottom:2px solid #795356!important;background:transparent!important;border-radius:0 0 6px 6px!important}
.app[data-leader] .buddy-devil[data-grabbed=true] .buddy-face::before{transform:translateY(1px) rotate(15deg)!important}
.app[data-leader] .buddy-devil[data-grabbed=true] .buddy-face::after{transform:translateY(1px) rotate(-15deg)!important}
/* A tug past the edge changes expression without moving outside the screen. */
.app[data-leader] .buddy[data-pulled=true] .eye{width:7px!important;height:3px!important;border-radius:50%;animation:none!important;transform:none!important}
.app[data-leader] .buddy[data-pulled=true] .smile{width:10px!important;height:5px!important;bottom:8px!important;border:0!important;border-top:2px solid #795356!important;background:transparent!important;border-radius:8px 8px 0 0!important}
.app[data-leader] .buddy[data-pulled=true] .buddy-face::before{transform:translateY(-2px) rotate(-18deg)!important}
.app[data-leader] .buddy[data-pulled=true] .buddy-face::after{transform:translateY(-2px) rotate(18deg)!important}
.app[data-leader] .buddy-angel[data-pulled=true] .smile{border-top-color:#55788a!important}
.app[data-leader] .buddy-devil:not([data-grabbed]):not([data-pulled]) .smile{width:10px;height:6px;bottom:9px;border:0;border-bottom:1.8px solid #795356;background:transparent;border-radius:0 0 10px 10px;transform:translateX(-50%) rotate(-5deg)}
.app[data-leader=devil] .buddy-devil:not([data-grabbed]):not([data-pulled]) .smile{width:12px;height:7px;transform:translateX(-50%) rotate(-8deg)}
.app[data-leader=angel] .buddy-devil:not([data-grabbed]):not([data-pulled]) .smile{width:8px;height:4px;border-bottom:0;border-top:1.8px solid #795356;border-radius:9px 9px 0 0;transform:translateX(-50%) rotate(4deg)}
.app[data-leader] .buddy-devil[data-tap=winning] .smile{width:12px!important;height:7px!important;border:0!important;border-bottom:1.8px solid #795356!important;background:transparent!important;border-radius:0 0 10px 10px!important}
html,body{margin:0;padding:0;background:transparent;overflow:visible;width:250px;height:250px;-webkit-text-size-adjust:100%;font-family:system-ui,-apple-system,'Segoe UI',sans-serif;color:#302b32}
.app{position:relative;width:250px;height:250px;margin:0;overflow:visible;background:none;box-shadow:none;--gesture:0;--bob:0}
.companions{position:absolute;left:96px;top:96px;width:58px;height:58px;display:flex;justify-content:space-between;pointer-events:none;scale:var(--stage-scale,1);transition:scale .68s cubic-bezier(.3,.05,.25,1)}

"""#

    private static let js = #"""
const app = document.querySelector('.app');
const buddy = document.querySelector('.buddy');
let drag = null, tapHistory = { time: 0, streak: 0 };
const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
window.__zh = true;

window.setLang = function (zh) { window.__zh = !!zh; };
window.setScale = function (s) {
  document.querySelector('.companions').style.setProperty('--stage-scale', s);
};
window.setBuddyScale = function (s) {
  document.documentElement.style.setProperty('--buddy-scale', s);
};
window.setPeek = function (on) {
  app.classList.toggle('peek-mode', !!on);
};
window.setMotion = function (on) { document.documentElement.dataset.motion = on ? 'on' : 'off'; };
window.setState = function (leader, gap, reaction, gesture, settling) {
  app.dataset.leader = leader;
  app.dataset.gap = gap;
  if (reaction) {
    app.dataset.reaction = reaction;
    app.style.setProperty('--gesture', gesture);
  } else {
    delete app.dataset.reaction;
    app.style.setProperty('--gesture', 0);
  }
  if (settling) {
    app.classList.add('settling-gesture');
    clearTimeout(window.__settleTimer);
    window.__settleTimer = setTimeout(() => app.classList.remove('settling-gesture'), 360);
  }
};

window.buddyDown = function () {
  buddy.getAnimations().filter(a => a.id === 'buddy-body-tap' || a.id === 'buddy-release').forEach(a => a.cancel());
  drag = { x: 0, y: 0, moved: false, offsetX: 0, offsetY: 0 };
  buddy.dataset.grabbed = 'true';
};

window.buddyMove = function (dx, dy) {
  if (!drag) return;
  if (Math.hypot(dx, dy) > 5) drag.moved = true;
  if (!drag.moved) return;
  const rubber = (n, soft) => {
    const sign = n < 0 ? -1 : 1, a = Math.abs(n);
    return sign * (a <= soft ? a : soft + (a - soft) * .22 / (1 + (a - soft) / 85));
  };
  const wantedX = dx * .85, wantedY = dy * .85;
  const x = rubber(wantedX, 55), y = rubber(wantedY, 48);
  const excessX = wantedX - clamp(wantedX, -55, 55), excessY = wantedY - clamp(wantedY, -48, 48);
  const pull = 1 - Math.exp(-Math.hypot(excessX, excessY) / 90);
  const stretch = Math.min(1, Math.hypot(x, y) / 80);
  const horizontal = Math.abs(excessX) >= Math.abs(excessY);
  const sx = 1 + stretch * .05 + (horizontal ? pull * .12 : -pull * .045);
  const sy = 1 - stretch * .04 + (horizontal ? -pull * .07 : pull * .12);
  drag.offsetX = x;
  drag.offsetY = y;
  buddy.dataset.pulled = pull > .12 ? 'true' : 'false';
  buddy.style.transition = 'none';
  buddy.style.transform = `translate(${x}px,${y}px) rotate(${clamp(dx * .12, -8, 8)}deg) scale(${sx},${sy})`;
};

window.buddyUp = function () {
  if (!drag) return;
  const p = drag;
  drag = null;
  delete buddy.dataset.grabbed;
  delete buddy.dataset.pulled;
  const heldTransform = buddy.style.transform;
  buddy.style.transition = '';
  buddy.style.transform = '';
  if (document.documentElement.dataset.motion === 'on' && p.moved && heldTransform) {
    const bounce = buddy.animate([
      { transform: heldTransform },
      { transform: `translate(${p.offsetX * -.065}px,${p.offsetY * -.065}px) scale(.97,1.035)`, offset: .68 },
      { transform: `translate(${p.offsetX * .018}px,${p.offsetY * .018}px) scale(1.015,.988)`, offset: .86 },
      { transform: 'translate(0,0) scale(1)' }
    ], { duration: 700, easing: 'cubic-bezier(.42,0,.58,1)' });
    bounce.id = 'buddy-release';
  }
};

const buddyMotions = {
  devil: {
    winning: ['rotate(0) scale(1)', 'translate(4px,-9px) rotate(15deg) scale(1.12,.94)', 'translate(-3px,1px) rotate(-10deg)', 'translate(3px,-5px) rotate(9deg)', 'rotate(0) scale(1)'],
    behind: ['rotate(0)', 'translate(-7px,2px) rotate(-24deg) scale(1.08,.96)', 'translate(4px,0) rotate(14deg)', 'translate(-5px,2px) rotate(-18deg)', 'rotate(0)'],
    together: ['rotate(0)', 'translate(8px,-4px) rotate(16deg)', 'translate(2px,0) rotate(-8deg)', 'translate(5px,-3px) rotate(10deg)', 'rotate(0)'],
    tickle: ['rotate(0)', 'rotate(-18deg) scale(1.13,.9)', 'rotate(18deg) scale(.92,1.1)', 'rotate(-14deg)', 'rotate(11deg)', 'rotate(0)']
  },
  angel: {
    winning: ['rotate(0)', 'translate(0,-10px) rotate(-7deg) scale(1.02,1.07)', 'translate(-4px,-13px) rotate(7deg)', 'translate(3px,-6px) rotate(-5deg)', 'rotate(0)'],
    behind: ['rotate(0)', 'translate(3px,4px) rotate(12deg) scale(.96,1.03)', 'translate(1px,5px) rotate(8deg)', 'translate(-2px,-2px) rotate(-4deg)', 'rotate(0)'],
    together: ['rotate(0)', 'translate(-5px,-4px) rotate(-10deg)', 'translate(-7px,-1px) rotate(-5deg)', 'translate(-3px,-3px) rotate(-8deg)', 'rotate(0)'],
    tickle: ['rotate(0)', 'translate(0,-4px) rotate(-8deg)', 'translate(-2px,-8px) rotate(8deg)', 'translate(2px,-5px) rotate(-6deg)', 'translate(0,-2px) rotate(4deg)', 'rotate(0)']
  }
};

window.buddyTap = function (tx, ty) {
  const who = buddy.dataset.buddy, leader = app.dataset.leader;
  const mood = leader === 'tie' ? 'together' : leader === who ? 'winning' : 'behind';
  const face = buddy.querySelector('.buddy-face');
  buddy.querySelector('.tap-bubble') && buddy.querySelector('.tap-bubble').remove();
  const bubble = document.createElement('span');
  bubble.className = 'tap-bubble';
  bubble.setAttribute('aria-hidden', 'true');
  const words = window.__zh
    ? { devil: { winning: '嘿，我赢啦！', behind: '哼，不服！', together: '有点意思♪', tickle: '别挠啦！' }, angel: { winning: '太好啦♡', behind: '我再努力…', together: '摸摸你♡', tickle: '痒痒！' } }
    : { devil: { winning: 'I win!', behind: 'Not fair!', together: 'Interesting!', tickle: 'Hey, stop!' }, angel: { winning: 'How lovely!', behind: 'I’ll keep trying…', together: 'A little hug!', tickle: 'Tickles!' } };
  const now = Date.now();
  tapHistory.streak = now - tapHistory.time < 1800 ? Math.min(tapHistory.streak + 1, 3) : 0;
  tapHistory.time = now;
  const action = tapHistory.streak ? 'tickle' : mood;
  bubble.textContent = words[who][action];
  buddy.append(bubble);
  buddy.dataset.tap = action;
  if (document.documentElement.dataset.motion === 'on') {
    buddy.getAnimations().filter(a => a.id === 'buddy-body-tap').forEach(a => a.cancel());
    const towardTouch = (action === 'together' || action === 'tickle') && (Math.abs(tx) + Math.abs(ty) > .05);
    const touchX = Math.round(tx * (who === 'angel' ? 8 : 6)), touchY = Math.round(ty * (who === 'angel' ? 7 : 5));
    const bodyFrames = towardTouch
      ? [{ transform: 'translate(0,0)' }, { transform: `translate(${touchX}px,${touchY}px) rotate(${Math.round(tx * (who === 'angel' ? 6 : 10))}deg) scale(1.04)` }, { transform: `translate(${Math.round(touchX * .6)}px,${Math.round(touchY * .6)}px) rotate(${Math.round(tx * -3)}deg)` }, { transform: `translate(${touchX}px,${touchY}px)` }, { transform: 'translate(0,0)' }]
      : buddyMotions[who][action].map(transform => ({ transform }));
    const bodyAction = buddy.animate(bodyFrames, { duration: who === 'angel' ? 1400 : 1050, easing: 'ease-in-out' });
    bodyAction.id = 'buddy-body-tap';
    const parts = buddy.querySelectorAll(who === 'angel' ? '.wing' : '.horn');
    parts.forEach((part, i) => {
      part.getAnimations().filter(a => a.id === 'buddy-detail-tap').forEach(a => a.cancel());
      const detail = part.animate(who === 'angel'
        ? [{ scale: '1 1' }, { scale: '1.15 .7' }, { scale: '1.08 1.2' }, { scale: '1 1' }]
        : [{ translate: '0 0' }, { translate: `${i ? -2 : 2}px -4px` }, { translate: '0 1px' }, { translate: '0 0' }],
        { duration: who === 'angel' ? 1100 : 650, iterations: who === 'angel' ? 2 : 1, easing: 'ease-in-out' });
      detail.id = 'buddy-detail-tap';
    });
    face.getAnimations().filter(a => a.id === 'buddy-tap').forEach(a => a.cancel());
    const faceAction = face.animate(who === 'angel'
      ? [{ rotate: '0deg' }, { rotate: '-7deg' }, { rotate: '3deg' }, { rotate: '0deg' }]
      : [{ rotate: '0deg' }, { rotate: '13deg' }, { rotate: '-10deg' }, { rotate: '0deg' }],
      { duration: who === 'angel' ? 1400 : 1050, easing: 'ease-in-out' });
    faceAction.id = 'buddy-tap';
  }
  setTimeout(() => { bubble.remove(); if (!buddy.querySelector('.tap-bubble')) delete buddy.dataset.tap; }, 1550);
};

"""#
}
