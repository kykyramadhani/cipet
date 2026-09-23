import SwiftUI

enum Tut {
    static let cycle: Double = 2.6   // one fill of the steal bar

    // MARK: angkot
    // the group sits centred on the screen. everything below is in the group's own coordinates,
    // and the order they're drawn in matters: wheels, interior, exterior, THEN the people, so
    // the driver ends up in the cab and the passengers in the windows instead of behind a panel.
    static let angkot   = CGRect(x: 217.0035, y: 0, width: 439.313, height: 424)
    static let wheel    = CGRect(x: 0,    y: 3.06, width: 439.313, height: 410.388)
    static let interior = CGRect(x: 7.38, y: 7.38, width: 424.264, height: 396.33)
    static let exterior = CGRect(x: 0,    y: 0,    width: 439.313, height: 410.388)

    static let bocah  = CGRect(x: 230.99, y: 116.21, width: 66.166, height: 84)
    static let kiriA  = CGRect(x: 166.50, y: 110.94, width: 57.497, height: 84)
    static let kiriB  = CGRect(x:  43.65, y: 110.94, width: 57.497, height: 84)
    static let sopir  = CGRect(x: 297.27, y: 114.63, width: 62.222, height: 84)
    static let kanan  = CGRect(x: 105.63, y: 186.88, width: 67.836, height: 84)
    static let seated = CGRect(x: 103.02, y: 109.00, width: 59.615, height: 83.395)

    /// faded copies marking the seats you could take
    static let ghosts = [CGRect(x: 44.985, y: 192, width: 59.659, height: 83.457),
                         CGRect(x: 168.00, y: 192, width: 59.659, height: 83.457)]
    static let ghostFade = 0.4

    // MARK: first scene, thief still out on the pavement
    static let outside    = CGRect(x: 638.02, y: 0, width: 70.969, height: 99.277)
    static let bubble     = CGRect(x: 672.11, y: 96.131, width: 143.354, height: 70.5276)
    static let bubbleText = CGRect(x: 686, y: 123, width: 170, height: 30)
    static let bubbleSize: CGFloat = 24

    // MARK: the bar over three of the heads
    static let aware = [CGRect(x: 232, y: 108, width: 68, height: 20),
                        CGRect(x: 101, y: 192, width: 68, height: 20),
                        CGRect(x: 158, y: 100, width: 68, height: 20)]
    static let awareLevel: [CGFloat] = [34.0 / 50, 45.0 / 50, 16.0 / 50]
    static let awareTrack = CGRect(x: 8,  y: 3, width: 60, height: 14)
    static let awareArt   = CGSize(width: 60.67, height: 15.7919)
    static let awareFill  = CGRect(x: 13, y: 5, width: 50, height: 10)
    static let eye        = CGRect(x: 0,  y: 0, width: 20, height: 20)
    static let eyeArt     = CGSize(width: 15.5139, height: 11.3174)

    // MARK: hud
    static let walletPanel = CGRect(x: 24,  y: 20, width: 140, height: 60)
    static let clockPanel  = CGRect(x: 367, y: 20, width: 140, height: 60)
    static let panelArt    = CGSize(width: 144.947, height: 64.9828)
    static let panelNudge  = CGSize(width: -2.306, height: -1.98)
    static let walletIcon: CGFloat = 48
    static let clockIcon:  CGFloat = 40
    static let hudSize:    CGFloat = 40
    static let hudGap:     CGFloat = 8

    static let label = CGRect(x: 24, y: 0, width: 220, height: 48)   // y comes from the step
    static let labelSize: CGFloat = 40

    // MARK: card
    static let cardX:      CGFloat = 669
    static let cardW:      CGFloat = 183
    static let cardPad:    CGFloat = 14
    static let cardGap:    CGFloat = 16
    static let cardRadius: CGFloat = 10
    static let cardBorder: CGFloat = 6
    static let cardSize:   CGFloat = 20
    static let skipSize:   CGFloat = 18
    static let nextSize:   CGFloat = 16
    static let nextBox   = CGSize(width: 36, height: 17)
    static let nextArt   = CGSize(width: 46.5141, height: 23.8214)
    static let nextNudge = CGSize(width: -10.419, height: -5.278)

    // MARK: bottom bar group, 440x116 sat 20 up from the bottom
    static let bar = CGRect(x: 217, y: 266, width: 440, height: 116)

    static let holdLabel = CGRect(x: 120, y: -1.699, width: 198.9, height: 36.0456)
    static let holdText  = CGRect(x: 153, y: 5.348, width: 150, height: 22)
    static let holdSize:  CGFloat = 15.652

    static let track = CGRect(x: 55.63, y: 25.95, width: 328.749, height: 40.0915)
    static let fill  = CGRect(x: 61, y: 34, width: 318, height: 24)   // width is the progress
    static let coin  = CGRect(x: 324, y: 3.37, width: 60, height: 61.2602)
    static let hand  = CGSize(width: 56.3478, height: 56.3478)
    static let handY: CGFloat = 18.652

    static let suspOutline = CGRect(x: 137.146, y: 73.269, width: 163.866, height: 43.9332)
    static let suspBadge   = CGRect(x: 113.569, y: 72.569, width: 44.432, height: 44.432)
    static let slot   = CGSize(width: 40, height: 23.2)
    static let slotGap:    CGFloat = 3.2
    static let slotX:      CGFloat = 161.6
    static let slotY:      CGFloat = 84.2
    static let slotRadius: CGFloat = 8
    static let slotBorder: CGFloat = 3.2
    static let slots = 3

    static func inAngkot(_ r: CGRect) -> CGRect { r.offsetBy(dx: angkot.minX, dy: angkot.minY) }
    static func inBar(_ r: CGRect) -> CGRect { r.offsetBy(dx: bar.minX, dy: bar.minY) }

    /// the svg exports bleed past their box by the stroke width, and `place` centres whatever
    /// it's given, so this is how far the art's centre ends up from the box's.
    static func bleed(_ box: CGSize, _ art: CGSize, _ nudge: CGSize) -> CGSize {
        CGSize(width: nudge.width + (art.width - box.width) / 2,
               height: nudge.height + (art.height - box.height) / 2)
    }

    static func centred(_ box: CGRect, on art: CGSize) -> CGRect {
        CGRect(x: box.midX - art.width / 2, y: box.midY - art.height / 2,
               width: art.width, height: art.height)
    }
}
