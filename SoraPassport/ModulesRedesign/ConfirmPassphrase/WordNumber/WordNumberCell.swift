import SoraUIKit

final class WordNumberCell: SoramitsuTableViewCell {
    
    private var wordNumberItem: WordNumberItem?

    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        return view
    }()
    
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.mnemonicConfirmationSelectWordNumber(preferredLanguages: .currentLocale)
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        return label
    }()

    private let numberLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.text = ""
        label.font = UIFont.boldSystemFont(ofSize: 128)
        label.textColor = SoramitsuUI.shared.theme.palette.color(.fgPrimary)
        label.textAlignment = .center
        return label
    }()
    
    private let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.mnemonicConfirmationSelectWord2(preferredLanguages: .currentLocale)
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        return label
    }()
    
    private let circlesStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .equalCentering
        view.sora.alignment = .center
        view.spacing = 8
        view.sora.clipsToBounds = false
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return view
    }()
    
    private let buttonsStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .vertical
        view.sora.distribution = .fillEqually
        view.spacing = 16
        view.sora.clipsToBounds = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubviews(containerView)
        contentView.addSubviews(buttonsStackView)
        containerView.addSubviews(titleLabel, numberLabel, descriptionLabel, circlesStackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            numberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            numberLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            numberLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),

            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            descriptionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 16),
            
            circlesStackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 24),
            circlesStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            circlesStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            circlesStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            
            buttonsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            buttonsStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 24),
            buttonsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}

extension WordNumberCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? WordNumberItem else {
            assertionFailure("Incorect type of item")
            return
        }
        wordNumberItem = item
        
        circlesStackView.removeArrangedSubviews()
        for i in 0..<3 {
            let view = SoramitsuView()
            view.sora.backgroundColor = i < item.currentStage ? .accentPrimary : .bgSurfaceVariant
            view.sora.cornerRadius = .circle
            view.widthAnchor.constraint(equalToConstant: 24).isActive = true
            view.heightAnchor.constraint(equalToConstant: 24).isActive = true
            circlesStackView.addArrangedSubview(view)
        }
        
        buttonsStackView.removeArrangedSubviews()
        for variant in item.variants {
            let variantText = SoramitsuTextItem(text: variant,
                                                fontData: FontType.buttonM,
                                                textColor: .accentPrimary,
                                                alignment: .center)
            
            let view = SoramitsuButton()
            view.sora.backgroundColor = .bgSurface
            view.sora.cornerRadius = .large
            view.sora.attributedText = variantText
            view.heightAnchor.constraint(equalToConstant: 56).isActive = true
            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                guard let self = self else { return }
                self.wordNumberItem?.tryHandler?(variant)
            }
            buttonsStackView.addArrangedSubview(view)
        }

        numberLabel.text = "\(item.index)"
    }
}

