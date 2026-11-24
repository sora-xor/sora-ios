import UIKit

open class BlurViewController: UIViewController {
    public var isClosable: Bool = true {
        didSet {
            panGestureRecognizer?.isEnabled = isClosable
        }
    }
    
    public var backgroundColor: SoramitsuColor = .custom(uiColor: .clear)
    public var completionHandler: (() -> Void)?
    
    var panGestureRecognizer: UIPanGestureRecognizer?
    var originalPosition: CGPoint?
    var currentPositionTouched: CGPoint?

    /// The screen this one covers whole. The page here is opaque, so once it is up the screen under it
    /// is hidden: that screen is no longer composited behind the page, its lit surfaces stop following
    /// the light and its hero stops drawing. It is shown again before this screen leaves or is dragged.
    private weak var coveredView: UIView?
    /// True from the moment this screen starts to leave until it has appeared again: a drag's snap-back
    /// that ends after that must not hide the screen underneath a second time.
    private var isLeaving = false

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupView()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isLeaving = false
        coverPresenter()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isLeaving = true
        uncoverPresenter()
    }

    deinit {
        // Never leave a screen hidden behind a cover that is gone.
        if let coveredView {
            DispatchQueue.main.async {
                guard coveredView.isHidden else { return }
                coveredView.isHidden = false
                LitStage.changed()
            }
        }
    }

    private func coverPresenter() {
        guard coveredView == nil, !isLeaving, modalPresentationStyle == .overFullScreen, view.window != nil,
              let under = presentingViewController?.view, !under.isHidden, under.window === view.window,
              view.convert(view.bounds, to: nil).insetBy(dx: -0.5, dy: -0.5).contains(under.convert(under.bounds, to: nil))
        else { return }
        under.isHidden = true
        coveredView = under
        LitStage.changed()
    }

    private func uncoverPresenter() {
        guard let under = coveredView else { return }
        coveredView = nil
        under.isHidden = false
        LitStage.changed()
    }
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        view.backgroundColor = SoramitsuUI.shared.theme.palette.color(backgroundColor)
        // A screen presented here stands on its own page. Half a blur of the screen under it showed
        // that screen's red as smears behind the controls.
        let page = AuroraView(style: .standard)
        page.frame = view.bounds
        page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(page)
        view.sendSubviewToBack(page)

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        panGestureRecognizer?.delegate = self
        panGestureRecognizer?.isEnabled = isClosable
        view.addGestureRecognizer(panGestureRecognizer!)
    }

    @objc func panGestureAction(_ panGesture: UIPanGestureRecognizer) {
        let translation = panGesture.translation(in: view)

        if panGesture.state == .began {
            // The screen underneath shows as this one is dragged down.
            uncoverPresenter()
            originalPosition = view.center
            currentPositionTouched = panGesture.location(in: view)
        } else if panGesture.state == .changed {
            view.frame.origin = CGPoint(
                x: 0,
                y: translation.y > 0 ? translation.y : 0
            )
        } else if panGesture.state == .ended {
            let velocity = panGesture.velocity(in: view)

            if velocity.y >= 1500 {
                UIView.animate(withDuration: 0.2
                               , animations: {
                    self.view.frame.origin = CGPoint(
                        x: 0,
                        y: self.view.frame.size.height
                    )
                }, completion: { [weak self] (isCompleted) in
                    if isCompleted {
                        self?.dismiss(animated: false, completion: self?.completionHandler)
                    }
                })
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    self.view.center = self.originalPosition!
                }, completion: { [weak self] finished in
                    // Back in place and still the screen on top: what is under it is covered again.
                    if finished { self?.coverPresenter() }
                })
            }
        } else if panGesture.state == .cancelled || panGesture.state == .failed {
            // An interrupted drag (a call, an alert) leaves the screen where the finger was: put it back.
            if let originalPosition { view.center = originalPosition }
            coverPresenter()
        }
    }
}

extension BlurViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return velocity.y > abs(velocity.x)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Table and form scrolling belongs to the scroll view. A blanket
        // dismissal pan otherwise wins and strands long modal content.
        var touchedView = touch.view
        while let candidate = touchedView, candidate !== view {
            if candidate is UIScrollView { return false }
            touchedView = candidate.superview
        }
        return true
    }
}
