import SoraUIKit
import Anchorage

class AccountOptionSeparator: SoramitsuView {
    let separatorView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .fgOutline
        return view
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 56),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0)
        ])
    }
}
