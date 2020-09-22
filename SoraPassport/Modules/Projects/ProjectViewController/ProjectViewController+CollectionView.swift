import UIKit
import SoraUI
import SoraFoundation

extension ProjectsViewController: UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == Constants.headerSectionIndex {
            return 0
        } else {
            guard emptyStateViewModel == nil else {
                return 1
            }

            return presenter.numberOfProjects
        }
    }

    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let emptyStateViewModel = emptyStateViewModel {
            return configureEmptyStateCell(for: collectionView,
                                           indexPath: indexPath,
                                           viewModel: emptyStateViewModel)
        } else {
            let oneOfViewModel = presenter.viewModel(at: indexPath.row)

            switch oneOfViewModel {
            case .project(let viewModel):
                return configureProjectCell(for: collectionView,
                                            indexPath: indexPath,
                                            viewModel: viewModel)
            case .referendum(let viewModel):
                return configureReferendumCell(for: collectionView,
                                               indexPath: indexPath,
                                               viewModel: viewModel)
            }
        }
    }

    private func configureProjectCell(for collectionView: UICollectionView,
                                      indexPath: IndexPath,
                                      viewModel: ProjectOneOfViewModel) -> UICollectionViewCell {
        switch viewModel {
        case .open(let viewModel):
            return configureOpenProjectCell(for: collectionView,
                                            indexPath: indexPath,
                                            viewModel: viewModel)
        case .finished(let viewModel):
            return configureFinishedProjectCell(for: collectionView,
                                                indexPath: indexPath,
                                                viewModel: viewModel)
        }
    }

    private func configureOpenProjectCell(for collectionView: UICollectionView,
                                          indexPath: IndexPath,
                                          viewModel: OpenProjectViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.openProjectCellId,
                                                      for: indexPath)!

        cell.localizationManager = localizationManager
        cell.bind(viewModel: viewModel, layoutMetadata: projectLayoutMetadata.openProjectLayoutMetadata)

        return cell
    }

    private func configureFinishedProjectCell(for collectionView: UICollectionView,
                                              indexPath: IndexPath,
                                              viewModel: FinishedProjectViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.finishedProjectCellId,
                                                      for: indexPath)!

        cell.bind(viewModel: viewModel, layoutMetadata: projectLayoutMetadata.finishedProjectLayoutMetadata)

        return cell
    }

    private func configureReferendumCell(for collectionView: UICollectionView,
                                         indexPath: IndexPath,
                                         viewModel: ReferendumViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.referendumCellId,
                                                      for: indexPath)!

        cell.localizationManager = localizationManager
        cell.bind(viewModel: viewModel, layoutMetadata: referendumLayoutMetadata)

        return cell
    }

    //swiftlint:disable force_cast
    private func configureEmptyStateCell(for collectionView: UICollectionView,
                                         indexPath: IndexPath,
                                         viewModel: EmptyStateListViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyStateListViewModel.cellIdentifier,
                                                      for: indexPath) as! EmptyStateCollectionViewCell

        cell.bind(viewModel: viewModel)

        return cell
    }
    //swiftlint:enable force_cast

    public func collectionView(_ collectionView: UICollectionView,
                               viewForSupplementaryElementOfKind kind: String,
                               at indexPath: IndexPath) -> UICollectionReusableView {
        let projectHeaderView = collectionView
            .dequeueReusableSupplementaryView(ofKind: kind,
                                              withReuseIdentifier: R.reuseIdentifier.projectHeaderId,
                                              for: indexPath)!

        if self.headerView !== projectHeaderView {
            configureHeaderView(projectHeaderView)
        }

        self.headerView?.localizationManager = localizationManager

        return projectHeaderView
    }
}

extension ProjectsViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)

        guard emptyStateViewModel == nil else {
            return
        }

        presenter.activateProject(at: indexPath.row)
    }
}

extension ProjectsViewController: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {

        if emptyStateViewModel == nil {
            let model = presenter.viewModel(at: indexPath.row)

            return model.itemSize
        } else {
            var headerHeight = headerView?.frame.size.height ?? 0.0
            headerHeight = collectionView.frame.size.height - headerHeight
            headerHeight -= 2.0 * Constants.projectCellSpacing
            headerHeight -= UIApplication.shared.statusBarFrame.maxY

            return CGSize(width: collectionView.frame.size.width,
                          height: headerHeight)
        }
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == Constants.headerSectionIndex {
            return CGSize(width: collectionView.frame.size.width, height: Constants.sectionHeight)
        } else {
            return .zero
        }
    }
}
