import UIKit

public class MessageViewFactory: MessageViewFactoryProtocol {
    public func createMessageView() -> MessageViewProtocol {
        let messageView = MessageView()
        messageView.backgroundColor = R.color.baseBackgroundHover()!

        messageView.contentInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        messageView.horizontalSpacing = 12.0
        messageView.verticalSpacing = 2.0

        messageView.titleColor = UIColor.white
        messageView.titleFont = UIFont.styled(for: .paragraph1)

        messageView.subtitleColor = UIColor.white
        messageView.subtitleFont = UIFont.styled(for: .paragraph2)

        messageView.imageTintColor = UIColor.white

        return messageView
    }
}
