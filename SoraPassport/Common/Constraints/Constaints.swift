import UIKit

public extension NSLayoutConstraint {

    var reverse: NSLayoutConstraint {
        constant = -1 * constant
        return self
    }

    var double: NSLayoutConstraint {
        constant = 2 * constant
        return self
    }

    static func activate(_ constraints: [NSLayoutConstraint?]) {
        activate(constraints.compactMap { $0 })
    }

    static func deactivate(_ constraints: [NSLayoutConstraint?]) {
        deactivate(constraints.compactMap { $0 })
    }

    @discardableResult func priority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }

    @discardableResult func priority(_ priority: Float) -> NSLayoutConstraint {
        self.priority = .init(priority)
        return self
    }

    @discardableResult func activate() -> NSLayoutConstraint {
        isActive = true
        return self
    }

    @discardableResult func deactivate() -> NSLayoutConstraint {
        isActive = false
        return self
    }
}
