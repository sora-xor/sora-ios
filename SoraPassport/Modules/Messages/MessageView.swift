import UIKit

public class MessageView: UIView {
    public var contentInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0) {
        didSet {
            invalidateLayout()
        }
    }

    public var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            invalidateLayout()
        }
    }

    public var verticalSpacing: CGFloat = 8.0 {
        didSet {
            invalidateLayout()
        }
    }

    public var titleColor: UIColor = UIColor.white {
        didSet {
            titleLabel?.textColor = titleColor
        }
    }

    public var titleFont: UIFont = UIFont.systemFont(ofSize: UIFont.labelFontSize) {
        didSet {
            titleLabel?.font = titleFont
        }
    }

    public var subtitleColor: UIColor = UIColor.white {
        didSet {
            subtitleLabel?.textColor = titleColor
        }
    }

    public var subtitleFont: UIFont = UIFont.systemFont(ofSize: UIFont.labelFontSize) {
        didSet {
            subtitleLabel?.font = titleFont
        }
    }

    public var imageTintColor: UIColor = UIColor.white {
        didSet {
            imageView?.tintColor = imageTintColor
        }
    }

    private var titleLabel: UILabel?
    private var subtitleLabel: UILabel?
    private var imageView: UIImageView?

    private func configureTitleLabelIfNeeded() {
        guard titleLabel == nil else {
            return
        }

        let label = UILabel()
        label.textColor = titleColor
        label.font = titleFont
        addSubview(label)
        titleLabel = label
    }

    private func dropTitleLabelIfNeeded() {
        titleLabel?.removeFromSuperview()
        titleLabel = nil
    }

    private func configureSubtitleLabelIfNeeded() {
        guard subtitleLabel == nil else {
            return
        }

        let label = UILabel()
        label.textColor = subtitleColor
        label.font = subtitleFont
        addSubview(label)
        subtitleLabel = label
    }

    private func dropSubtitleLabelIfNeeded() {
        subtitleLabel?.removeFromSuperview()
        subtitleLabel = nil
    }

    private func configureImageViewIfNeeded() {
        guard imageView == nil else {
            return
        }

        let iconView = UIImageView()
        iconView.tintColor = imageTintColor
        addSubview(iconView)
        imageView = iconView
    }

    private func dropImageViewIfNeeded() {
        imageView?.removeFromSuperview()
        imageView = nil
    }

    // MARK: Layout

    public func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override public var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = contentIntrinsicHeight
        size.height += contentInsets.top + contentInsets.bottom

        return size
    }

    private var contentIntrinsicHeight: CGFloat {
        return max(labelsIntrinsicContentHeight, imageIntrisicContentHeight)
    }

    private var labelsIntrinsicContentHeight: CGFloat {
        var labelsHeight: CGFloat = 0.0

        if let titleHeight = titleLabel?.intrinsicContentSize.height {
            labelsHeight += titleHeight
        }

        if let subtitleHeight = subtitleLabel?.intrinsicContentSize.height {
            labelsHeight += subtitleHeight
        }

        if titleLabel != nil, subtitleLabel != nil {
            labelsHeight += verticalSpacing
        }

        return labelsHeight
    }

    private var imageIntrisicContentHeight: CGFloat {
        return imageView?.intrinsicContentSize.height ?? 0.0
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        var leading = contentInsets.left
        let contentHeight = contentIntrinsicHeight

        if let imageView = imageView {
            let imageSize = imageView.intrinsicContentSize
            let originY = contentInsets.top + contentHeight / 2.0 - imageSize.height / 2.0
            imageView.frame = CGRect(origin: CGPoint(x: leading, y: originY), size: imageSize)
            leading += imageSize.width + horizontalSpacing
        }

        var top = contentInsets.top + contentHeight / 2.0 - labelsIntrinsicContentHeight / 2.0
        let maxWidth = bounds.size.width - leading - contentInsets.right

        if let titleLabel = titleLabel {
            var titleSize = titleLabel.intrinsicContentSize
            titleSize.width = maxWidth
            titleLabel.frame = CGRect(origin: CGPoint(x: leading, y: top), size: titleSize)
            top += titleSize.height + verticalSpacing
        }

        if let subtitleLabel = subtitleLabel {
            var subtitleSize = subtitleLabel.intrinsicContentSize
            subtitleSize.width = maxWidth
            subtitleLabel.frame = CGRect(origin: CGPoint(x: leading, y: top), size: subtitleSize)
        }
    }
}

extension MessageView: MessageViewProtocol {
    public func set(message: SoraMessageProtocol) {
        if let title = message.title {
            configureTitleLabelIfNeeded()
            titleLabel?.text = title
        } else {
            dropTitleLabelIfNeeded()
        }

        if let subtitle = message.subtitle {
            configureSubtitleLabelIfNeeded()
            subtitleLabel?.text = subtitle
        } else {
            dropSubtitleLabelIfNeeded()
        }

        if let icon = message.image {
            configureImageViewIfNeeded()
            imageView?.image = icon
        } else {
            dropImageViewIfNeeded()
        }

        invalidateIntrinsicContentSize()
        layoutIfNeeded()
    }
}
