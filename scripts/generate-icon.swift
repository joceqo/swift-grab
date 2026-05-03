#!/usr/bin/env swift
import AppKit

let sourceURL = URL(fileURLWithPath: "scripts/assets/swiftgrab-icon-source.png")
let appIconDir = URL(fileURLWithPath: "Sources/SwiftGrabApp/Assets.xcassets/AppIcon.appiconset")

struct IconOutput {
    let filename: String
    let pixelSize: Int
}

let outputs = [
    IconOutput(filename: "icon_16x16.png", pixelSize: 16),
    IconOutput(filename: "icon_16x16@2x.png", pixelSize: 32),
    IconOutput(filename: "icon_32x32.png", pixelSize: 32),
    IconOutput(filename: "icon_32x32@2x.png", pixelSize: 64),
    IconOutput(filename: "icon_128x128.png", pixelSize: 128),
    IconOutput(filename: "icon_128x128@2x.png", pixelSize: 256),
    IconOutput(filename: "icon_256x256.png", pixelSize: 256),
    IconOutput(filename: "icon_256x256@2x.png", pixelSize: 512),
    IconOutput(filename: "icon_512x512.png", pixelSize: 512),
    IconOutput(filename: "icon_512x512@2x.png", pixelSize: 1024)
]

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Missing icon source at \(sourceURL.path)")
}

func resizedPNG(from image: NSImage, pixelSize: Int) throws -> Data {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let resized = NSImage(size: size)

    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(origin: .zero, size: size),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1
    )
    resized.unlockFocus()

    guard
        let tiff = resized.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "SwiftGrabIcon", code: 1)
    }

    return png
}

try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)

for output in outputs {
    let png = try resizedPNG(from: sourceImage, pixelSize: output.pixelSize)
    let url = appIconDir.appendingPathComponent(output.filename)
    try png.write(to: url)
    print("Saved \(url.path)")
}
