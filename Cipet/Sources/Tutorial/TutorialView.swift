import SwiftUI

// the onboarding, straight after Play and before round 1. every page is its frame from the
// design exported whole, so it matches exactly, with real buttons laid over the "skip" and
// the arrow drawn on it. the rects are those words' own bounds in the frame.
enum Tutorial {
    struct Page {
        let art: String
        let skip: CGRect?
        let next: CGRect   // the arrow, or "Play now" on the last page
    }

    static let pages: [Page] = [
        Page(art: "tutorial_259_201",  skip: CGRect(x: 683, y: 307, width: 30, height: 18),
             next: CGRect(x: 814, y: 304, width: 24, height: 24)),
        Page(art: "tutorial_278_1161", skip: CGRect(x: 683, y: 283, width: 31, height: 18),
             next: CGRect(x: 814, y: 283, width: 24, height: 24)),
        Page(art: "tutorial_278_2688", skip: CGRect(x: 663, y: 258, width: 30, height: 18),
             next: CGRect(x: 794, y: 255, width: 24, height: 24)),
        Page(art: "tutorial_278_1745", skip: CGRect(x: 685, y: 257, width: 30, height: 18),
             next: CGRect(x: 816, y: 254, width: 24, height: 24)),
        Page(art: "tutorial_288_194",  skip: CGRect(x: 141, y: 351, width: 30, height: 18),
             next: CGRect(x: 272, y: 348, width: 24, height: 24)),
        Page(art: "tutorial_278_3324", skip: CGRect(x: 135, y: 348, width: 30, height: 18),
             next: CGRect(x: 266, y: 345, width: 24, height: 24)),
        Page(art: "tutorial_278_3061", skip: CGRect(x: 685, y: 338, width: 30, height: 18),
             next: CGRect(x: 816, y: 335, width: 24, height: 24)),
        Page(art: "tutorial_278_3241", skip: nil,
             next: CGRect(x: 151, y: 298, width: 76, height: 18)),
    ]

    /// the drawn words are smaller than a finger, so every button reaches at least this far
    static let minTap: CGFloat = 44

    static func tap(_ r: CGRect) -> CGRect {
        r.insetBy(dx: min(0, (r.width - minTap) / 2), dy: min(0, (r.height - minTap) / 2))
    }
}

struct TutorialView: View {
    let onFinish: () -> Void

    @State private var index = 0

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)
            let page = Tutorial.pages[index]

            ZStack(alignment: .topLeading) {
                place(CGRect(origin: .zero, size: DesignSpace.screen), space) {
                    Image(page.art).resizable()
                }
                if let skip = page.skip { button(skip, space, onFinish) }
                button(page.next, space, next)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .task { runTutorialChecks() }
    }

    private func next() {
        if index + 1 < Tutorial.pages.count { index += 1 } else { onFinish() }
    }

    private func button(_ r: CGRect, _ space: DesignSpace,
                        _ action: @escaping () -> Void) -> some View {
        place(Tutorial.tap(r), space) {
            Button(action: action) { Color.clear.contentShape(Rectangle()) }
                .buttonStyle(PressStyle())
        }
    }
}

private func runTutorialChecks() {
    #if DEBUG
    assert(Tutorial.pages.count == 8, "eight screens in the design's tutorial row")
    let screen = CGRect(origin: .zero, size: DesignSpace.screen)
    for (i, p) in Tutorial.pages.enumerated() {
        assert(UIImage(named: p.art) != nil, "page \(i + 1)'s art is missing")
        assert(screen.contains(Tutorial.tap(p.next)), "page \(i + 1)'s next button is off screen")
        if let skip = p.skip {
            assert(!Tutorial.tap(skip).intersects(Tutorial.tap(p.next)),
                   "page \(i + 1): skip and next would steal each other's taps")
        }
    }
    assert(Tutorial.pages.last!.skip == nil, "the last page only has Play now")
    assert(Tutorial.tap(CGRect(x: 0, y: 0, width: 24, height: 24)).width == Tutorial.minTap)
    #endif
}

#Preview(traits: .landscapeLeft) { TutorialView {} }
