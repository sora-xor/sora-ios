/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraFoundation
import SoraUI
import Anchorage

protocol InputRewardAmountViewDelegate: AnyObject {

}

protocol InputRewardAmountViewOutput: AnyObject {
    func willMove()
}

protocol InputRewardAmountViewInput: AnyObject {
    func setupTitle(with text: String)
    func setup(with models: [CellViewModel])
    func reloadCell(at indexPath: IndexPath, models: [CellViewModel])
    func dismiss(with completion: @escaping () -> Void)
}

final class InputRewardAmountView: RoundedView {

    private struct Constants {
        static let titleLabelTopOffset = CGFloat(20)
        static let titleHeight = CGFloat(11)
    }

    weak var viewController: UIViewController?
    var presenter: InputRewardAmountViewOutput?
    var contentViewModels: [CellViewModel] = []

    var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4).withSize(11.0)
            $0.textColor = R.color.neumorphism.text()
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    lazy var tableView: UITableView = {
        UITableView().then {
            $0.separatorInset = .zero
            $0.separatorColor = .clear
            if #available(iOS 15.0, *) {
                $0.sectionHeaderTopPadding = 0
            }
            $0.backgroundColor = .clear
            $0.estimatedRowHeight = 100
            $0.rowHeight = UITableView.automaticDimension
            $0.register(
                SpaceCell.self,
                forCellReuseIdentifier: SpaceCell.reuseIdentifier)
            $0.register(
                TitleDescriptionCell.self,
                forCellReuseIdentifier: TitleDescriptionCell.reuseIdentifier
            )
            $0.register(
                AmountCell.self,
                forCellReuseIdentifier: AmountCell.reuseIdentifier
            )
            $0.register(
                TextCell.self,
                forCellReuseIdentifier: TextCell.reuseIdentifier
            )
            $0.register(
                ButtonCell.self,
                forCellReuseIdentifier: ButtonCell.reuseIdentifier
            )
            $0.dataSource = self
            $0.delegate = self
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)

        cornerRadius = 40.0
        shadowColor = R.color.neumorphism.base()!
        roundingCorners = [.topLeft, .topRight]

        addSubview(titleLabel)
        addSubview(tableView)

        titleLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.topAnchor == topAnchor + Constants.titleLabelTopOffset
            $0.heightAnchor == Constants.titleHeight
        }

        tableView.do {
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor
            $0.topAnchor == titleLabel.bottomAnchor
            $0.bottomAnchor == bottomAnchor
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        presenter?.willMove()
    }

    @objc
    func keyboardWillShow(_ notification:Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        }
    }

    @objc
    func keyboardWillHide(_ notification:Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
}

extension InputRewardAmountView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contentViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = contentViewModels[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: viewModel.cellReuseIdentifier, for: indexPath
        ) as? Reusable else {
            fatalError("Could not dequeue cell with identifier: ChangeAccountTableViewCell")
        }
        cell.bind(viewModel: contentViewModels[indexPath.row])
        return cell
    }
}

extension InputRewardAmountView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension InputRewardAmountView: InputRewardAmountViewInput {
    func setupTitle(with text: String) {
        titleLabel.text = text
    }

    func setup(with models: [CellViewModel]) {
        contentViewModels = models
        tableView.reloadData()
    }

    func reloadCell(at indexPath: IndexPath, models: [CellViewModel]) {
        contentViewModels = models
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func dismiss(with completion: @escaping () -> Void) {
        viewController?.dismiss(animated: true, completion: completion)
    }
}

extension InputRewardAmountView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
}
