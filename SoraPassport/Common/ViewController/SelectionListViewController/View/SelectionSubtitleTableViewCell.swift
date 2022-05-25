import UIKit

@IBDesignable
final class SelectionSubtitleTableViewCell: UITableViewCell, SelectionItemViewProtocol {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var checkmarkImageView: UIImageView!

    @IBInspectable
    var checkmarkIcon: UIImage? {
        didSet {
            updateSelectionState()
        }
    }

    private(set) var viewModel: SelectableSubtitleListViewModel?

    override func prepareForReuse() {
        viewModel?.removeObserver(self)
    }

    func bind(viewModel: SelectableViewModelProtocol) {
        if let subtitleViewModel = viewModel as? SelectableSubtitleListViewModel {
            self.viewModel = subtitleViewModel

            titleLabel.text = subtitleViewModel.title
            subtitleLabel.text = subtitleViewModel.subtitle
            updateSelectionState()

            titleLabel.font = UIFont.styled(for: .paragraph2, isBold: true)
            subtitleLabel.font = UIFont.styled(for: .paragraph3)
            
            titleLabel.textColor = R.color.neumorphism.textDark()!
            subtitleLabel.textColor = R.color.neumorphism.textDark()!

            viewModel.addObserver(self)
        }
    }

    private func updateSelectionState() {
        guard let viewModel = viewModel else {
            return
        }

        if checkmarkImageView != nil {
            checkmarkImageView.image = viewModel.isSelected ? checkmarkIcon : nil
        }
    }
}

extension SelectionSubtitleTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
