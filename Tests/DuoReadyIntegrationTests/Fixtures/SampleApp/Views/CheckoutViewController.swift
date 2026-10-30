import UIKit

final class CheckoutViewController: UIViewController {
    private let summary = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        let topInset: CGFloat = view.bounds.height == 812 ? 44 : 20
        NSLayoutConstraint.activate([
            summary.widthAnchor.constraint(equalToConstant: 375),
            summary.heightAnchor.constraint(equalToConstant: 120),
            summary.topAnchor.constraint(equalTo: view.topAnchor, constant: topInset),
        ])
    }
}
