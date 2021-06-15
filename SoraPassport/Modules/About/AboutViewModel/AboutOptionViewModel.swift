/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol AboutOptionViewModelProtocol {
    static var locale: Locale { get set }

    var option: AboutOption { get }

    var title: String { get }
    var subtitle: String? { get }
    var image: UIImage? { get }
    var address: URL? { get }
}

struct AboutOptionViewModel: AboutOptionViewModelProtocol {
    static var locale: Locale = Locale.current

    var option: AboutOption

    var title: String
    var image: UIImage?
    var address: URL?

    var subtitle: String? {
        switch option {
        case .website, .opensource, .telegram:
            return address?.absoluteString
                .replacingOccurrences(of: "https://", with: "")

        case .writeUs(let email):
            return email

        default:
            return nil
        }
    }

    init(by option: AboutOption) {
        self.option = option

        self.title = option.title(for: Self.locale)
        self.image = option.iconImage()
        self.address = option.address()
    }
}
