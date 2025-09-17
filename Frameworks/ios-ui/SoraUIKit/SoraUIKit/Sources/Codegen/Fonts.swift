import Foundation

// #codegen
enum FontWeight: String, CaseIterable {
	case zero = "Regular"
	case one = "Bold"
    case medium = "Medium"
}

enum FontFamily: String, CaseIterable {
	case text = "Inter"
	case headline = "Sora"
    case almarai = "Almarai"
    case sunflower = "Sunflower"
    case tektur = "Tektur"

    var systemName: String {
        switch self {
        case .text: return "Inter"
        case .headline: return "sora-rc004-0417"
        case .almarai: return "Almarai"
        case .sunflower: return "Sunflower"
        case .tektur: return "Tektur"
        }
    }
}

public enum FontType {
    public static let displayM: FontData = FontData(fontFamily: .tektur,
												fontSize: 30,
                                                fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 32,
												paragraphSpacing: 0)

	public static let displayS: FontData = FontData(fontFamily: .tektur,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let displayL: FontData = FontData(fontFamily: .tektur,
												fontSize: 34,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 40,
												paragraphSpacing: 0)

	public static let textBoldM: FontData = FontData(fontFamily: .sunflower,
												fontSize: 16,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let textBoldS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 14,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let textBoldL: FontData = FontData(fontFamily: .sunflower,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let textBoldXS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 12,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 12,
												paragraphSpacing: 0)

	public static let textXS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 12,
                                                fontWeight: .medium,
												letterSpacing: 0.0,
												lineHeight: 12,
												paragraphSpacing: 0)

	public static let textS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 14,
												fontWeight: .medium,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let textM: FontData = FontData(fontFamily: .sunflower,
												fontSize: 16,
                                                 fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let textL: FontData = FontData(fontFamily: .sunflower,
												fontSize: 18,
												fontWeight: .medium,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let headline1: FontData = FontData(fontFamily: .sunflower,
												fontSize: 24,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 32,
												paragraphSpacing: 0)

	public static let headline4: FontData = FontData(fontFamily: .sunflower,
												fontSize: 13,
												fontWeight: .medium,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let headline3: FontData = FontData(fontFamily: .sunflower,
												fontSize: 15,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let headline2: FontData = FontData(fontFamily: .sunflower,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let buttonM: FontData = FontData(fontFamily: .sunflower,
												fontSize: 16,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let paragraphXS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 12,
												fontWeight: .medium,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let paragraphBoldXS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 12,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let paragraphBoldM: FontData = FontData(fontFamily: .sunflower,
												fontSize: 16,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let paragraphBoldS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 14,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let paragraphBoldL: FontData = FontData(fontFamily: .sunflower,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 28,
												paragraphSpacing: 0)

	public static let paragraphS: FontData = FontData(fontFamily: .sunflower,
												fontSize: 14,
												fontWeight: .medium,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let paragraphL: FontData = FontData(fontFamily: .sunflower,
												fontSize: 18,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 28,
												paragraphSpacing: 0)

	public static let paragraphM: FontData = FontData(fontFamily: .sunflower,
												fontSize: 16,
                                                fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

    public static let extra: FontData = FontData(fontFamily: .sunflower,
                                                fontSize: 41,
                                                fontWeight: .medium,
                                                letterSpacing: 0.0,
                                                lineHeight: 41,
                                                paragraphSpacing: 0)
}
