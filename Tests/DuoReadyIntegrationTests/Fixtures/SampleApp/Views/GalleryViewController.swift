import UIKit

final class GalleryViewController: UIViewController {
    private let stack = UIStackView()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let itemWidth = UIScreen.main.bounds.width / 3

        if UIDevice.current.orientation.isLandscape {
            stack.axis = .horizontal
        } else {
            stack.axis = .vertical
        }
        layout(itemWidth: itemWidth)
    }

    private func layout(itemWidth: CGFloat) {}
}
