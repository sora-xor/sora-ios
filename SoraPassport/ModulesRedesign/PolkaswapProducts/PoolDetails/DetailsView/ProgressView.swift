import SoraUIKit

final class ProgressView: SoramitsuView {
    
    private var widthConstraint: NSLayoutConstraint?

    let progressView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .additionalPolkaswap
        view.sora.cornerRadius = .circle
        return view
    }()

    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func set(progressPercentage: Float) {
        widthConstraint?.constant = 64 * CGFloat(progressPercentage / 100)
    }

    private func setup() {
        sora.backgroundColor = .bgSurfaceVariant
        addSubview(progressView)
    }

    private func setupLayout() {
        widthConstraint = progressView.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 64),
            widthConstraint
        ])
    }
}
