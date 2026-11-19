#!/usr/bin/env swift
// 生成 AppIcon.iconset（由 build.sh 再转成 .icns）
// 用法: swift Build/make-icon.swift <输出 iconset 目录>

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <iconset-dir>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// 绘制 1024×1024 的主图：深蓝圆角底 + 白色控制滑块符号。
func renderMaster(size: CGFloat = 1024) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    ctx.setShouldAntialias(true)

    // 圆角矩形背景（macOS 图标留边）
    let inset = size * 0.09
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.30, blue: 0.78, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.52, blue: 0.95, alpha: 1),
    ])
    gradient?.draw(in: path, angle: -90)

    // 顶部高光
    NSColor.white.withAlphaComponent(0.08).setFill()
    let highlight = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2),
                                 xRadius: size * 0.225, yRadius: size * 0.225)
    highlight.fill()

    // 三条滑动条 + 滑块，呼应 MenuBarExtra 的 slider 图标
    NSColor.white.setFill()
    let barWidth = size * 0.42
    let barHeight = size * 0.052
    let centerX = size / 2
    let knobSize = size * 0.135
    let ys: [CGFloat] = [size * 0.66, size * 0.5, size * 0.34]
    let knobX: [CGFloat] = [centerX + barWidth * 0.28, centerX - barWidth * 0.26, centerX + barWidth * 0.06]

    for (i, y) in ys.enumerated() {
        let barRect = NSRect(x: centerX - barWidth / 2, y: y - barHeight / 2, width: barWidth, height: barHeight)
        NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
        let knobRect = NSRect(x: knobX[i] - knobSize / 2, y: y - knobSize / 2, width: knobSize, height: knobSize)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knobRect).fill()
        NSColor(calibratedRed: 0.16, green: 0.35, blue: 0.82, alpha: 1).setFill()
        NSBezierPath(ovalIn: knobRect.insetBy(dx: knobSize * 0.26, dy: knobSize * 0.26)).fill()
    }

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage, side: Int) -> Data? {
    let target = NSImage(size: NSSize(width: side, height: side))
    target.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy, fraction: 1)
    target.unlockFocus()
    guard let tiff = target.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return nil }
    return png
}

let master = renderMaster()
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, side) in variants {
    guard let data = pngData(from: master, side: side) else {
        FileHandle.standardError.write(Data("无法生成 \(name)\n".utf8))
        exit(3)
    }
    try data.write(to: output.appendingPathComponent(name))
}
print("已生成 iconset: \(output.path)")
