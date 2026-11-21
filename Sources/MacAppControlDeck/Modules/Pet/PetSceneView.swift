import SwiftUI

/// 面板里的唯一根视图。只订阅状态机，不处理鼠标。
struct PetSceneView: View {
    @ObservedObject var state: PetStateMachine

    var body: some View {
        Group {
            if PetRasterAssets.shared != nil {
                PetRasterArt(frame: state.rasterFrame)
            } else {
                PetVectorArt(
                    skin: state.skin,
                    theme: state.keyboardTheme,
                    detail: state.size.detail,
                    snapshot: state.snapshot
                )
            }
        }
        .frame(
            width: PetGeometry.visualSize(for: state.size).width,
            height: PetGeometry.visualSize(for: state.size).height
        )
        .animation(.easeOut(duration: 0.18), value: state.size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 设置页的实时小预览。
struct PetLivePreview: View {
    @ObservedObject var settings: PetSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            if PetRasterAssets.shared != nil {
                PetRasterArt(frame: PetRasterFrame(
                    eyeX: CGFloat(sin(t * 1.1)) * 8,
                    eyeY: CGFloat(sin(t * 0.7)) * 3,
                    headYaw: CGFloat(sin(t * 0.8)) * 2.5,
                    headPitch: CGFloat(sin(t * 0.6)) * 1.5,
                    bob: CGFloat(sin(t * 1.3)) * 1.2,
                    keycaps: []
                ))
                .frame(width: 200, height: 266)
            } else {
            PetVectorArt(
                skin: settings.skin,
                theme: settings.keyboardTheme,
                detail: .standard,
                snapshot: PetSnapshot(
                    blink: sin(t * 1.7) > 0.96 ? 1 : 0,
                    bodyBounce: abs(sin(t * 1.4)) * 0.012,
                    tailWag: CGFloat(sin(t * 2)),
                    earTwitch: CGFloat(sin(t * 3.4))
                )
            )
            .frame(width: 200, height: 277)
            }
        }
        .frame(width: 200, height: 277)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        )
    }
}

struct PetSkinSwatch: View {
    let skin: PetSkin
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            PetVectorArt(skin: skin, theme: skin.defaultKeyboardTheme, detail: .compact, snapshot: .idle)
                .frame(width: 84, height: 116)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            Text(skin.name)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.accentColor : .primary)
        }
        .contentShape(Rectangle())
    }
}
