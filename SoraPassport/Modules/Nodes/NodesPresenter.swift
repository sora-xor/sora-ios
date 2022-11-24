/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

enum NodeAction {
    case add
    case select(node: ChainNodeModel)
    case copy(node: ChainNodeModel)
    case edit(node: ChainNodeModel)
    case remove(node: ChainNodeModel)
}

final class NodesPresenter {
    weak var view: NodesViewProtocol?
    var wireframe: NodesWireframeProtocol!
    var interactor: NodesInteractorInputProtocol!
}

// MARK: - Presenter Protocol

extension NodesPresenter: NodesPresenterProtocol, AuthorizationPresentable {
    func didReceive(chain: ChainModel) {
        updateScreen(with: chain)
    }

    func setup() {
        interactor.setup()
    }
}

extension NodesPresenter: NodesInteractorOutputProtocol {
    func restart() {
        DispatchQueue.main.async {
            self.wireframe?.showRoot()
        }
    }

    func showConnectionFailed() {
        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.selectNodeUnableJoinNodeTitle(preferredLanguages: .currentLocale),
            message: R.string.localizable.selectNodeUnableJoinNodeMessage(preferredLanguages: .currentLocale),
            actions: [],
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale)
        )
        present(viewModel: viewModel, style: .alert, from: view)
    }
}

extension NodesPresenter: NodesCellDelegate {
    func onAction(_ action: NodeAction) {
        switch action {
        case .select(let node):
            onSelected(node)
        case .copy(let node):
            onCopy(node)
        case .remove(let node):
            onRemove(node)
        case .edit(_), .add:
            onCustomAction(action)
        }
    }

    private func onCopy(_ node: ChainNodeModel) {
        UIPasteboard.general.string = node.url.description
    }

    private func onCustomAction(_ action: NodeAction) {
        guard let controller = view?.controller else { return }
        let chain = interactor.chain
        wireframe?.showCustomNode(from: controller, chain: chain, action: action, completion: { [weak self] chain in
            self?.updateScreen(with: chain)
        })
    }

    private func onRemove(_ node: ChainNodeModel) {

        let removeAction = AlertPresentableAction(
            title: R.string.localizable.commonRemove(preferredLanguages: .currentLocale)
        ) {
            // TODO: impl remove node
            self.interactor.removeNode(node)
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.removeNodeTitle(preferredLanguages: .currentLocale),
            message: nil,
            actions: [removeAction],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: .currentLocale)
        )
        present(viewModel: viewModel, style: .alert, from: view)
    }

    // TODO: use it
    private func unableToRemove(_ node: ChainNodeModel) {

        let removeAction = AlertPresentableAction(
            title: R.string.localizable.commonOk(preferredLanguages: .currentLocale)
        ) {
            // TODO: impl remove node
            print("TODO: impl remove node")
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.removeNodeErrorTitle(preferredLanguages: .currentLocale),
            message: R.string.localizable.removeNodeErrorMessage(preferredLanguages: .currentLocale),
            actions: [removeAction],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: .currentLocale)
        )
        present(viewModel: viewModel, style: .alert, from: view)
    }

    private func onSelected(_ node: ChainNodeModel) {
        authorize(animated: true,
                  cancellable: true,
                  inView: nil) { [weak self] (isAuthorized) in

            guard isAuthorized, let view = self?.view else { return }

            let actionTitle = R.string.localizable.commonOk(preferredLanguages: .currentLocale)
            let action = AlertPresentableAction(title: actionTitle) { [weak self] in
                self?.interactor.changeSelectedNode(to: node)
            }

            let title = R.string.localizable.selectNodeSwitchAlertTitle(preferredLanguages: .currentLocale)
            let message = R.string.localizable.selectNodeSwitchAlertDescription(preferredLanguages: .currentLocale)
            let viewModel = AlertPresentableViewModel(title: title,
                                                      message: message,
                                                      actions: [action],
                                                      closeAction: R.string.localizable.commonCancel(preferredLanguages: .currentLocale) )
            self?.present(viewModel: viewModel, style: .alert, from: view)
        }
    }
}

private extension NodesPresenter {
    func createItems(with nodes: [NodeViewModel], customNodes: [NodeViewModel]) -> [SectionViewModel] {
        var items: [SectionViewModel] = []
        items.append(SectionViewModel(header: NodesHeaderViewModel(title: R.string.localizable.selectNodeDefaultNodes(preferredLanguages: .currentLocale)), models: NodesViewModel(nodesModels: nodes, header: R.string.localizable.selectNodeDefaultNodes(preferredLanguages: .currentLocale), delegate: self)))

        if !customNodes.isEmpty {
            items.append(SectionViewModel(header: NodesHeaderViewModel(title: R.string.localizable.selectNodeCustomNodes(preferredLanguages: .currentLocale)), models: NodesViewModel(nodesModels: customNodes, header: R.string.localizable.selectNodeCustomNodes(preferredLanguages: .currentLocale), delegate: self)))
        }
        return items
    }

    private func updateScreen(with chain: ChainModel) {

        let nodesViewModels = chain.nodes.map({ NodeViewModel(node: $0, isSelected: $0 == chain.selectedNode, isCustom: false) })
        let sortedNodes = nodesViewModels.sorted { $0.node.name < $1.node.name }

        let customNodeViewModels = (chain.customNodes ?? []).map({ NodeViewModel(node: $0, isSelected: $0 == chain.selectedNode, isCustom: true) })
        let sortedCustomNodes = customNodeViewModels.sorted { $0.node.name < $1.node.name }

        let items = createItems(with: sortedNodes, customNodes: sortedCustomNodes)
        DispatchQueue.main.async {
            self.view?.setup(with: items)
        }
    }
}

extension NodesPresenter: ButtonCellDelegate {
    func buttonTapped() {
        onAction(.add)
    }
}

// MARK: - Localizable

extension NodesPresenter: Localizable {

    var locale: Locale {
        return localizationManager?.selectedLocale ?? Locale.current
    }

    var languages: [String] {
        return localizationManager?.preferredLocalizations ?? []
    }
}
