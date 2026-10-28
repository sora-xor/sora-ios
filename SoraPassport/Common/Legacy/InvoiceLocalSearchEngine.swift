/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/


import Foundation

public protocol InvoiceLocalSearchEngineProtocol {
    func searchByAccountId(_ accountId: String) -> SearchData?
}
