import Foundation
import UIKit
import SoraUIKit

final class BalanceDetailsViewController: SoramitsuViewController {

    private let swipeView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .fgTertiary
        view.sora.cornerRadius = .circle
        return view
    }()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 0
        return view
    }()
    

    var viewModels: [BalanceDetailViewModel]

    init(viewModels: [BalanceDetailViewModel]) {
        self.viewModels = viewModels
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        
        for (index, model) in viewModels.enumerated() {
            let view = BalanceDetailView()
            view.viewModel = model
            view.heightAnchor.constraint(equalToConstant: 48).isActive = true
            stackView.addArrangedSubview(view)
            
            if index != viewModels.count - 1 {
                let view = SoramitsuView()
                view.heightAnchor.constraint(equalToConstant: 24).isActive = true
                
                if index != 0 {
                    let separatorView = SoramitsuView()
                    separatorView.sora.backgroundColor = .fgOutline
                    view.addSubview(separatorView)
                    separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                    separatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
                    separatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                    separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
                }

                stackView.addArrangedSubview(view)
            }
        }
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubviews(stackView, swipeView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            swipeView.widthAnchor.constraint(equalToConstant: 32),
            swipeView.heightAnchor.constraint(equalToConstant: 4),
            swipeView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            swipeView.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -8),
            
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }
}
