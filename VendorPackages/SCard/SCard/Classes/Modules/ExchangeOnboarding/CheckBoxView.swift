import SoraUIKit

class CheckBoxView: UIControl {

    let selectionColor: UIColor
    let borderColor: UIColor

    private let icon: SoramitsuImageView = {
        let view = SoramitsuImageView()
        return view
    }()

    private let title: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphS
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let checkBoxOnImage: UIImage
    private let checkBoxOffImage = R.image.checkBoxOff()

    init(
        title: String,
        borderColor: UIColor = SoramitsuUI.shared.theme.palette.color(.bgSurfaceVariant),
        selectionColor: UIColor = SoramitsuUI.shared.theme.palette.color(.accentPrimary)
    ) {
        self.title.sora.text = title
        self.borderColor = borderColor
        self.selectionColor = selectionColor
        self.checkBoxOnImage = R.image.checkBoxOn() ?? .init()
        super.init(frame: .zero)
        setupInitialLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            icon.image = isSelected ? checkBoxOnImage : checkBoxOffImage
            icon.tintColor = isSelected ? selectionColor : SoramitsuUI.shared.theme.palette.color(.fgPrimary)
            layer.borderColor = isSelected ? selectionColor.cgColor : borderColor.cgColor
        }
    }

    private func setupInitialLayout() {
        addSubview(icon) {
            $0.leading.equalToSuperview().inset(16)
            $0.top.bottom.equalToSuperview().inset(8)
            $0.size.equalTo(24)
        }

        addSubview(title) {
            $0.leading.equalTo(icon.snp.trailing).offset(16)
            $0.top.bottom.equalToSuperview().inset(10)
            $0.trailing.equalToSuperview().inset(16)
        }

        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = borderColor.cgColor
    }
}
