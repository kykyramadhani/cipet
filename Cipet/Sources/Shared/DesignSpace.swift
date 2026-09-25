import SwiftUI

// every screen is drawn on one fixed canvas and then scaled up to whatever device we're on,
// so all the numbers in the layout files stay in a single coordinate system.
struct DesignSpace {
    static let screen = CGSize(width: 874, height: 402)

    let scale: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    init(_ size: CGSize, canvas: CGSize = DesignSpace.screen) {
        scale = max(size.width / canvas.width, size.height / canvas.height)
        ox = (size.width  - canvas.width  * scale) / 2
        oy = (size.height - canvas.height * scale) / 2
    }

    func x(_ v: CGFloat) -> CGFloat { ox + v * scale }
    func y(_ v: CGFloat) -> CGFloat { oy + v * scale }

    /// a length in canvas units, in screen points
    func px(_ v: CGFloat) -> CGFloat { v * scale }
}

func place<V: View>(_ r: CGRect, _ space: DesignSpace,
                    @ViewBuilder _ content: () -> V) -> some View {
    content()
        .frame(width: space.px(r.width), height: space.px(r.height))
        .position(x: space.x(r.midX), y: space.y(r.midY))
}

extension View {
    /// every screen wants the same thing: full bleed, no status bar, no home indicator
    func fullBleed() -> some View {
        ignoresSafeArea()
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
    }
}
