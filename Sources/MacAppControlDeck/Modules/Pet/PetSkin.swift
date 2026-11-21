import CoreGraphics
import Foundation

enum PetBodyKind: String, Equatable {
    case cat
    case dog
}

enum PetPattern: String, Equatable {
    case solid
    case tabby
    case calico
}

enum PetHitShape: String, Equatable {
    case ellipse
    case roundedRect
}

struct PetHitRegion: Equatable {
    var rect: CGRect
    var shape: PetHitShape = .ellipse
}

struct PetAnchors: Equatable {
    var head: PetPoint
    var body: PetPoint
    var leftPaw: PetPoint
    var rightPaw: PetPoint
    var leftEye: PetPoint
    var rightEye: PetPoint
    var tail: PetPoint
    var leftEar: PetPoint
    var rightEar: PetPoint
    var keyboard: PetPoint
}

struct PetPalette: Equatable {
    var body: PetColor
    var outline: PetColor
    var innerEar: PetColor
    var pawPad: PetColor
    var pawMitt: PetColor
    var eye: PetColor
    var muzzle: PetColor
    var patchA: PetColor
    var patchB: PetColor
    var stripe: PetColor
    var accent: PetColor
}

struct PetSkin: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let bodyKind: PetBodyKind
    let pattern: PetPattern
    let palette: PetPalette
    let hitRegions: [PetHitRegion]
    let anchors: PetAnchors
    let defaultKeyboardTheme: PetKeyboardTheme
    let license: String
}

enum PetSkinCatalog {
    static let defaultID = "classic-white"

    static let all: [PetSkin] = [
        classicWhite,
        midnightBlack,
        orangeTabby,
        calico,
        creamDog
    ]

    static var defaultSkin: PetSkin { classicWhite }

    static func skin(id: String) -> PetSkin? {
        all.first { $0.id == id }
    }

    static let sharedAnchors = PetAnchors(
        head: PetPoint(0.50, 0.24),
        body: PetPoint(0.50, 0.57),
        leftPaw: PetPoint(0.13, 0.90),
        rightPaw: PetPoint(0.68, 0.90),
        leftEye: PetPoint(0.43, 0.25),
        rightEye: PetPoint(0.57, 0.25),
        tail: PetPoint(0.87, 0.68),
        leftEar: PetPoint(0.37, 0.13),
        rightEar: PetPoint(0.63, 0.13),
        keyboard: PetPoint(0.54, 0.90)
    )

    private static let sharedHitRegions: [PetHitRegion] = [
        PetHitRegion(rect: CGRect(x: 0.20, y: 0.46, width: 0.56, height: 0.26), shape: .ellipse),
        PetHitRegion(rect: CGRect(x: 0.22, y: 0.21, width: 0.48, height: 0.30), shape: .ellipse),
        PetHitRegion(rect: CGRect(x: 0.24, y: 0.63, width: 0.50, height: 0.12), shape: .ellipse),
        PetHitRegion(rect: CGRect(x: 0.72, y: 0.72, width: 0.16, height: 0.10), shape: .roundedRect),
        PetHitRegion(rect: CGRect(x: 0.08, y: 0.66, width: 0.64, height: 0.14), shape: .roundedRect),
        PetHitRegion(rect: CGRect(x: 0.70, y: 0.50, width: 0.28, height: 0.24), shape: .ellipse)
    ]

    static let classicWhite = PetSkin(
        id: defaultID,
        name: "经典白猫",
        subtitle: "完整蹲坐骨架",
        bodyKind: .cat,
        pattern: .solid,
        palette: PetPalette(
            body: PetColor(hex: "F6F1E6"),
            outline: PetColor(hex: "2B2622"),
            innerEar: PetColor(hex: "F3B7B7"),
            pawPad: PetColor(hex: "F3A9A9"),
            pawMitt: PetColor(hex: "FFFDF7"),
            eye: PetColor(hex: "29351E"),
            muzzle: PetColor(hex: "FFFDF7"),
            patchA: PetColor(hex: "F6F1E6"),
            patchB: PetColor(hex: "F6F1E6"),
            stripe: PetColor(hex: "E9DFCC"),
            accent: PetColor(hex: "F3B7B7")
        ),
        hitRegions: sharedHitRegions,
        anchors: sharedAnchors,
        defaultKeyboardTheme: .cream,
        license: "原创矢量"
    )

    static let midnightBlack = PetSkin(
        id: "midnight-black",
        name: "午夜黑猫",
        subtitle: "参考视频同款，大绿竖瞳",
        bodyKind: .cat,
        pattern: .solid,
        palette: PetPalette(
            body: PetColor(hex: "141414"),
            outline: PetColor(hex: "595959"),
            innerEar: PetColor(hex: "141414"),
            pawPad: PetColor(hex: "D9B7A5"),
            pawMitt: PetColor(hex: "F2E7D5"),
            eye: PetColor(hex: "D8FF4A"),
            muzzle: PetColor(hex: "141414"),
            patchA: PetColor(hex: "141414"),
            patchB: PetColor(hex: "141414"),
            stripe: PetColor(hex: "060606"),
            accent: PetColor(hex: "8CCF72")
        ),
        hitRegions: sharedHitRegions,
        anchors: sharedAnchors,
        defaultKeyboardTheme: .cream,
        license: "原创矢量"
    )

    static let orangeTabby = PetSkin(
        id: "orange-tabby",
        name: "橘子虎斑",
        subtitle: "暖色条纹，完整蹲坐",
        bodyKind: .cat,
        pattern: .tabby,
        palette: PetPalette(
            body: PetColor(hex: "E79A4C"),
            outline: PetColor(hex: "3A2A22"),
            innerEar: PetColor(hex: "F2B6A0"),
            pawPad: PetColor(hex: "F2A0A0"),
            pawMitt: PetColor(hex: "FFF2D9"),
            eye: PetColor(hex: "B7E04A"),
            muzzle: PetColor(hex: "FFF2D9"),
            patchA: PetColor(hex: "E79A4C"),
            patchB: PetColor(hex: "FFF2D9"),
            stripe: PetColor(hex: "B9652D"),
            accent: PetColor(hex: "F2B6A0")
        ),
        hitRegions: sharedHitRegions,
        anchors: sharedAnchors,
        defaultKeyboardTheme: .cream,
        license: "原创矢量"
    )

    static let calico = PetSkin(
        id: "calico",
        name: "三花猫",
        subtitle: "黑橘白斑块，完整蹲坐",
        bodyKind: .cat,
        pattern: .calico,
        palette: PetPalette(
            body: PetColor(hex: "FFF9EE"),
            outline: PetColor(hex: "2B2622"),
            innerEar: PetColor(hex: "F2B6C0"),
            pawPad: PetColor(hex: "F2B6C0"),
            pawMitt: PetColor(hex: "FFFFFF"),
            eye: PetColor(hex: "C8E84A"),
            muzzle: PetColor(hex: "FFFFFF"),
            patchA: PetColor(hex: "2B2622"),
            patchB: PetColor(hex: "E79A4C"),
            stripe: PetColor(hex: "2B2622"),
            accent: PetColor(hex: "F2B6C0")
        ),
        hitRegions: sharedHitRegions,
        anchors: sharedAnchors,
        defaultKeyboardTheme: .cream,
        license: "原创矢量"
    )

    static let creamDog = PetSkin(
        id: "cream-dog",
        name: "奶油小狗",
        subtitle: "垂耳吐舌，同一套完整骨架",
        bodyKind: .dog,
        pattern: .solid,
        palette: PetPalette(
            body: PetColor(hex: "F0D6A2"),
            outline: PetColor(hex: "4A3528"),
            innerEar: PetColor(hex: "D6B47A"),
            pawPad: PetColor(hex: "F3C4C4"),
            pawMitt: PetColor(hex: "FFF1D8"),
            eye: PetColor(hex: "3A2A22"),
            muzzle: PetColor(hex: "FFF4DC"),
            patchA: PetColor(hex: "F0D6A2"),
            patchB: PetColor(hex: "D6B47A"),
            stripe: PetColor(hex: "F0D6A2"),
            accent: PetColor(hex: "EF8C8C")
        ),
        hitRegions: sharedHitRegions,
        anchors: sharedAnchors,
        defaultKeyboardTheme: .cream,
        license: "原创矢量"
    )
}
