import UIKit

final class LegacyBanner: UIView {
    func height() -> CGFloat {
        UIScreen.main.scale > 2 ? 44 : 40
    }
}
