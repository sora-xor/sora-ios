import UIKit

public class MessageViewWireframe: NSObject, MessageViewWireframeProtocol {
    public static var animationDuration: Double = 0.25
    public static var presentationDuration: Double = 2.0

    public static let shared = MessageViewWireframe()

    private override init() {}

    public func show(message: SoraMessageProtocol, on window: UIWindow, animated: Bool) {
        cancelScheduledHidding(on: window)

        defer {
            window.windowLevel = UIWindow.Level.statusBar + 1
        }

        if let messageView = findMessageView(on: window) {
            messageView.layer.removeAllAnimations()
            messageView.set(message: message)
            messageView.frame = calculateVisibleFrame(on: window, for: messageView)
        } else {
            guard let messageView = MessageViewFactory().createMessageView() as? MessageView else {
                return
            }

            messageView.set(message: message)

            let startFrame = calculateHiddenFrame(on: window, for: messageView)
            let finalFrame = calculateVisibleFrame(on: window, for: messageView)

            messageView.frame = startFrame
            window.addSubview(messageView)

            if animated {
                UIView.animate(withDuration: type(of: self).animationDuration) {
                    messageView.frame = finalFrame
                }
            } else {
                messageView.frame = finalFrame
            }
        }

        scheduleHidding(on: window)
    }

    public func hide(on window: UIWindow, animated: Bool) {
        cancelScheduledHidding(on: window)

        defer {
            window.windowLevel = UIWindow.Level.statusBar - 1
        }

        guard let messageView = findMessageView(on: window) else {
            return
        }

        guard animated else {
            messageView.removeFromSuperview()
            return
        }

        UIView.animate(
            withDuration: type(of: self).animationDuration,
            animations: {
                messageView.frame = self.calculateHiddenFrame(on: window, for: messageView)
        },
            completion: { completed in
                if completed {
                    messageView.removeFromSuperview()
                }

        })
    }

    // MARK: Scheduled Hidding

    @objc private func onShowTimeout(window: UIWindow) {
        hide(on: window, animated: true)
    }

    private func scheduleHidding(on window: UIWindow) {
        perform(#selector(onShowTimeout(window:)), with: window, afterDelay: type(of: self).presentationDuration)
    }

    private func cancelScheduledHidding(on window: UIWindow) {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(onShowTimeout(window:)),
                                               object: window)
    }

    // MARK: Message View Layout

    private func findMessageView(on window: UIWindow) -> MessageView? {
        for subview in window.subviews {
            if let messageView = subview as? MessageView {
                return messageView
            }
        }

        return nil
    }

    private func calculateVisibleFrame(on window: UIWindow, for messageView: MessageView) -> CGRect {
        let contentHeight = messageView.intrinsicContentSize.height
        return CGRect(x: 0.0, y: 0.0, width: window.frame.width, height: contentHeight)
    }

    private func calculateHiddenFrame(on window: UIWindow, for messageView: MessageView) -> CGRect {
        let contentHeight = messageView.intrinsicContentSize.height
        return CGRect(x: 0.0, y: -contentHeight, width: window.frame.width, height: contentHeight)
    }
}
