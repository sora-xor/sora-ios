import UIKit
final class PolkamarktLineChartView: UIView {
    private let captionLabel = WalletUX.label(style: .headline)
    private let contextLabel = WalletUX.label(style: .footnote)
    private var plotBounds = CGRect.zero

    var caption = "" {
        didSet {
            captionLabel.text = caption
            updateDescription()
        }
    }

    var context = "" {
        didSet {
            contextLabel.text = context
            updateDescription()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = WalletUX.page
        contextLabel.textColor = WalletUX.secondary
        addSubview(captionLabel)
        addSubview(contextLabel)
        isAccessibilityElement = true
        accessibilityTraits = .image
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func updateDescription() {
        accessibilityLabel = [caption, context].filter { !$0.isEmpty }.joined(separator: ". ")
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = max(1, size.width - 48)
        let limit = CGSize(width: width, height: .greatestFiniteMagnitude)
        return CGSize(width: size.width, height: 48 + captionLabel.sizeThatFits(limit).height +
                      contextLabel.sizeThatFits(limit).height + (values.count > 1 ? 150 : 0))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let limit = CGSize(width: max(1, bounds.width - 48), height: .greatestFiniteMagnitude)
        captionLabel.frame = CGRect(origin: CGPoint(x: 24, y: 16), size: captionLabel.sizeThatFits(limit))
        contextLabel.frame = CGRect(origin: CGPoint(x: 24, y: captionLabel.frame.maxY + 8), size: contextLabel.sizeThatFits(limit))
        plotBounds = CGRect(x: 24, y: contextLabel.frame.maxY + 16, width: limit.width, height: 126)
        setNeedsDisplay()
    }

    var values: [Double] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var secondaryValues: [Double] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var markerFraction: Double? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard values.count > 1, let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let bounds = plotBounds
        stroke(
            values,
            color: WalletUX.accent,
            lineWidth: 3,
            in: bounds,
            context: context
        )
        if secondaryValues.count > 1 {
            context.saveGState()
            context.setLineDash(phase: 0, lengths: [6, 4])
            stroke(
                secondaryValues,
                color: WalletUX.foreground,
                lineWidth: 2,
                in: bounds,
                context: context
            )
            context.restoreGState()
        }
        if let markerFraction {
            let normalized = min(max(markerFraction, 0.01), 0.99)
            let markerX = bounds.minX +
                CGFloat((normalized - 0.01) / 0.98) * bounds.width
            context.saveGState()
            context.setStrokeColor(WalletUX.secondary.cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.move(to: CGPoint(x: markerX, y: bounds.minY))
            context.addLine(to: CGPoint(x: markerX, y: bounds.maxY))
            context.strokePath()
            context.restoreGState()
        }
    }

    private func stroke(
        _ values: [Double],
        color: UIColor,
        lineWidth: CGFloat,
        in bounds: CGRect,
        context: CGContext
    ) {
        context.beginPath()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        let denominator = CGFloat(max(values.count - 1, 1))
        for (index, rawValue) in values.enumerated() {
            let value = min(max(rawValue, 0), 1)
            let point = CGPoint(
                x: bounds.minX + CGFloat(index) / denominator * bounds.width,
                y: bounds.maxY - CGFloat(value) * bounds.height
            )
            if index == 0 {
                context.move(to: point)
            } else {
                context.addLine(to: point)
            }
        }
        context.strokePath()
    }
}
