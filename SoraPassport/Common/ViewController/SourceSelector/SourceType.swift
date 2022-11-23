/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol SourceType {
    func titleForLocale(_ locale: Locale) -> String
    var descriptionText: String? { get }
}
