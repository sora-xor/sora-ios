import Foundation
import UIKit
import CoreText

extension FontWeight {
    var uiKitWeight: UIFont.Weight {
        switch self {
        case .regular: return .regular
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

public enum FontFeature: Hashable {
    /// Tabular (monospaced) figures: `tnum` in Sora, monospaced digits in the system font.
    case tabular
}

public struct FontData {
    let fontFamily: FontFamily
    let fontSize: CGFloat
    let fontWeight: FontWeight
    let letterSpacing: CGFloat
    let lineHeight: CGFloat
    let paragraphSpacing: CGFloat
    var features: Set<FontFeature> = []

    /// PostScript name of the bundled face (for example `Sora-Bold`), or nil
    /// when this style uses a system font.
    ///
    /// Before 3.9.0 the name was built from the enum case names
    /// (`"headline-one"`), so the lookup always failed and every style fell
    /// back to the system font. The raw values match the bundled fonts.
    public var postScriptName: String? {
        guard fontFamily.isBundled else { return nil }
        return "\(fontFamily.rawValue)-\(fontWeight.rawValue)"
    }

    public var font: UIFont {
        FontData.cachedFont(for: self)
    }

    /// A copy with tabular figures.
    public var tabular: FontData {
        var copy = self
        copy.features.insert(.tabular)
        return copy
    }

    var paragraph: NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = max(0, lineHeight - fontSize)
        paragraphStyle.paragraphSpacing = self.paragraphSpacing
        return paragraphStyle
    }

    public var attributes: [NSAttributedString.Key: Any] {
        [.paragraphStyle: paragraph,
         .font: font,
         .kern: letterSpacing]
    }

    public func attriburedString(with text: String) -> NSMutableAttributedString {
        NSMutableAttributedString(string: text, attributes: [.font: font,
                                                             .kern: letterSpacing,
                                                             .paragraphStyle: paragraph])
    }

    // MARK: - Font cache

    /// `UIFont` creation is not free and `font` is read on every cell
    /// configuration. `NSCache` is thread-safe.
    private static let cache = NSCache<NSString, UIFont>()

    private static func cachedFont(for data: FontData) -> UIFont {
        let key = "\(data.fontFamily.rawValue)|\(data.fontWeight.rawValue)|\(data.fontSize)|\(data.features.contains(.tabular))" as NSString
        if let font = cache.object(forKey: key) {
            return font
        }
        let font = makeFont(for: data)
        cache.setObject(font, forKey: key)
        return font
    }

    private static func makeFont(for data: FontData) -> UIFont {
        let base: UIFont
        switch data.fontFamily {
        case .mono:
            base = .monospacedSystemFont(ofSize: data.fontSize, weight: data.fontWeight.uiKitWeight)
        case .text, .headline:
            if let name = data.postScriptName, let bundled = UIFont(name: name, size: data.fontSize) {
                base = bundled
            } else {
                base = .systemFont(ofSize: data.fontSize, weight: data.fontWeight.uiKitWeight)
            }
        }
        guard data.features.contains(.tabular) else {
            return base
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]]
        ])
        return UIFont(descriptor: descriptor, size: data.fontSize)
    }
}
