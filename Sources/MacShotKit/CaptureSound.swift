import AVFoundation
import Foundation

/// 截图快门音。播放等待音频设备启动（蓝牙耳机可达 9 秒），
/// 因此全部工作放在独立串行队列，绝不阻塞主线程。
final class CaptureSound: @unchecked Sendable {
    static let shared = CaptureSound(start: CaptureSound.playerStart())

    private let queue = DispatchQueue(label: "com.macappcontroldeck.capture-sound", qos: .userInitiated)
    private let start: (_ prepareOnly: Bool) -> Void

    init(start: @escaping (_ prepareOnly: Bool) -> Void) {
        self.start = start
    }

    func play() {
        queue.async { self.start(false) }
    }

    func warmUp() {
        queue.async { self.start(true) }
    }

    func drain() {
        queue.sync {}
    }

    private static let soundURLs = [
        URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"),
        URL(fileURLWithPath: "/System/Library/Sounds/Tink.aiff"),
    ]

    private static func playerStart() -> (Bool) -> Void {
        var player: AVAudioPlayer?
        return { prepareOnly in
            if player == nil {
                player = soundURLs.lazy.compactMap { try? AVAudioPlayer(contentsOf: $0) }.first
            }
            guard let player else { return }
            if prepareOnly {
                player.prepareToPlay()
                return
            }
            player.stop()
            player.currentTime = 0
            player.play()
        }
    }
}
