import UIKit
import SoraUI

final class UnsupportedVersionViewController: UIViewController, AdaptiveDesignable {
    var presenter: UnsupportedVersionPresenterProtocol!

    @IBOutlet private var iconTop: NSLayoutConstraint!
    @IBOutlet private var titleTop: NSLayoutConstraint!
    @IBOutlet private var messageTop: NSLayoutConstraint!
    @IBOutlet private var actionTop: NSLayoutConstraint!

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var actionButton: SoraButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()

        presenter.setup()
    }

    private func adjustLayout() {
        iconTop.constant *= designScaleRatio.height
        titleTop.constant *= designScaleRatio.height
        messageTop.constant *= designScaleRatio.height
        actionTop.constant *= designScaleRatio.height
    }

    @IBAction func actionDidSelect() {
        presenter.performAction()
    }
}

extension UnsupportedVersionViewController: UnsupportedVersionViewProtocol {
    func didReceive(viewModel: UnsupportedVersionViewModel) {
        titleLabel.text = viewModel.title
        messageLabel.text = viewModel.message
        iconImageView.image = viewModel.icon
        actionButton.title = viewModel.actionTitle
        actionButton.invalidateLayout()
    }
}
