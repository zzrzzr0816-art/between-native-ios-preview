import SwiftUI

/// Persistent rig, using the H5's 58 x 58 coordinate space and independent timelines.
struct CompanionRig: View {
    let angel: Bool
    var cheer: CGFloat
    var reply: CGFloat
    var strong: Bool
    var available: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var epoch = Date()
    @State private var held = CGSize.zero
    @State private var grabbing = false
    @State private var tapAt = Date.distantPast
    private var ink: Color { Color(hex: angel ? 0x426779 : 0x61474b) }
    private func sample(_ t: Double, duration: Double, keys: [(Double, CGFloat)]) -> CGFloat {
        let phase = t.truncatingRemainder(dividingBy: duration) / duration
        for i in 1..<keys.count where phase <= keys[i].0 {
            let a = keys[i-1], b = keys[i], u = CGFloat((phase-a.0)/(b.0-a.0)), smooth = u*u*(3-2*u)
            return a.1+(b.1-a.1)*smooth
        }
        return keys.last?.1 ?? 0
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSince(epoch)
            let bob = angel ? sample(t, duration: 7.4, keys: [(0,0),(0.35,-7),(0.7,-3),(1,0)]) : sample(t, duration: 5.2, keys: [(0,0),(0.18,-4),(0.25,0),(0.45,-3),(0.68,-6),(0.76,0),(1,0)])
            let turn = angel ? sample(t, duration: 7.4, keys: [(0,0),(0.35,-3),(0.7,3),(1,0)]) : sample(t, duration: 5.2, keys: [(0,-2),(0.18,5),(0.25,-5),(0.45,3),(0.68,6),(0.76,-3),(1,-2)])
            let blink = angel ? sample(t, duration: 7.2, keys: [(0,1),(0.46,1),(0.57,0.08),(0.62,0.08),(0.69,1),(1,1)]) : sample(t, duration: 5.8, keys: [(0,1),(0.32,1),(0.39,0.08),(0.43,0.08),(0.48,1),(0.60,1),(0.72,0.08),(0.76,0.08),(0.82,1),(1,1)])
            let wing = sample(t, duration: 3.8, keys: [(0,1),(0.35,0.85),(0.65,1.12),(1,1)])
            let reaction = CGFloat(max(0, 1 - context.date.timeIntervalSince(tapAt) / 1.4))
            let pull = min(1, hypot(held.width, held.height) / 80)
            let faceTilt = (angel ? -1.0 : 1.0) * (Double(cheer) * 7 - Double(reply) * 6)
            ZStack(alignment: .topLeading) {
                if angel {
                    CSSCornerShape(corners: [0.7,0.2,0.7,0.25]).fill(Color(hex: 0xfffdf8)).frame(width: 16, height: 18).rotationEffect(.degrees(-28)).scaleEffect(x: 1, y: wing).position(x: 8, y: 33)
                    CSSCornerShape(corners: [0.7,0.2,0.7,0.25]).fill(Color(hex: 0xfffdf8)).frame(width: 16, height: 18).scaleEffect(x: -1, y: wing).rotationEffect(.degrees(28)).position(x: 50, y: 33)
                } else {
                    CSSCornerShape(corners: [0.9,0.05,0.3,0.2]).fill(Color(hex: 0xd56e67)).frame(width: 13, height: 16).rotationEffect(.degrees(-25)).position(x: 15.5, y: 15)
                    CSSCornerShape(corners: [0.9,0.05,0.3,0.2]).fill(Color(hex: 0xd56e67)).frame(width: 13, height: 16).scaleEffect(x: -1).rotationEffect(.degrees(25)).position(x: 42.5, y: 15)
                }
                ZStack(alignment: .topLeading) {
                    CSSCornerShape().fill(angel ? H5Design.angel : H5Design.devil)
                        .overlay(CSSCornerShape().fill(Color(hex: angel ? 0x6fa5c4 : 0xd1766b).opacity(0.2)).offset(y: 38).mask(CSSCornerShape()))
                        .shadow(color: Color(hex: angel ? 0x6398b6 : 0xa55f63).opacity(0.15), radius: 6, y: 5)
                    Capsule().fill(Color(hex: angel ? 0x55788a : 0x73565a).opacity(0.68)).frame(width: 7, height: 2).rotationEffect(.degrees(grabbing ? -15 : Double(reply)*(-12))).position(x: 13.5, y: 13)
                    Capsule().fill(Color(hex: angel ? 0x55788a : 0x73565a).opacity(0.68)).frame(width: 7, height: 2).rotationEffect(.degrees(grabbing ? 15 : Double(reply)*12)).position(x: 30.5, y: 13)
                    Ellipse().fill(ink).frame(width: 5, height: (grabbing ? 7 : 9-3*cheer)*blink).position(x: 14.5 + (angel ? -1 : 1)*reply*2, y: 21)
                    Ellipse().fill(ink).frame(width: 5, height: (grabbing ? 7 : 9-3*cheer)*blink).position(x: 29.5 + (angel ? -1 : 1)*reply*2, y: 21)
                    if grabbing {
                        Ellipse().stroke(ink, lineWidth: 1.6).frame(width: angel ? 6 : 9, height: angel ? 7 : 4).position(x: 22, y: 31)
                    } else {
                        MouthCurve().stroke(Color(hex: angel ? 0x55788a : 0x795356), style: StrokeStyle(lineWidth: 1.8, lineCap: .round)).frame(width: 9+cheer*3+reaction*2, height: 6+cheer*2).rotationEffect(.degrees(angel ? 0 : -5)).position(x: 22, y: 30)
                    }
                }.frame(width: 44, height: 42).rotationEffect(.degrees(faceTilt + (angel ? -5 : 12) * Double(reaction))).position(x: 29, y: 33)
                if angel { Ellipse().stroke(Color(hex: 0xe6bd75), lineWidth: 3).frame(width: 27, height: 6).rotationEffect(.degrees(-8)).position(x: 29, y: 5.5) }
                Text("✦").font(.system(size: 13)).foregroundColor(Color(hex: angel ? 0x6c9db6 : 0xd9a35f))
                    .opacity(Double(cheer) * (strong ? 0.8 : 0.48) * Double(max(0, sin(t * .pi * 2 / 2.8))))
                    .scaleEffect(0.75 + 0.25 * abs(sin(t * .pi / 2.8))).position(x: angel ? -3 : 59, y: 0)
            }
            .frame(width: 58, height: 58)
            .rotationEffect(.degrees(Double(turn + min(8, max(-8, held.width * 0.12)))))
            .scaleEffect(x: 1+pull*0.08, y: 1-pull*0.05)
            .offset(x: held.width, y: held.height + bob)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                grabbing = true
                func rubber(_ x: CGFloat, soft: CGFloat) -> CGFloat {
                    let n = abs(x)*0.85, sign: CGFloat = x < 0 ? -1 : 1
                    return sign * (n <= soft ? n : soft+(n-soft)*0.22/(1+(n-soft)/85))
                }
                held = CGSize(width: rubber(value.translation.width, soft: 55), height: rubber(value.translation.height, soft: 48))
            }.onEnded { value in
                if hypot(value.translation.width,value.translation.height) < 5 { tapAt = Date() }
                grabbing = false
                withAnimation(reduceMotion ? nil : .interpolatingSpring(stiffness: 140, damping: 17)) { held = .zero }
            })
        }
        .frame(width: 58, height: 58)
        .accessibilityLabel(angel ? "Angel companion" : "Devil companion")
    }
}
private struct MouthCurve: Shape {
    func path(in r: CGRect) -> Path { var p = Path();p.move(to: .zero);p.addCurve(to: CGPoint(x:r.width,y:0),control1:CGPoint(x:r.width*0.15,y:r.height*1.3),control2:CGPoint(x:r.width*0.85,y:r.height*1.3));return p }
}
