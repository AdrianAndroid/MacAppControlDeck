import CoreGraphics
import Foundation

/// 新骨架的设计坐标，与 Canvas 一致：原点左上角，y 向下。
enum PetRigLayout {
    static let designSize = CGSize(width: 260, height: 360)
    static let center = PetPoint(130, 180)

    static let hips = PetPoint(130, 286)
    static let neck = PetPoint(130, 142)
    static let head = PetPoint(130, 98)

    static let leftShoulder = PetPoint(102, 186)
    static let rightShoulder = PetPoint(158, 186)
    static let upperArm: CGFloat = 78
    static let forearm: CGFloat = 82

    static let leftHip = PetPoint(104, 300)
    static let rightHip = PetPoint(156, 300)
    static let leftFoot = PetPoint(102, 330)
    static let rightFoot = PetPoint(158, 330)

    static let tailRoot = PetPoint(178, 286)
    static let tailMid = PetPoint(232, 250)
    static let tailTip = PetPoint(244, 198)

    static let mouseCenter = PetPoint(20, 338)
    static let mouseSize = CGSize(width: 44, height: 28)
    static let rightRestPaw = PetPoint(176, 328)

    /// 两段 IK。bend 为 -1 时肘向外侧弯，+1 向内。
    static func elbow(shoulder: PetPoint, paw: PetPoint, bend: CGFloat) -> PetPoint {
        let dx = paw.x - shoulder.x
        let dy = paw.y - shoulder.y
        let distance = max(sqrt(dx * dx + dy * dy), 0.001)
        let reach = upperArm + forearm - 0.5
        let clampedDistance = min(distance, reach)
        let along = (upperArm * upperArm - forearm * forearm + clampedDistance * clampedDistance)
            / (2 * clampedDistance)
        let height = sqrt(max(upperArm * upperArm - along * along, 0))
        let ux = dx / distance
        let uy = dy / distance
        let base = PetPoint(shoulder.x + ux * along, shoulder.y + uy * along)
        return PetPoint(base.x - uy * height * bend, base.y + ux * height * bend)
    }
}
