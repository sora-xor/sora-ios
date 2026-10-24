import Foundation

// SORA Neon type scale (design spec §5.3). Hand-maintained: the old Figma
// token generator was removed in 3.9.0 because it could not express the
// SemiBold weight, tabular figures or the monospaced family.

enum FontWeight: String, CaseIterable {
    case regular = "Regular"
    case semibold = "SemiBold"
    case bold = "Bold"
}

enum FontFamily: String, CaseIterable {
    /// Body text. Inter 4.1 is bundled with the app under the SIL OFL 1.1.
    case text = "Inter"
    /// Display, headlines, buttons, hero numerals, PIN digits. Bundled
    /// (`Sora-*.otf`, registered through `UIAppFonts`).
    case headline = "Sora"
    /// Addresses, hashes, raw seed, codes: the platform monospace.
    case mono = "SystemMono"

    var isBundled: Bool { self != .mono }
}

public enum FontType {
    // MARK: Display
    public static let displayHero = FontData(fontFamily: .headline, fontSize: 40, fontWeight: .semibold,
                                             letterSpacing: -0.5, lineHeight: 48, paragraphSpacing: 0,
                                             features: [.tabular])
    public static let displayL = FontData(fontFamily: .headline, fontSize: 34, fontWeight: .bold,
                                          letterSpacing: -0.4, lineHeight: 40, paragraphSpacing: 0)
    public static let displayM = FontData(fontFamily: .headline, fontSize: 24, fontWeight: .bold,
                                          letterSpacing: -0.2, lineHeight: 32, paragraphSpacing: 0)
    public static let displayS = FontData(fontFamily: .headline, fontSize: 18, fontWeight: .semibold,
                                          letterSpacing: 0, lineHeight: 24, paragraphSpacing: 0)

    // MARK: Headline
    public static let headline1 = FontData(fontFamily: .headline, fontSize: 24, fontWeight: .bold,
                                           letterSpacing: -0.2, lineHeight: 32, paragraphSpacing: 0)
    public static let headline2 = FontData(fontFamily: .headline, fontSize: 18, fontWeight: .semibold,
                                           letterSpacing: 0, lineHeight: 24, paragraphSpacing: 0)
    public static let headline3 = FontData(fontFamily: .headline, fontSize: 15, fontWeight: .semibold,
                                           letterSpacing: 0, lineHeight: 20, paragraphSpacing: 0)
    public static let headline4 = FontData(fontFamily: .headline, fontSize: 13, fontWeight: .semibold,
                                           letterSpacing: 0.1, lineHeight: 18, paragraphSpacing: 0)
    /// "TOTAL BALANCE", "SECURITY". Uppercase at the call site (locale-aware).
    public static let eyebrow = FontData(fontFamily: .headline, fontSize: 11, fontWeight: .semibold,
                                         letterSpacing: 1.2, lineHeight: 14, paragraphSpacing: 0)

    // MARK: Button
    public static let buttonM = FontData(fontFamily: .headline, fontSize: 16, fontWeight: .semibold,
                                         letterSpacing: 0.2, lineHeight: 20, paragraphSpacing: 0)

    // MARK: Text
    public static let textL = FontData(fontFamily: .text, fontSize: 18, fontWeight: .regular,
                                       letterSpacing: 0, lineHeight: 24, paragraphSpacing: 0)
    public static let textBoldL = FontData(fontFamily: .text, fontSize: 18, fontWeight: .semibold,
                                           letterSpacing: 0, lineHeight: 24, paragraphSpacing: 0)
    public static let textM = FontData(fontFamily: .text, fontSize: 16, fontWeight: .regular,
                                       letterSpacing: 0, lineHeight: 22, paragraphSpacing: 0)
    public static let textBoldM = FontData(fontFamily: .text, fontSize: 16, fontWeight: .semibold,
                                           letterSpacing: 0, lineHeight: 22, paragraphSpacing: 0)
    public static let textS = FontData(fontFamily: .text, fontSize: 14, fontWeight: .regular,
                                       letterSpacing: 0, lineHeight: 18, paragraphSpacing: 0)
    public static let textBoldS = FontData(fontFamily: .text, fontSize: 14, fontWeight: .semibold,
                                           letterSpacing: 0, lineHeight: 18, paragraphSpacing: 0)
    public static let textXS = FontData(fontFamily: .text, fontSize: 12, fontWeight: .regular,
                                        letterSpacing: 0.1, lineHeight: 16, paragraphSpacing: 0)
    public static let textBoldXS = FontData(fontFamily: .text, fontSize: 12, fontWeight: .semibold,
                                            letterSpacing: 0.1, lineHeight: 16, paragraphSpacing: 0)

    // MARK: Paragraph
    public static let paragraphL = FontData(fontFamily: .text, fontSize: 18, fontWeight: .regular,
                                            letterSpacing: 0, lineHeight: 28, paragraphSpacing: 0)
    public static let paragraphM = FontData(fontFamily: .text, fontSize: 16, fontWeight: .regular,
                                            letterSpacing: 0, lineHeight: 24, paragraphSpacing: 0)
    public static let paragraphS = FontData(fontFamily: .text, fontSize: 14, fontWeight: .regular,
                                            letterSpacing: 0, lineHeight: 20, paragraphSpacing: 0)
    public static let paragraphXS = FontData(fontFamily: .text, fontSize: 12, fontWeight: .regular,
                                             letterSpacing: 0, lineHeight: 16, paragraphSpacing: 0)
    public static let paragraphBoldL = FontData(fontFamily: .text, fontSize: 18, fontWeight: .semibold,
                                                letterSpacing: 0, lineHeight: 28, paragraphSpacing: 0)
    public static let paragraphBoldM = FontData(fontFamily: .text, fontSize: 16, fontWeight: .semibold,
                                                letterSpacing: 0, lineHeight: 24, paragraphSpacing: 0)
    public static let paragraphBoldS = FontData(fontFamily: .text, fontSize: 14, fontWeight: .semibold,
                                                letterSpacing: 0, lineHeight: 20, paragraphSpacing: 0)
    public static let paragraphBoldXS = FontData(fontFamily: .text, fontSize: 12, fontWeight: .semibold,
                                                 letterSpacing: 0, lineHeight: 16, paragraphSpacing: 0)

    // MARK: Numbers, addresses, secrets
    /// Asset and transaction amounts (tabular figures).
    public static let amountM = FontData(fontFamily: .text, fontSize: 16, fontWeight: .semibold,
                                         letterSpacing: 0, lineHeight: 22, paragraphSpacing: 0,
                                         features: [.tabular])
    /// Fiat values, rates, fees (tabular figures).
    public static let amountS = FontData(fontFamily: .text, fontSize: 14, fontWeight: .regular,
                                         letterSpacing: 0, lineHeight: 18, paragraphSpacing: 0,
                                         features: [.tabular])
    /// Addresses, hashes, raw seed, recovery codes.
    public static let mono = FontData(fontFamily: .mono, fontSize: 13, fontWeight: .regular,
                                      letterSpacing: 0, lineHeight: 20, paragraphSpacing: 0)
    /// Recovery words.
    public static let phraseWord = FontData(fontFamily: .text, fontSize: 16, fontWeight: .semibold,
                                            letterSpacing: 0, lineHeight: 22, paragraphSpacing: 0)
    /// PIN keypad digits.
    public static let pinDigit = FontData(fontFamily: .headline, fontSize: 28, fontWeight: .regular,
                                          letterSpacing: 0, lineHeight: 32, paragraphSpacing: 0,
                                          features: [.tabular])
}
