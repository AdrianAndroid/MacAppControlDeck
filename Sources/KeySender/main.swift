import AppKit
import CoreGraphics

// 用法: KeySender <keyCode> <modifierMask>
// modifierMask 位: 1=command 2=control 4=option 8=shift 16=fn
let args = CommandLine.arguments
guard args.count >= 2, let keyCode = UInt16(args[1]) else {
    FileHandle.standardError.write(Data("usage: KeySender <keyCode> [mask]\n".utf8))
    exit(2)
}
let mask = args.count > 2 ? (UInt64(args[2]) ?? 0) : 0
var flags: CGEventFlags = []
if mask & 1 != 0 { flags.insert(.maskCommand) }
if mask & 2 != 0 { flags.insert(.maskControl) }
if mask & 4 != 0 { flags.insert(.maskAlternate) }
if mask & 8 != 0 { flags.insert(.maskShift) }
if mask & 16 != 0 { flags.insert(.maskSecondaryFn) }

for keyDown in [true, false] {
    guard let event = CGEvent(keyboardEventSource: nil,
                              virtualKey: CGKeyCode(keyCode),
                              keyDown: keyDown) else {
        FileHandle.standardError.write(Data("event-create-failed\n".utf8))
        exit(3)
    }
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(60_000)
}
exit(0)
