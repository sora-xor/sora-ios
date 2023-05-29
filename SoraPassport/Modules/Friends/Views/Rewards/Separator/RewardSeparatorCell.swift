import UIKit
import Then
import Anchorage
import SoraUI

final class RewardSeparatorCell: UITableViewCell {

    // MARK: - Outlets
    private var containerView: UIView = {
        ShadowShapeView().then {
            $0.fillColor = R.color.neumorphism.backgroundLightGrey() ?? .white
            $0.shadowOpacity = 0.3
            $0.shadowColor = UIColor(white: 0, alpha: 0.3)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    private var graySeparatorView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.neumorphism.separator()
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
        }
    }()
    
    private var whiteSeparatorView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.brandWhite()
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
        }
    }()
    
    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var path = UIBezierPath()
        
        path.append(UIBezierPath(rect: CGRect(x: -3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height)))
        
        path.append(UIBezierPath(rect: CGRect(x: containerView.bounds.width + 3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height)))
        
        containerView.layer.shadowPath = path.cgPath
    }
}

extension RewardSeparatorCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? RewardSeparatorViewModel else { return }
//        containerView.roundingCorners = [ .topLeft, .topRight ]
    }
}

private extension RewardSeparatorCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = R.color.baseBackground()

        contentView.addSubview(containerView)
        containerView.addSubview(graySeparatorView)
        containerView.addSubview(whiteSeparatorView)

        containerView.do {
            $0.topAnchor == contentView.topAnchor
            $0.bottomAnchor == contentView.bottomAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.heightAnchor == 17
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        graySeparatorView.do {
            $0.topAnchor == containerView.topAnchor + 8
            $0.leadingAnchor == containerView.leadingAnchor
            $0.centerXAnchor == containerView.centerXAnchor
        }

        whiteSeparatorView.do {
            $0.topAnchor == graySeparatorView.bottomAnchor
            $0.leadingAnchor == containerView.leadingAnchor
            $0.centerXAnchor == containerView.centerXAnchor
            $0.heightAnchor == 1
        }
    }
}
