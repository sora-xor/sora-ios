import UIKit
import Then
import Anchorage

public extension UIView {
    static func empty(height: CGFloat? = nil, width: CGFloat? = nil) -> UIView {
        UIView().then {
            $0.backgroundColor = .clear

            if let height = height {
                $0.heightAnchor == height
            }

            if let width = width {
                $0.widthAnchor == width
            }
        }
    }

    func wrapped(height: CGFloat? = nil, width: CGFloat? = nil) -> UIView {
        UIView.empty(height: height, width: width).then {
            $0.addSubview(self)
            self.edgeAnchors == $0.edgeAnchors
        }
    }
}
