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

    /// PostScript name of the bundled face this style was designed in (for
    /// example `Sora-Bold`), or nil for the monospaced family.
    ///
    /// Up to 3.8.6 the name was built from the enum case names
    /// (`"headline-one"`), so the lookup always failed and every style drew
    /// in the system font. The classic design keeps that look: `font` is the
    /// system font whatever this name is.
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
        let primary: UIFont
        switch data.fontFamily {
        case .mono:
            primary = .monospacedSystemFont(ofSize: data.fontSize, weight: data.fontWeight.uiKitWeight)
        case .text, .headline:
            // The classic SORA design: up to 3.8.6 every style drew in the
            // system font (see `postScriptName`), so it still does.
            primary = .systemFont(ofSize: data.fontSize, weight: data.fontWeight.uiKitWeight)
        }
        let base = withEgyptianHieroglyphFallback(primary)
        guard data.features.contains(.tabular) else {
            return base
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]]
        ])
        return UIFont(descriptor: descriptor, size: data.fontSize)
    }

    /// The Nexus line still ships Middle Egyptian (egy-Egyp): neither Sora,
    /// Inter nor the system font draws hieroglyphs, so the app's bundled Noto
    /// Sans Egyptian Hieroglyphs face is the fallback for those characters
    /// only. The primary face, and so `fontName`, is unchanged.
    private static func withEgyptianHieroglyphFallback(_ font: UIFont) -> UIFont {
        let egyptian = UIFontDescriptor(name: "NotoSansEgyptianHieroglyphs-Regular", size: font.pointSize)
        let cascade = UIFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String)
        let descriptor = font.fontDescriptor.addingAttributes([cascade: [egyptian]])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
