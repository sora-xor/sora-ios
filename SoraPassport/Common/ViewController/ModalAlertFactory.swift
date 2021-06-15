import UIKit
import SoraUI

struct ModalAlertFactory {
    static func createSuccessAlert(_ title: String) -> UIViewController {
        let contentView = ImageWithTitleView()
        contentView.iconImage = R.image.success()
        contentView.title = title
        contentView.spacingBetweenLabelAndIcon = 8.0
        contentView.layoutType = .verticalImageFirst
        contentView.titleColor = R.color.baseContentTertiary()
        contentView.titleFont = UIFont.styled(for: .paragraph3)

        let contentWidth = contentView.intrinsicContentSize.width + 24.0

        let controller = UIViewController()
        controller.view = contentView

        let preferredSize = CGSize(
            width: max(160.0, contentWidth),
            height: 87.0
        )

        let style = ModalAlertPresentationStyle(
            backgroundColor: R.color.utilityNotification()!,
            backdropColor: .clear,
            cornerRadius: 8.0
        )

        let configuration = ModalAlertPresentationConfiguration(
            style: style,
            preferredSize: preferredSize,
            dismissAfterDelay: 1.5,
            completionFeedback: .success
        )

        controller.modalTransitioningFactory = ModalAlertPresentationFactory(configuration: configuration)
        controller.modalPresentationStyle = .custom

        return controller
    }

}
