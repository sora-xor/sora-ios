import UIKit
import SoraUI

class SkeletonCollectionViewCell: UICollectionViewCell {

    private(set) var viewModel: SkeletonCellViewModel?
    private(set) var skrullableView: SkrullableView?

    func present(for viewModel: SkeletonCellViewModel) {
        if viewModel != self.viewModel {
            self.viewModel = viewModel

            self.skrullableView?.removeFromSuperview()
            self.skrullableView = nil

            if let skrullableView = configureSkeleton(for: viewModel) {
                skrullableView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(skrullableView)

                skrullableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
                skrullableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
                skrullableView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
                skrullableView.heightAnchor.constraint(equalToConstant: viewModel.contentSize.height).isActive = true

                skrullableView.startSkrulling()

                self.skrullableView = skrullableView
            }
        }
    }

    func configureSkeleton(for viewModel: SkeletonCellViewModel) -> SkrullableView? {
        return nil
    }
}
