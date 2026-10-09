// Renders the app icon: swift scripts/make-icon.swift <output.png>
import AppKit
import CoreImage

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func layer(_ draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(context)
    return context.makeImage()!
}

func blurred(_ image: CGImage, radius: Double) -> CGImage {
    let input = CIImage(cgImage: image)
    let output = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
    return CIContext().createCGImage(output, from: input.extent)!
}

func linear(_ context: CGContext, _ colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

// macOS icon grid: 824 pt body centered in 1024.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
let bar = CGRect(x: 452, y: 300, width: 120, height: 520)
let barPath = CGPath(roundedRect: bar, cornerWidth: 60, cornerHeight: 60, transform: nil)

// RGB backlight glow behind the bar.
let rgbGlow = blurred(layer { context in
    context.addPath(CGPath(roundedRect: bar.insetBy(dx: -120, dy: -20), cornerWidth: 160, cornerHeight: 160, transform: nil))
    context.clip()
    linear(context, [color(0xFF2D95), color(0xFF9F0A), color(0x30D158), color(0x0A84FF), color(0xBF5AF2)],
           from: CGPoint(x: 0, y: bar.maxY + 30), to: CGPoint(x: 0, y: bar.minY - 30))
}, radius: 55)

// Warm front light falling forward.
let warmGlow = blurred(layer { context in
    context.addEllipse(in: CGRect(x: 330, y: 230, width: 364, height: 640))
    context.clip()
    linear(context, [color(0xFFD9A0, 0.28), color(0xFFD9A0, 0)], from: CGPoint(x: 512, y: 700), to: CGPoint(x: 512, y: 150))
}, radius: 60)

let icon = layer { context in
    context.addPath(bodyPath)
    context.clip()

    // Background
    linear(context, [color(0x23263A), color(0x0B0C15)], from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: body.minY))
    context.draw(rgbGlow, in: CGRect(x: 0, y: 0, width: size, height: size))
    context.draw(rgbGlow, in: CGRect(x: 0, y: 0, width: size, height: size))
    context.draw(warmGlow, in: CGRect(x: 0, y: 0, width: size, height: size))

    // Stand
    context.setFillColor(color(0x3A3D4C))
    context.fill(CGRect(x: 497, y: 220, width: 30, height: 90))
    context.addPath(CGPath(roundedRect: CGRect(x: 392, y: 196, width: 240, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil))
    context.fillPath()

    // Light bar with a glowing warm face
    context.saveGState()
    context.setShadow(offset: .zero, blur: 60, color: color(0xFFF1DC, 0.9))
    context.addPath(barPath)
    context.setFillColor(color(0xFFF3DF))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(barPath)
    context.clip()
    linear(context, [color(0xFFFFFF), color(0xFFE9C7)], from: CGPoint(x: bar.minX, y: 0), to: CGPoint(x: bar.maxX, y: 0))
    context.restoreGState()

    // Glass highlight on the upper half
    linear(context, [color(0xFFFFFF, 0.16), color(0xFFFFFF, 0)], from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: body.midY))
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, icon, nil)
CGImageDestinationFinalize(destination)
