/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol InvitationActionViewDelegate: class {
    func invitationAction(view: InvitationActionView, didSelectActionAt index: Int)
}

final class InvitationActionView: UIView {
    weak var delegate: InvitationActionViewDelegate?

    var contentInsets = UIEdgeInsets(top: 0.0, left: 20.0, bottom: 20.0, right: 20.0) {
        didSet {
            if oldValue !=  contentInsets {
                updateContentLayout()
                setNeedsLayout()
            }
        }
    }

    var verticalSpacing: CGFloat = 20.0 {
        didSet {
            if oldValue != verticalSpacing {
                updateContentLayout()
                setNeedsLayout()
            }
        }
    }

    var actionPreferredHeight: CGFloat = 67.0 {
        didSet {
            if actionButtons.count > 0 {
                actionButtons.forEach { actionButton in
                    let heightConstraint = actionButton.constraints.first { $0.firstAttribute == .height }
                    heightConstraint?.constant = actionPreferredHeight
                }

                setNeedsLayout()
            }
        }
    }

    private var headerLabel: UILabel?
    private var actionButtons: [RoundedCellControlView] = []
    private var footerLabel: UILabel?

    private var dynamicConstrainst: [NSLayoutConstraint] = []

    func bind(viewModel: InvitationActionListViewModel) {
        let isHeaderLayoutChanged = updateHeaderLabel(for: viewModel)
        let isActionsLayoutChanged = updateActions(for: viewModel)
        let isFooterLayoutChanged = updateFooterLabel(for: viewModel)

        if isHeaderLayoutChanged || isActionsLayoutChanged || isFooterLayoutChanged {
            updateContentLayout()
        }

        setNeedsLayout()
    }

    func changeAccessory(title: String, at actionIndex: Int) {
        if actionIndex < actionButtons.count {
            actionButtons[actionIndex].titleAccessoryView.accessoryLabel.text = title
            actionButtons[actionIndex].invalidateLayout()
        }
    }

    func changeAccessory(style: InvitationActionStyle, at actionIndex: Int) {
        if actionIndex < actionButtons.count {
            apply(style: style, to: actionButtons[actionIndex].titleAccessoryView.accessoryLabel)
        }
    }

    // MARK: Subviews

    private func updateHeaderLabel(for viewModel: InvitationActionListViewModel) -> Bool {
        var hasLayoutChanges = false

        if let headerText = viewModel.headerText {
            if headerLabel == nil {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.font = .darkGreyishSemiboldLabel
                label.textColor = .darkGreyish
                label.numberOfLines = 0

                addSubview(label)

                headerLabel = label

                hasLayoutChanges = true
            }

            headerLabel?.text = headerText
        } else {
            if headerLabel != nil {
                headerLabel?.removeFromSuperview()
                headerLabel = nil

                hasLayoutChanges = true
            }
        }

        return hasLayoutChanges
    }

    private func updateActions(for viewModel: InvitationActionListViewModel) -> Bool {
        let hasLayoutChanges = viewModel.actions.count != actionButtons.count

        if actionButtons.count < viewModel.actions.count {
            let count = viewModel.actions.count - actionButtons.count
            (0..<count).forEach { _ in
                let actionButton = createActionButton()
                addSubview(actionButton)
                actionButtons.append(actionButton)
            }
        } else {
            let count = actionButtons.count - viewModel.actions.count
            (0..<count).forEach { _ in
                let actionButton = actionButtons.popLast()
                actionButton?.removeFromSuperview()
            }
        }

        for (index, actionButton) in actionButtons.enumerated() {
            let actionViewModel = viewModel.actions[index]

            actionButton.titleAccessoryView.titleView.title = actionViewModel.title
            actionButton.titleAccessoryView.titleView.iconImage = actionViewModel.icon
            actionButton.titleAccessoryView.accessoryLabel.text = actionViewModel.accessoryText

            apply(style: actionViewModel.style, to: actionButton.titleAccessoryView.accessoryLabel)

            if index == 0 {
                if actionButtons.count == 1 {
                    actionButton.roundedBackgroundView.roundingCorners = .allCorners
                    actionButton.borderView.borderType = []
                } else {
                    actionButton.roundedBackgroundView.roundingCorners = [.topLeft, .topRight]
                    actionButton.borderView.borderType = [.bottom]
                }
            } else if index == actionButtons.count - 1 {
                actionButton.roundedBackgroundView.roundingCorners = [.bottomLeft, .bottomRight]
                actionButton.borderView.borderType = []
            } else {
                actionButton.roundedBackgroundView.roundingCorners = []
                actionButton.borderView.borderType = [.bottom]
            }

            actionButton.invalidateLayout()
        }

        return hasLayoutChanges
    }

    private func updateFooterLabel(for viewModel: InvitationActionListViewModel) -> Bool {
        var hasLayoutChanges = false

        if let footerText = viewModel.footerText {
            if footerLabel == nil {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.font = .greyishRegularLabel
                label.textColor = .greyish
                label.numberOfLines = 0

                addSubview(label)

                footerLabel = label

                hasLayoutChanges = true
            }

            footerLabel?.text = footerText
        } else {
            if footerLabel != nil {
                footerLabel?.removeFromSuperview()
                footerLabel = nil

                hasLayoutChanges = true
            }
        }

        return hasLayoutChanges
    }

    private func updateContentLayout() {
        dynamicConstrainst.forEach { $0.isActive = false }

        updateHeaderLabelLayout()
        updateActionsLayout()
        updateFooterLabelLayout()

        let topViewAnchor = ((footerLabel?.bottomAnchor ?? actionButtons.last?.bottomAnchor)
            ?? headerLabel?.bottomAnchor) ?? topAnchor

        let bottom = bottomAnchor.constraint(equalTo: topViewAnchor, constant: contentInsets.bottom)
        bottom.isActive = true
        dynamicConstrainst.append(bottom)
    }

    private func updateHeaderLabelLayout() {
        if let headerLabel = headerLabel {
            let top = headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top)
            top.isActive = true
            dynamicConstrainst.append(top)

            let leading = headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor,
                                                               constant: contentInsets.left)
            leading.isActive = true
            dynamicConstrainst.append(leading)

            let trailing =  headerLabel.trailingAnchor.constraint(equalTo: trailingAnchor,
                                                                  constant: -contentInsets.right)
            trailing.isActive = true
            dynamicConstrainst.append(trailing)
        }
    }

    private func updateActionsLayout() {
        for (index, actionButton) in actionButtons.enumerated() {
            let leading = actionButton.leadingAnchor.constraint(equalTo: leadingAnchor,
                                                                constant: contentInsets.left)
            leading.isActive = true
            dynamicConstrainst.append(leading)

            let trailing = actionButton.trailingAnchor.constraint(equalTo: trailingAnchor,
                                                                  constant: -contentInsets.right)
            trailing.isActive = true
            dynamicConstrainst.append(trailing)

            if index == 0 {
                if let headerLabel = headerLabel {
                    let top = actionButton.topAnchor.constraint(equalTo: headerLabel.bottomAnchor,
                                                                constant: verticalSpacing)
                    top.isActive = true
                    dynamicConstrainst.append(top)
                } else {
                    let top = actionButton.topAnchor.constraint(equalTo: topAnchor,
                                                                constant: contentInsets.top)
                    top.isActive = true
                    dynamicConstrainst.append(top)
                }
            } else {
                let top = actionButton.topAnchor.constraint(equalTo: actionButtons[index - 1].bottomAnchor)
                top.isActive = true
                dynamicConstrainst.append(top)
            }
        }
    }

    private func updateFooterLabelLayout() {
        if let footerLabel = footerLabel {
            let leading = footerLabel.leadingAnchor.constraint(equalTo: leadingAnchor,
                                                               constant: contentInsets.left)
            leading.isActive = true
            dynamicConstrainst.append(leading)

            let trailing =  footerLabel.trailingAnchor.constraint(equalTo: trailingAnchor,
                                                                  constant: -contentInsets.right)
            trailing.isActive = true
            dynamicConstrainst.append(trailing)

            let vertical: NSLayoutConstraint

            if let topViewAnchor = (actionButtons.last?.bottomAnchor ?? headerLabel?.bottomAnchor) {
                vertical = footerLabel.topAnchor.constraint(equalTo: topViewAnchor,
                                                            constant: verticalSpacing)
            } else {
                vertical = footerLabel.topAnchor.constraint(equalTo: topAnchor,
                                                            constant: verticalSpacing)
            }

            vertical.isActive = true
            dynamicConstrainst.append(vertical)
        }
    }

    private func createActionButton() -> RoundedCellControlView {
        let actionButton = RoundedCellControlView()
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.roundedBackgroundView.fillColor = .white
        actionButton.roundedBackgroundView.highlightedFillColor = .white
        actionButton.roundedBackgroundView.shadowColor = .greyish
        actionButton.roundedBackgroundView.shadowOpacity = 0.24
        actionButton.roundedBackgroundView.shadowOffset = CGSize(width: 0.0, height: 1.0)
        actionButton.roundedBackgroundView.shadowRadius = 2.0
        actionButton.titleAccessoryView.titleView.spacingBetweenLabelAndIcon = 15.0
        actionButton.contentInsets.left = 20.0
        actionButton.contentInsets.right = 20.0
        actionButton.titleAccessoryView.titleView.titleFont = .roundedContentCellText
        actionButton.titleAccessoryView.titleView.titleColor = .actionTitle
        actionButton.titleAccessoryView.accessoryLabel.textColor = .coolGrey
        actionButton.titleAccessoryView.accessoryLabel.font = .roundedContentCellText
        actionButton.changesContentOpacityWhenHighlighted = true
        actionButton.borderView.strokeColor = .listSeparator
        actionButton.borderView.strokeWidth = 1.0

        actionButton.heightAnchor.constraint(equalToConstant: actionPreferredHeight).isActive = true

        actionButton.addTarget(self,
                               action: #selector(didSelect(actionButton:)),
                               for: .touchUpInside)

        return actionButton
    }

    private func apply(style: InvitationActionStyle, to accessoryLabel: UILabel) {
        switch style {
        case .normal:
            accessoryLabel.textColor = .coolGrey
        case .critical:
            accessoryLabel.textColor = .darkRed
        }
    }

    // MARK: Action

    @objc private func didSelect(actionButton: RoundedCellControlView) {
        if let index = actionButtons.firstIndex(of: actionButton) {
            delegate?.invitationAction(view: self, didSelectActionAt: index)
        }
    }
}
