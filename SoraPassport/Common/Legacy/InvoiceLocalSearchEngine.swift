/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

public protocol InvoiceLocalSearchEngineProtocol {
    func searchByAccountId(_ accountId: String) -> SearchData?
}
