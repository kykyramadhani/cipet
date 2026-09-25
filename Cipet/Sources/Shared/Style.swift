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
    static let stone   = Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255)
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
    var tracking: CGFloat = 0

    var body: some View {
        let line = GlyphLine(string, size: size, bold: bold, tracking: tracking)
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

    /// `tracking` is the design's letter spacing, in the same points as `size`. coretext
    /// puts it after every character, the last one included, which is what figma measures a
    /// tracked line as too.
    init(_ string: String, size: CGFloat, bold: Bool = false, tracking: CGFloat = 0) {
        let font = (UIFont(name: bold ? "Skranji-Bold" : "Skranji", size: size)
                    ?? .systemFont(ofSize: size)) as CTFont
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if tracking != 0 { attributes[.kern] = tracking }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: string, attributes: attributes))
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

// every overlay card is headed the same way, off 125:1508: skranji bold at fifty in the
// near-black the design calls Neutral/950. settings used to be a forty point sticker with a
// pale fill and an outline, and the instructions a twenty-four point regular, so the four
// cards you can open from the menu read as four different screens.
//
// the design's line box is 51.704, which is tighter than skranji's own line — laying the
// word out in a box that short quietly shrinks it to fit, which is what happened to Paused.
// so the box here is the font's line height, centred on the spot the card puts the heading,
// and the design's narrower box is only what the card's own layout reserves for it.
struct CardTitle: View {
    let text: String
    /// where the card centres its heading
    let centre: CGPoint
    let space: DesignSpace
    /// wide enough that a longer word in another language has room before it has to shrink
    var width: CGFloat = 320

    static let size: CGFloat = 50
    /// what the design reserves for the line, which is not the same as what it draws in
    static let lineBox: CGFloat = 51.704
    /// skranji's own line at this size — its "normal" is 54.336 at 40
    static let line: CGFloat = 54.336 * size / 40

    static func box(_ centre: CGPoint, width: CGFloat = 320) -> CGRect {
        CGRect(x: centre.x - width / 2, y: centre.y - line / 2, width: width, height: line)
    }

    var body: some View {
        place(Self.box(centre, width: width), space) {
            Text(text)
                .font(.skranji(space.px(Self.size)))
                .foregroundStyle(Ink.black)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

func runGlyphChecks() {
    #if DEBUG
    // tracking has to reach the laid out line, not just the api. the menu's tagline is set
    // tighter than the font draws it and used to come out a tenth wider than the design,
    // because the only outline renderer that took a tracking value was the rounded one.
    let plain = GlyphLine("Ready to Steal?", size: 40)
    let tight = GlyphLine("Ready to Steal?", size: 40, tracking: -1.8467)
    assert(tight.box.width < plain.box.width, "tracking has to narrow the line")
    assert(abs((plain.box.width - tight.box.width) - 1.8467 * 15) < 0.5,
           "and by the spacing times the characters")
    assert(tight.box.height == plain.box.height, "without touching the line's height")

    // the two weights are both really loaded, or everything silently falls back to the
    // system font and every box measured off the design is wrong
    assert(UIFont(name: "Skranji", size: 40) != nil && UIFont(name: "Skranji-Bold", size: 40) != nil)
    assert(GlyphLine("CIPET", size: 40, bold: true).box.width
           > GlyphLine("CIPET", size: 40).box.width, "bold is the wider of the two")
    #endif
}

func runCardTitleChecks() {
    #if DEBUG
    // the heading is drawn in a taller box than the layout reserves, so the glyphs are never
    // squeezed — the whole reason Paused came out small
    assert(CardTitle.line > CardTitle.lineBox)
    assert(abs(GlyphLine("Paused", size: CardTitle.size, bold: true).box.height
               - CardTitle.line) < 0.01, "the box is skranji's own line at this size")

    // and the box is centred on the point it is given, so a card only has to say where
    let box = CardTitle.box(CGPoint(x: 100, y: 50))
    assert(abs(box.midX - 100) < 0.001 && abs(box.midY - 50) < 0.001)

    // every heading the game shows fits at full size, in both languages, so none of them is
    // silently riding minimumScaleFactor the way the old Paused box was
    for word in ["Settings", "Record", "Paused", "Instruction"] {
        for copy in [word, Indonesian.table[word] ?? word] {
            let w = GlyphLine(copy, size: CardTitle.size, bold: true).box.width
            assert(w <= 320, "\(copy) is \(Int(w)) wide and would be shrunk to fit")
        }
    }
    #endif
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
