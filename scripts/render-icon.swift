// Renders the app icon (the milestones thread, design 2a) as 1024 × 1024 PNGs into the asset catalog:
// light, dark and tinted. Run from the repo root after changing the design:
//   swift scripts/render-icon.swift
import AppKit

struct Look {
    let file: String
    let background: CGColor
    let thread: CGColor
    let pin: CGColor
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let looks = [
    // The thread between the pins in the darkroom accent, the pins in milestone marigold.
    Look(file: "AppIcon.png", background: rgb(0xF3ECDF), thread: rgb(0xC2412D), pin: rgb(0xE0A526)),
    Look(file: "AppIcon-Dark.png", background: rgb(0x1B1714), thread: rgb(0xE8664F), pin: rgb(0xE8B23C)),
    // Tinted: iOS takes the luminance of a grayscale image on black and applies the user's tint,
    // so the thread is a dimmer grey than the pins.
    Look(file: "AppIcon-Tinted.png", background: rgb(0x000000), thread: rgb(0x8C8C8C), pin: rgb(0xFFFFFF)),
]

let size = 1024
let scale = CGFloat(size) / 100   // the design is drawn on a 100-unit grid, as on the canvas
let folder = "Moments/Assets.xcassets/AppIcon.appiconset"

for look in looks {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Flip to the canvas's top-left origin.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)

    ctx.setFillColor(look.background)
    ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

    let thread = CGMutablePath()
    thread.move(to: CGPoint(x: 50, y: 20))
    thread.addCurve(to: CGPoint(x: 50, y: 52), control1: CGPoint(x: 29, y: 31), control2: CGPoint(x: 71, y: 41))
    thread.addCurve(to: CGPoint(x: 50, y: 84), control1: CGPoint(x: 29, y: 63), control2: CGPoint(x: 71, y: 73))
    ctx.addPath(thread)
    ctx.setStrokeColor(look.thread)
    ctx.setLineWidth(3.5)
    ctx.setLineCap(.round)
    ctx.strokePath()

    // Pins: r 8 with a 3.5-unit ring of background, so the thread appears to pass behind them.
    for y in [20.0, 52.0, 84.0] {
        let ring = CGRect(x: 50 - 9.75, y: y - 9.75, width: 19.5, height: 19.5)
        ctx.setFillColor(look.background)
        ctx.fillEllipse(in: ring)
        ctx.setFillColor(look.pin)
        ctx.fillEllipse(in: CGRect(x: 50 - 8, y: y - 8, width: 16, height: 16))
    }

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(folder)/\(look.file)"))
    print("wrote \(folder)/\(look.file)")
}
