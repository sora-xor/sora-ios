extension UIViewController {
    static let indicatorViewTag = 1001
    
    func startLoader(
        backgroundColor: UIColor = .clear,
        indicatorColor: UIColor = .gray
    ) {
        let bgView = UIView(frame: view.bounds)
        bgView.tag = Self.indicatorViewTag
        bgView.backgroundColor = backgroundColor
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.center = view.center
        indicator.color = indicatorColor
        bgView.addSubview(indicator)
        view.addSubview(bgView)
        indicator.startAnimating()
    }

    func stopLoader() {
        view.viewWithTag(Self.indicatorViewTag)?.removeFromSuperview()
    }
}
