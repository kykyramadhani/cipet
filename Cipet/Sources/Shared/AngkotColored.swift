import SwiftUI

// the yellow angkot, three layers stacked: wheels, body, then the roof panel over the window.
// loading screen and menu draw the same thing at wildly different sizes, so the layers keep
// their places inside the group's own box and everything scales from there.
struct AngkotColored: View {
    let group: CGRect
    let space: DesignSpace

    private static let box  = CGSize(width: 317, height: 301.03949)
    private static let body = CGRect(x: 0, y: 0,       width: 316.75443, height: 296.12857)
    private static let tyre = CGRect(x: 0, y: 4.91093, width: 316.99997, height: 296.12857)

    var body: some View {
        let k = group.width / Self.box.width * space.scale
        ZStack(alignment: .topLeading) {
            layer("loading_angkot_wheel",    Self.tyre, k)
            layer("angkot_exterior_colored", Self.body, k)
            layer("angkot_roof_colored",     Self.body, k)
        }
        .frame(width: space.px(group.width), height: space.px(group.height), alignment: .topLeading)
    }

    private func layer(_ name: String, _ r: CGRect, _ k: CGFloat) -> some View {
        Image(name).resizable()
            .frame(width: r.width * k, height: r.height * k)
            .offset(x: r.minX * k, y: r.minY * k)
    }
}
