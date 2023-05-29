import UIKit

protocol SilentViewController: UIViewController {
    var tappableView: UIView? { get }
}

extension SilentViewController {
    var tappableView: UIView? { nil }
}

final class SilentWindow: UIWindow {
    private let root: SilentViewController

    init(root: SilentViewController) {
        self.root = root
        super.init(frame: UIScreen.main.bounds)
        rootViewController = root

        isHidden = false
        windowLevel = UIWindow.Level(rawValue: CGFloat.greatestFiniteMagnitude)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let view = root.tappableView else { return false }
        let viewPoint = convert(point, to: view)
        return view.point(inside: viewPoint, with: event)
    }
}

