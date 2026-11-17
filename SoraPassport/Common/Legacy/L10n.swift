/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation


//swiftlint:disable all
public enum L10n {

    static var sharedLanguage: WalletLanguage = WalletLanguage.defaultLanguage

    // Only the entries the transfer and QR-scanning code still reads. The
    // other 90 generated entries of the old CommonWallet table had no reader
    // and were removed on 2026-11-18.

    public enum Amount {
        public enum Error {
            /// Sorry, we couldn't find asset information you want to send. Please, try again later.
            public static var asset: String { return localize("amount.error.asset") }
            /// Sorry, balance checking request failed. Please, try again later.
            public static var balance: String { return localize("amount.error.balance") }
            /// Sorry, we couldn't contact transfer provider. Please, try again later.
            public static var transfer: String { return localize("amount.error.transfer") }
        }
    }

    public enum InvoiceScan {
        public enum Error {
            /// Unfortunately, you denied access to camera previously. Would you like to allow access now?
            public static var cameraRestrictedPreviously: String { return localize("invoice_scan.error.camera_restricted_previously") }
            /// Camera Access
            public static var cameraTitle: String { return localize("invoice_scan.error.camera_title") }
            /// Can't extract receiver's data
            public static var extractFail: String { return localize("invoice_scan.error.extract_fail") }
            /// Unfortunately, you denied access to photos previously. Would you like to allow access now?
            public static var galleryRestrictedPreviously: String { return localize("invoice_scan.error.gallery_restricted_previously") }
            /// Photos Access
            public static var galleryTitle: String { return localize("invoice_scan.error.gallery_title") }
            /// You can't send to yourself
            public static var match: String { return localize("invoice_scan.error.match") }
            /// Please, check internet connection
            public static var noInternet: String { return localize("invoice_scan.error.no_internet") }
            /// Can't find a user from QR
            public static var userNotFound: String { return localize("invoice_scan.error.user_not_found") }
        }
    }
}

extension L10n {

    // These legacy keys are still used by transfer and QR scanning, but are
    // absent from the shipped English Localizable.strings catalog.
    private static let activeEnglishFallbacks: [String: String] = [
        "amount.error.asset": "Sorry, we couldn't find asset information you want to send. Please, try again later.",
        "amount.error.balance": "Sorry, balance checking request failed. Please, try again later.",
        "amount.error.transfer": "Sorry, we couldn't contact transfer provider. Please, try again later.",
        "invoice_scan.error.camera_restricted_previously": "Unfortunately, you denied access to camera previously. Would you like to allow access now?",
        "invoice_scan.error.camera_title": "Camera Access",
        "invoice_scan.error.extract_fail": "Can't extract receiver's data",
        "invoice_scan.error.gallery_restricted_previously": "Unfortunately, you denied access to photos previously. Would you like to allow access now?",
        "invoice_scan.error.gallery_title": "Photos Access",
        "invoice_scan.error.match": "You can't send to yourself",
        "invoice_scan.error.no_internet": "Please, check internet connection",
        "invoice_scan.error.user_not_found": "Can't find a user from QR"
    ]

    fileprivate static func localize(_ key: String, _ args: CVarArg...) -> String {
        let format = getFormat(for: key, localization: sharedLanguage.rawValue,
                               bundle: Bundle(for: BundleLoadHelper.self))
        return String(format: format, arguments: args)
    }

    static func getFormat(for key: String, localization: String, bundle: Bundle) -> String {
        var checked = Set<String>()
        let languages = [localization, Locale(identifier: localization).languageCode, "en"]
            .compactMap { $0 }
        let missingValue = UUID().uuidString

        for language in languages {
            guard checked.insert(language).inserted,
                  let langBundle = R.languageBundle(language, in: bundle) else {
                continue
            }

            let value = langBundle.localizedString(forKey: key,
                                                    value: missingValue,
                                                    table: "Localizable")
            if value != missingValue && !value.isEmpty {
                return value
            }
        }

        return activeEnglishFallbacks[key] ?? ""
    }

}


private final class BundleLoadHelper {}
//swiftlint:enable all
