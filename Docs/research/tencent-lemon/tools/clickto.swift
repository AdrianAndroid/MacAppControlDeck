import Cocoa

let args = CommandLine.arguments
guard args.count >= 5,
      let pid = Int32(args[1]),
      let x = Double(args[2]),
      let y = Double(args[3]),
      let clicks = Int(args[4]) as Int? else {
    FileHandle.standardError.write("usage: clickto <pid> <x> <y> <clicks>\n".data(using: .utf8)!)
    exit(2)
}
let point = CGPoint(x: x, y: y)
for i in 0..<clicks {
    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)!
    down.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)!
    up.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
    down.postToPid(pid)
    usleep(40_000)
    up.postToPid(pid)
    usleep(120_000)
}
