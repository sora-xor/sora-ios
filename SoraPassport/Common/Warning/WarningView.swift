import SoraUIKit
import SnapKit

struct WarningViewModel {
    let title: String
    let descriptionText: String
    var isHidden: Bool
}

final class WarningView: SoramitsuView {

    let containterView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.borderWidth = 1
        view.sora.borderColor = .statusError
        view.sora.backgroundColor = .statusErrorContainer
        view.sora.cornerRadius = .max
        return view
    }()
    
    let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .fill
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 8
        return stackView
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.sora.alignment = .center
        label.sora.font = FontType.paragraphBoldS
        label.sora.textColor = .statusError
        return label
    }()
    
    let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.sora.font = FontType.paragraphS
        label.sora.textColor = .statusError
        return label
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }
    
    func setupView(with model: WarningViewModel) {
        titleLabel.sora.text = model.title
        descriptionLabel.sora.text = model.descriptionText
        
        sora.isHidden = model.isHidden
    }

    private func setupSubviews() {

        addSubview(containterView)
        containterView.addSubviews(stackView)
        stackView.addArrangedSubviews(titleLabel, descriptionLabel)
    }

    private func setupConstrains() {
        let verticalOffset = 16
        let horizontalOffset = 24
        
        containterView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(containterView).offset(horizontalOffset)
            make.centerX.equalTo(containterView)
            make.top.equalTo(containterView).offset(verticalOffset)
            make.centerY.equalTo(containterView)
        }
    }
}
