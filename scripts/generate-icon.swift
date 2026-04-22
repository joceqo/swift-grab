#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outputDir = "icon-variants"

func makeContext() -> CGContext {
    let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func save(_ ctx: CGContext, name: String) {
    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: "\(outputDir)/\(name).png")
    try! data.write(to: url)
    print("Saved: \(url.path)")
}

func drawGradientBg(_ ctx: CGContext, top: CGColor, bottom: CGColor) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [top, bottom] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: size/2, y: 0),
        end: CGPoint(x: size/2, y: size),
        options: []
    )
}

func drawRadialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color, color.copy(alpha: 0)!] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(
        gradient,
        startCenter: center, startRadius: 0,
        endCenter: center, endRadius: radius,
        options: []
    )
}

func drawCrosshair(_ ctx: CGContext, center: CGPoint, radius: CGFloat, strokeWidth: CGFloat, color: CGColor, gapRatio: CGFloat = 0.28) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(strokeWidth)
    ctx.setLineCap(.round)
    let gap = radius * gapRatio
    // Horizontal line (left + right segments)
    ctx.move(to: CGPoint(x: center.x - radius, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x - gap, y: center.y))
    ctx.move(to: CGPoint(x: center.x + gap, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x + radius, y: center.y))
    // Vertical line (top + bottom segments)
    ctx.move(to: CGPoint(x: center.x, y: center.y - radius))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y - gap))
    ctx.move(to: CGPoint(x: center.x, y: center.y + gap))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y + radius))
    ctx.strokePath()
}

func drawRing(_ ctx: CGContext, center: CGPoint, radius: CGFloat, width: CGFloat, color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius*2, height: radius*2))
    ctx.strokePath()
}

func drawDot(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius*2, height: radius*2))
    ctx.fillPath()
}

func drawBrackets(_ ctx: CGContext, rect: CGRect, arm: CGFloat, width: CGFloat, color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let (x, y, w, h) = (rect.minX, rect.minY, rect.width, rect.height)
    // top-left
    ctx.move(to: CGPoint(x: x, y: y + arm)); ctx.addLine(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x + arm, y: y))
    // top-right
    ctx.move(to: CGPoint(x: x + w - arm, y: y)); ctx.addLine(to: CGPoint(x: x + w, y: y)); ctx.addLine(to: CGPoint(x: x + w, y: y + arm))
    // bottom-right
    ctx.move(to: CGPoint(x: x + w, y: y + h - arm)); ctx.addLine(to: CGPoint(x: x + w, y: y + h)); ctx.addLine(to: CGPoint(x: x + w - arm, y: y + h))
    // bottom-left
    ctx.move(to: CGPoint(x: x + arm, y: y + h)); ctx.addLine(to: CGPoint(x: x, y: y + h)); ctx.addLine(to: CGPoint(x: x, y: y + h - arm))
    ctx.strokePath()
}

func drawShine(_ ctx: CGContext) {
    let shineRect = CGRect(x: size * 0.15, y: size * 0.06, width: size * 0.7, height: size * 0.28)
    let shine = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.saveGState()
    let shinePath = CGPath(ellipseIn: shineRect, transform: nil)
    ctx.addPath(shinePath)
    ctx.clip()
    ctx.drawLinearGradient(shine, start: CGPoint(x: size/2, y: shineRect.minY), end: CGPoint(x: size/2, y: shineRect.maxY), options: [])
    ctx.restoreGState()
}

let center = CGPoint(x: size/2, y: size/2)

// Colors
let navyTop    = CGColor(red: 0.06, green: 0.07, blue: 0.18, alpha: 1) // #0f1230
let indigoBot  = CGColor(red: 0.11, green: 0.12, blue: 0.35, alpha: 1) // #1c1e59
let cyanAccent = CGColor(red: 0.0,  green: 0.85, blue: 1.0,  alpha: 1) // #00d9ff
let cyanDim    = CGColor(red: 0.0,  green: 0.85, blue: 1.0,  alpha: 0.18)
let greenAccent = CGColor(red: 0.2,  green: 1.0,  blue: 0.5,  alpha: 1) // #33ff80
let greenDim    = CGColor(red: 0.2,  green: 1.0,  blue: 0.5,  alpha: 0.18)

// ── VARIANT 1: Crosshair + ring, cyan ──
do {
    let ctx = makeContext()
    drawGradientBg(ctx, top: navyTop, bottom: indigoBot)
    drawRadialGlow(ctx, center: center, radius: size * 0.42, color: cyanDim)
    drawRing(ctx, center: center, radius: size * 0.28, width: size * 0.022, color: CGColor(red: 0, green: 0.85, blue: 1.0, alpha: 0.35))
    drawCrosshair(ctx, center: center, radius: size * 0.38, strokeWidth: size * 0.022, color: cyanAccent)
    drawDot(ctx, center: center, radius: size * 0.042, color: cyanAccent)
    drawShine(ctx)
    save(ctx, name: "variant1-crosshair-cyan")
}

// ── VARIANT 2: Crosshair + brackets, green ──
do {
    let ctx = makeContext()
    drawGradientBg(ctx, top: navyTop, bottom: indigoBot)
    drawRadialGlow(ctx, center: center, radius: size * 0.44, color: greenDim)
    let bracketRect = CGRect(x: size*0.22, y: size*0.22, width: size*0.56, height: size*0.56)
    drawBrackets(ctx, rect: bracketRect, arm: size * 0.12, width: size * 0.028, color: CGColor(red: 0.2, green: 1.0, blue: 0.5, alpha: 0.45))
    drawCrosshair(ctx, center: center, radius: size * 0.32, strokeWidth: size * 0.022, color: greenAccent)
    drawDot(ctx, center: center, radius: size * 0.038, color: greenAccent)
    drawShine(ctx)
    save(ctx, name: "variant2-crosshair-green-brackets")
}

// ── VARIANT 3: Abstract — ring + dot + minimal tick marks, cyan ──
do {
    let ctx = makeContext()
    drawGradientBg(ctx, top: navyTop, bottom: indigoBot)
    drawRadialGlow(ctx, center: center, radius: size * 0.40, color: cyanDim)
    // Outer ring
    drawRing(ctx, center: center, radius: size * 0.34, width: size * 0.018, color: CGColor(red: 0, green: 0.85, blue: 1.0, alpha: 0.25))
    // Inner ring
    drawRing(ctx, center: center, radius: size * 0.20, width: size * 0.014, color: CGColor(red: 0, green: 0.85, blue: 1.0, alpha: 0.5))
    // Tick marks at N/E/S/W on outer ring
    ctx.setStrokeColor(cyanAccent)
    ctx.setLineWidth(size * 0.020)
    ctx.setLineCap(.round)
    for angle in [CGFloat.pi/2, 3*CGFloat.pi/2, 0, CGFloat.pi] {
        let innerR = size * 0.34 - size * 0.06
        let outerR = size * 0.34 + size * 0.06
        let startPt = CGPoint(x: center.x + innerR * cos(angle), y: center.y + innerR * sin(angle))
        let endPt   = CGPoint(x: center.x + outerR * cos(angle), y: center.y + outerR * sin(angle))
        ctx.move(to: startPt); ctx.addLine(to: endPt)
    }
    ctx.strokePath()
    // Center dot
    drawDot(ctx, center: center, radius: size * 0.052, color: cyanAccent)
    drawShine(ctx)
    save(ctx, name: "variant3-abstract-rings-cyan")
}

print("\nDone. 3 variants in ./\(outputDir)/")
