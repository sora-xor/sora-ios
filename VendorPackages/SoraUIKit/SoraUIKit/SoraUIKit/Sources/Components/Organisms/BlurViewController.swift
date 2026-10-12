import UIKit

open class BlurViewController: UIViewController {
    public var isClosable: Bool = true {
        didSet {
            panGestureRecognizer?.isEnabled = isClosable
        }
    }
    
    public var backgroundColor: SoramitsuColor = .custom(uiColor: .clear) {
        didSet {
            if isViewLoaded { applyBackground() }
        }
    }
    public var completionHandler: (() -> Void)?

    /// Theme-aware backdrop: a dark blur and scrim in dark mode, a light one
    /// in light mode. It follows theme changes while the modal is open.
    lazy var blurredView: UIView = {
        let backdrop = NeonScrimView(frame: view.bounds)
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return backdrop
    }()

    var panGestureRecognizer: UIPanGestureRecognizer?
    var originalPosition: CGPoint?
    var currentPositionTouched: CGPoint?

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupView()
    }
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyBackground() {
        let color = SoramitsuUI.shared.theme.palette.color(backgroundColor)
        view.backgroundColor = color
        // An opaque page (the PIN root) has nothing behind it to blur.
        blurredView.isHidden = color.cgColor.alpha >= 1
    }

    func setupView() {
        applyBackground()
        SoramitsuUI.updates.addObserver(self)
        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        panGestureRecognizer?.isEnabled = isClosable
        view.addGestureRecognizer(panGestureRecognizer!)
    }

    @objc func panGestureAction(_ panGesture: UIPanGestureRecognizer) {
        let translation = panGesture.translation(in: view)

        if panGesture.state == .began {
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
                })
            }
        }
    }
}

extension BlurViewController: SoramitsuObserver {
    public func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { applyBackground() }
    }
}
