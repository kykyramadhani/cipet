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

// every button in the game uses this, so the click sound only needs wiring up once. it fires
// on the press going down, not in the body, so a redraw cant retrigger it.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, down in
                if down { Audio.shared.play(.click) }
            }
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

// the design's text outlines are real strokes on the outside of each letter with mitred
// corners, which is where skranji's little spikes come from. OutlinedText's offset copies
// round those off, so this strokes the actual glyph outlines instead.
struct StrokedText: View {
    let string: String
    let size: CGFloat        // design points
    let fill: Color
    let rim: Color
    let width: CGFloat       // design points, all of it outside the letter
    let scale: CGFloat
    var bold = false

    var body: some View {
        let line = GlyphLine(string, size: size, bold: bold)
        let path = line.path.applying(CGAffineTransform(scaleX: scale, y: scale))
        ZStack(alignment: .topLeading) {
            // a stroke is centred on the outline, so twice the width and the fill on top
            // leaves exactly `width` showing outside
            path.stroke(rim, style: StrokeStyle(lineWidth: width * 2 * scale,
                                                lineJoin: .miter, miterLimit: 4))
            path.fill(fill)
        }
        .frame(width: line.box.width * scale, height: line.box.height * scale,
               alignment: .topLeading)
    }
}

/// one line of skranji as a path, laid out in the same box the design uses: its advance
/// wide, ascent + descent tall, baseline at the ascent
struct GlyphLine {
    let path: Path
    let box: CGSize

    init(_ string: String, size: CGFloat, bold: Bool = false) {
        let font = (UIFont(name: bold ? "Skranji-Bold" : "Skranji", size: size)
                    ?? .systemFont(ofSize: size)) as CTFont
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: string, attributes: [.font: font]))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        let out = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let n = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: n)
            var at = [CGPoint](repeating: .zero, count: n)
            CTRunGetGlyphs(run, CFRange(), &glyphs)
            CTRunGetPositions(run, CFRange(), &at)
            for i in 0..<n {
                guard let g = CTFontCreatePathForGlyph(font, glyphs[i], nil) else { continue }
                // coretext is y-up from the baseline, flip it into a top-down box
                out.addPath(g, transform: CGAffineTransform(translationX: at[i].x, y: ascent)
                    .scaledBy(x: 1, y: -1))
            }
        }
        path = Path(out)
        box = CGSize(width: width, height: ascent + descent)
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
