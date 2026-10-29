import AppKit
import CoreGraphics
// Original vector artwork rendered at a deterministic 1024 pixels, without alpha.
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let colors = [CGColor(red: 0.03, green: 0.22, blue: 0.32, alpha: 1), CGColor(red: 0.035, green: 0.48, blue: 0.57, alpha: 1)]
let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0,1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 1024,y: 0), end: CGPoint(x: 0,y: 1024), options: [])
context.setStrokeColor(CGColor(gray: 1, alpha: 0.28)); context.setLineWidth(14); context.setLineCap(.round)
context.move(to: CGPoint(x: 175,y: 240)); context.addCurve(to: CGPoint(x: 810,y: 760), control1: CGPoint(x: 190,y: 700), control2: CGPoint(x: 520,y: 850)); context.strokePath()
context.setFillColor(CGColor(gray: 1, alpha: 0.8)); context.fillEllipse(in: CGRect(x: 159,y: 224,width: 32,height: 32))
context.saveGState(); context.translateBy(x: 520,y: 510); context.rotate(by: -.pi/4)
let points: [(Double,Double)] = [(0,330),(30,290),(42,90),(285,-100),(285,-155),(40,-65),(30,-240),(115,-300),(115,-335),(0,-290),(-115,-335),(-115,-300),(-30,-240),(-40,-65),(-285,-155),(-285,-100),(-42,90),(-30,290)]
context.setFillColor(CGColor(gray: 1,alpha: 1)); context.move(to: CGPoint(x: points[0].0,y: points[0].1))
for p in points.dropFirst() { context.addLine(to: CGPoint(x: p.0,y: p.1)) }; context.closePath(); context.fillPath(); context.restoreGState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Flightbook/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
