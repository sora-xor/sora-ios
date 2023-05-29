import Foundation
@testable import SoraPassport

func createRandomLanguageList() -> [Language] {
    return Locale.isoLanguageCodes.map { code in
        return Language(code: code)
    }
}
