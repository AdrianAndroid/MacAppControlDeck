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
        head: PetPoint(0.50, 0.36),
        body: PetPoint(0.50, 0.64),
        leftPaw: PetPoint(0.20, 0.78),
        rightPaw: PetPoint(0.82, 0.80),
        leftEye: PetPoint(0.44, 0.33),
        rightEye: PetPoint(0.56, 0.33),
        tail: PetPoint(0.78, 0.74),
        leftEar: PetPoint(0.37, 0.18),
        rightEar: PetPoint(0.63, 0.18),
        keyboard: PetPoint(0.58, 0.87)
    )

    private static let sharedHitRegions: [PetHitRegion] = [
        PetHitRegion(rect: CGRect(x: 0.22, y: 0.24, width: 0.58, height: 0.56), shape: .ellipse),
        PetHitRegion(rect: CGRect(x: 0.29, y: 0.08, width: 0.42, height: 0.42), shape: .ellipse),
        PetHitRegion(rect: CGRect(x: 0.05, y: 0.76, width: 0.17, height: 0.18), shape: .roundedRect),
        PetHitRegion(rect: CGRect(x: 0.23, y: 0.75, width: 0.66, height: 0.23), shape: .roundedRect),
        PetHitRegion(rect: CGRect(x: 0.70, y: 0.58, width: 0.22, height: 0.24), shape: .ellipse)
    ]

    static let classicWhite = PetSkin(
        id: defaultID,
        name: "经典白猫",
        subtitle: "原味 Bongo，最耐看",
        bodyKind: .cat,
        pattern: .solid,
        palette: PetPalette(
            body: PetColor(hex: "F6F1E6"),
            outline: PetColor(hex: "2B2622"),
            innerEar: PetColor(hex: "F3B7B7"),
            pawPad: PetColor(hex: "F3A9A9"),
            eye: PetColor(hex: "2B2622"),
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
        subtitle: "奶油描边，深色壁纸也清楚",
        bodyKind: .cat,
        pattern: .solid,
        palette: PetPalette(
            body: PetColor(hex: "252525"),
            outline: PetColor(hex: "F2E4CB"),
            innerEar: PetColor(hex: "E9A7B4"),
            pawPad: PetColor(hex: "E9A7B4"),
            eye: PetColor(hex: "86CC72"),
            muzzle: PetColor(hex: "3A3430"),
            patchA: PetColor(hex: "252525"),
            patchB: PetColor(hex: "252525"),
            stripe: PetColor(hex: "111111"),
            accent: PetColor(hex: "86CC72")
        ),
        hitRegions: sharedHitRegions,
        anchors: sharedAnchors,
        defaultKeyboardTheme: .cream,
        license: "原创矢量"
    )

    static let orangeTabby = PetSkin(
        id: "orange-tabby",
        name: "橘子虎斑",
        subtitle: "暖色条纹，最耐看",
        bodyKind: .cat,
        pattern: .tabby,
        palette: PetPalette(
            body: PetColor(hex: "E79A4C"),
            outline: PetColor(hex: "3A2A22"),
            innerEar: PetColor(hex: "F2B6A0"),
            pawPad: PetColor(hex: "F2A0A0"),
            eye: PetColor(hex: "C47A2B"),
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
        subtitle: "黑橘白斑块，识别度最高",
        bodyKind: .cat,
        pattern: .calico,
        palette: PetPalette(
            body: PetColor(hex: "FFF9EE"),
            outline: PetColor(hex: "2B2622"),
            innerEar: PetColor(hex: "F2B6C0"),
            pawPad: PetColor(hex: "F2B6C0"),
            eye: PetColor(hex: "C8872C"),
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
        subtitle: "垂耳吐舌，换物种的新鲜感",
        bodyKind: .dog,
        pattern: .solid,
        palette: PetPalette(
            body: PetColor(hex: "F0D6A2"),
            outline: PetColor(hex: "4A3528"),
            innerEar: PetColor(hex: "D6B47A"),
            pawPad: PetColor(hex: "F3C4C4"),
            eye: PetColor(hex: "3A2A22"),
            muzzle: PetColor(hex: "FFF4DC"),
            patchA: PetColor(hex: "F0D6A2"),
            patchB: PetColor(hex: "D6B47A"),
            stripe: PetColor(hex: "F0D6A2"),
            accent: PetColor(hex: "EF8C8C")
        ),
        hitRegions: [
            PetHitRegion(rect: CGRect(x: 0.20, y: 0.22, width: 0.62, height: 0.58), shape: .ellipse),
            PetHitRegion(rect: CGRect(x: 0.24, y: 0.08, width: 0.52, height: 0.44), shape: .ellipse),
            PetHitRegion(rect: CGRect(x: 0.04, y: 0.76, width: 0.18, height: 0.18), shape: .roundedRect),
            PetHitRegion(rect: CGRect(x: 0.22, y: 0.75, width: 0.68, height: 0.23), shape: .roundedRect)
        ],
        anchors: PetAnchors(
            head: PetPoint(0.50, 0.35),
            body: PetPoint(0.50, 0.64),
            leftPaw: PetPoint(0.18, 0.79),
            rightPaw: PetPoint(0.82, 0.80),
            leftEye: PetPoint(0.43, 0.32),
            rightEye: PetPoint(0.57, 0.32),
            tail: PetPoint(0.82, 0.72),
            leftEar: PetPoint(0.31, 0.40),
            rightEar: PetPoint(0.69, 0.40),
            keyboard: PetPoint(0.58, 0.87)
        ),
        defaultKeyboardTheme: .cream,
        license: "原创矢量"
    )
}
