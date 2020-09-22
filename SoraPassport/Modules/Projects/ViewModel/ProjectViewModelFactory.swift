/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraFoundation

enum ProjectOneOfViewModel {
    case open(viewModel: OpenProjectViewModel)
    case finished(viewModel: FinishedProjectViewModel)

    var identifier: String {
        switch self {
        case .open(let viewModel):
            return viewModel.identifier
        case .finished(let viewModel):
            return viewModel.identifier
        }
    }

    var isFavorite: Bool {
        set {
            switch self {
            case .open(let viewModel):
                viewModel.content.isFavorite = newValue
            case .finished(let viewModel):
                viewModel.content.isFavorite = newValue
            }
        }

        get {
            switch self {
            case .open(let viewModel):
                return viewModel.content.isFavorite
            case .finished(let viewModel):
                return viewModel.content.isFavorite
            }
        }
    }

    var itemSize: CGSize {
        switch self {
        case .open(let viewModel):
            return viewModel.layout.itemSize
        case .finished(let viewModel):
            return viewModel.layout.itemSize
        }
    }

    var imageViewModel: ImageViewModelProtocol? {
        switch self {
        case .open(let viewModel):
            return viewModel.imageViewModel
        case .finished(let viewModel):
            return viewModel.imageViewModel
        }
    }
}

protocol ProjectViewModelDelegate: OpenProjectViewModelDelegate & FinishedProjectViewModelDelegate {}

protocol DynamicProjectViewModelFactoryProtocol: class {
    var delegate: ProjectViewModelFactoryDelegate? { get set }
}

protocol ProjectViewModelFactoryDelegate: class {
    func projectFactoryDidChange(_ factory: DynamicProjectViewModelFactoryProtocol)
}

protocol ProjectViewModelFactoryProtocol: DynamicProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: ProjectLayoutMetadata,
                delegate: ProjectViewModelDelegate?,
                locale: Locale) -> ProjectOneOfViewModel

    func create(from projectDetails: ProjectDetailsData,
                delegate: ProjectDetailsViewModelDelegate?,
                locale: Locale) -> ProjectDetailsViewModel
}

final class ProjectViewModelFactory: ProjectViewModelFactoryProtocol {
    private(set) var openProjectViewModelFactory: OpenProjectViewModelFactoryProtocol
    private(set) var finishedProjectViewModelFactory: FinishedProjectViewModelFactoryProtocol

    weak var delegate: ProjectViewModelFactoryDelegate?

    init(openProjectViewModelFactory: OpenProjectViewModelFactoryProtocol,
         finishedProjectViewModelFactory: FinishedProjectViewModelFactoryProtocol) {
        self.openProjectViewModelFactory = openProjectViewModelFactory
        self.finishedProjectViewModelFactory = finishedProjectViewModelFactory

        finishedProjectViewModelFactory.delegate = self
    }

    func create(from project: ProjectData,
                layoutMetadata: ProjectLayoutMetadata,
                delegate: ProjectViewModelDelegate?,
                locale: Locale) -> ProjectOneOfViewModel {
        switch project.status {
        case .open:
            let viewModel = openProjectViewModelFactory
                .create(from: project,
                        layoutMetadata: layoutMetadata.openProjectLayoutMetadata,
                        delegate: delegate,
                        locale: locale)
            return .open(viewModel: viewModel)
        case .closed, .failed:
            let viewModel = finishedProjectViewModelFactory
                .create(from: project,
                        layoutMetadata: layoutMetadata.finishedProjectLayoutMetadata,
                        delegate: delegate,
                        locale: locale)
            return .finished(viewModel: viewModel)
        }
    }

    func create(from projectDetails: ProjectDetailsData,
                delegate: ProjectDetailsViewModelDelegate?,
                locale: Locale) -> ProjectDetailsViewModel {
        switch projectDetails.status {
        case .open:
            return openProjectViewModelFactory.create(from: projectDetails,
                                                      delegate: delegate,
                                                      locale: locale)
        case .closed, .failed:
            return finishedProjectViewModelFactory.create(from: projectDetails,
                                                          delegate: delegate,
                                                          locale: locale)
        }
    }
}

extension ProjectViewModelFactory: ProjectViewModelFactoryDelegate {
    func projectFactoryDidChange(_ factory: DynamicProjectViewModelFactoryProtocol) {
        delegate?.projectFactoryDidChange(self)
    }
}

extension ProjectViewModelFactory {
    static func createDefault() -> ProjectViewModelFactoryProtocol {
        let votesFormatter = NumberFormatter.vote.localizableResource()
        let integerFormatter = NumberFormatter.anyInteger.localizableResource()

        let dateFormatterFactory = FinishedProjectDateFormatterFactory.self
        let dateFormatterProvider = DateFormatterProvider(dateFormatterFactory: dateFormatterFactory,
                                                          dayChangeHandler: DayChangeHandler())

        let open = OpenProjectViewModelFactory(votesFormatter: votesFormatter,
                                               integerFormatter: integerFormatter)
        let finished = FinishedProjectViewModelFactory(votesFormatter: votesFormatter,
                                                       integerFormatter: integerFormatter,
                                                       dateFormatterProvider: dateFormatterProvider)

        return ProjectViewModelFactory(openProjectViewModelFactory: open,
                                       finishedProjectViewModelFactory: finished)
    }
}
