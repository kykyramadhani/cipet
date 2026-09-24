import SwiftUI

extension Font {
    /// skranji is in Resources/Fonts and registered in Cipet-Info.plist. the postscript name for
    /// the regular weight is just "Skranji", not "Skranji-Regular" — get it wrong and it silently
    /// falls back to the system font.
    static func skranji(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "Skranji-Bold" : "Skranji", size: size)
    }
}

enum Ink {
    static let black   = Color(red:  23 / 255, green:  23 / 255, blue:  23 / 255)
    static let soft    = Color(red:  10 / 255, green:  10 / 255, blue:  10 / 255)
    static let paper   = Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255)
    static let pale    = Color(red: 229 / 255, green: 229 / 255, blue: 229 / 255)
    static let yellow  = Color(red: 250 / 255, green: 206 / 255, blue:  91 / 255)
    static let glow    = Color(red: 255 / 255, green: 228 / 255, blue: 158 / 255)
    static let red     = Color(red: 211 / 255, green:  68 / 255, blue:  53 / 255)
    static let redGlow = Color(red: 232 / 255, green: 112 / 255, blue: 100 / 255)
    static let snow    = Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    static let grey    = Color(red: 161 / 255, green: 161 / 255, blue: 161 / 255)
}

/// m:ss, for the clock and the end screen
func mmss(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", s / 60, s % 60)
}

// a sprite with an optional thin ring round its silhouette. thats how the picked passenger
// is marked when theres no yellow version of their artwork to swap in — they keep their own
// drawing and just get outlined.
struct Sprite: View {
    let name: String
    var ring: Color? = nil
    var ringWidth: CGFloat = 0

    var body: some View {
        ZStack {
            if let ring, ringWidth > 0 {
                ForEach(0..<12, id: \.self) { i in
                    let a = Double(i) / 12 * 2 * .pi
                    Image(name).resizable().renderingMode(.template)
                        .foregroundStyle(ring)
                        .offset(x: ringWidth * CGFloat(cos(a)), y: ringWidth * CGFloat(sin(a)))
                }
            }
            Image(name).resizable()
        }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// swiftui Text cant do a stroke, so the outline is copies of the word nudged around a circle
// with the real one on top. drawingGroup flattens it all into one layer.
struct OutlinedText: View {
    let string: String
    let font: Font
    let fill: Color
    let thickness: CGFloat
    var tracking: CGFloat = 0
    var outline: Color = Ink.black
    /// a second tighter ring. only the big CIPET title needs it, smaller text closes up fine.
    var twoRings = false

    var body: some View {
        let word = Text(string).font(font).tracking(tracking)
        ZStack {
            ForEach(0..<(twoRings ? 36 : 24), id: \.self) { i in
                let outer = i < 24
                let n = outer ? 24 : 12
                let a = Double(outer ? i : i - 24) / Double(n) * 2 * .pi
                let d = thickness * (outer ? 1 : 0.55)
                word.foregroundStyle(outline)
                    .offset(x: d * CGFloat(cos(a)), y: d * CGFloat(sin(a)))
            }
            word.foregroundStyle(fill)
        }
        .fixedSize()
        .padding(thickness * 1.6)   // drawingGroup clips to the bounds, leave room for the ring
        .drawingGroup()
    }
}

// a filled bar with a lighter rim, used for the steal bar and the suspicion bars
struct TwoToneBar: View {
    let core: Color
    let rim: Color
    let radius: CGFloat
    let edge: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius).fill(core)
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(rim, lineWidth: edge))
    }
}
