import SoraUIKit
import UIKit

final class ConfirmAssetsCell: SoramitsuTableViewCell {
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fillEqually
        view.spacing = 8
        view.sora.clipsToBounds = false
        return view
    }()
    
    private let firstAsset: ConfirmAssetView = {
        let view = ConfirmAssetView()
        view.sora.cornerRadius = .max
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        return view
    }()
    
    private let secondAsset: ConfirmAssetView = {
        let view = ConfirmAssetView()
        view.sora.cornerRadius = .max
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        return view
    }()

    private let operationImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.backgroundColor = .bgSurface
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
        stackView.addArrangedSubviews(firstAsset, secondAsset)
        contentView.addSubviews(stackView, operationImageView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            operationImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            operationImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            operationImageView.widthAnchor.constraint(equalToConstant: 24),
            operationImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
}

extension ConfirmAssetsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ConfirmAssetsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        item.firstAssetImageModel.imageViewModel?.loadImage { [weak self] (icon, _) in
            self?.firstAsset.imageView.image = icon
        }
        
        item.secondAssetImageModel.imageViewModel?.loadImage { [weak self] (icon, _) in
            self?.secondAsset.imageView.image = icon
        }

        firstAsset.symbolLabel.sora.text = item.firstAssetImageModel.symbol
        firstAsset.amountLabel.sora.text = item.firstAssetImageModel.amountText
        
        secondAsset.symbolLabel.sora.text = item.secondAssetImageModel.symbol
        secondAsset.amountLabel.sora.text = item.secondAssetImageModel.amountText
        
        operationImageView.image = UIImage(named: item.operationImageName)
    }
}

