@nonobjc extension UIViewController {
    func add(_ child: UIViewController?, frame: CGRect? = nil) {
        guard let child = child else { return }
        addChild(child)

        if let frame = frame {
            child.view.frame = frame
        }

        view.addSubview(child.view)

        if frame == nil {
            child.view.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
        }

        child.didMove(toParent: self)
    }

    func remove() {
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }
}
