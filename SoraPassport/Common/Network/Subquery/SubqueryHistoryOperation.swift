// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import RobinHood
import SSFUtils
import sorawallet

enum SubqueryHistoryOperationError: Swift.Error {
    case invalidRequest
    case invalidResponse
}

public final class SubqueryHistoryOperation<ResultType>: BaseOperation<ResultType> {

    private let baseUrl: URL
    private let address: String
    private let count: Int
    private let page: Int
    private var filter: ((TxHistoryItem) -> KotlinBoolean)? = nil

    public init(
        address: String,
        count: Int,
        page: Int,
        filter: ((TxHistoryItem) -> KotlinBoolean)? = nil,
        baseUrl: URL? = nil
    ) {
        self.baseUrl = baseUrl ?? ConfigService.shared.config.subqueryURL
        self.filter = filter
        self.address = address
        self.count = count
        self.page = page

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard (1...100).contains(count),
                  (1...100).contains(page),
                  (1...128).contains(address.utf8.count),
                  address.range(
                    of: #"^[1-9A-HJ-NP-Za-km-z]+$"#,
                    options: .regularExpression
                  ) != nil else {
                throw SubqueryHistoryOperationError.invalidRequest
            }

            let offset = (page - 1) * count
            let query = """
            query WalletHistory {
              historyElements(
                first: \(count)
                offset: \(offset)
                orderBy: TIMESTAMP_DESC
                filter: { address: { equalTo: "\(address)" } }
              ) {
                nodes {
                  id
                  blockHash
                  module
                  method
                  address
                  networkFee
                  execution
                  timestamp
                  data
                }
                pageInfo { endCursor hasNextPage }
              }
            }
            """

            let payload: SubqueryHistoryData = try SoraIndexerClient.execute(
                url: baseUrl,
                query: query
            )
            guard payload.historyElements.nodes.allSatisfy({ $0.address == address }),
                  Set(payload.historyElements.nodes.map(\.identifier)).count ==
                    payload.historyElements.nodes.count else {
                throw SubqueryHistoryOperationError.invalidResponse
            }
            Logger.shared.info(
                "SORA history request succeeded: \(baseUrl.host ?? "unknown host")"
            )

            var items = payload.historyElements.nodes.map {
                SoraIndexerHistoryMapper.map($0, address: address)
            }
            if let filter {
                items = items.filter { filter($0).boolValue }
            }

            let historyResult = TxHistoryResult<TxHistoryItem>(
                endCursor: payload.historyElements.pageInfo.endCursor,
                endReached: !payload.historyElements.pageInfo.hasNextPage,
                page: Int64(page),
                items: items,
                errorMessage: nil
            )
            guard let typedResult = historyResult as? ResultType else {
                throw SoraIndexerClientError.resultTypeMismatch
            }
            result = .success(typedResult)
        } catch {
            result = .failure(error)
        }
    }
}

enum SoraIndexerHistoryMapper {
    static func map(_ element: SubqueryHistoryElement, address: String) -> TxHistoryItem {
        TxHistoryItem(
            id: element.identifier,
            blockHash: element.blockHash,
            module: element.module,
            method: element.method,
            timestamp: String(element.timestamp.value),
            networkFee: element.fee,
            success: element.execution.success,
            data: dataParameters(from: element, address: address),
            nestedData: nestedItems(from: element.data)
        )
    }

    private static func dataParameters(
        from element: SubqueryHistoryElement,
        address: String
    ) -> [TxHistoryItemParam]? {
        guard let values = element.data.dictValue else {
            return nil
        }

        if element.module.caseInsensitiveCompare("liquidityProxy") == .orderedSame,
           element.method.caseInsensitiveCompare("swapTransferBatch") == .orderedSame {
            var selected: [String: JSON] = [:]
            values.forEach { key, value in
                switch key.lowercased() {
                case "adarfee", "actualfee":
                    selected[key] = value
                case "transfers":
                    value.arrayValue?.compactMap(\.dictValue).forEach { transfer in
                        guard transfer.values.contains(where: { primitiveString($0) == address }) else {
                            return
                        }
                        selected.merge(transfer) { _, new in new }
                    }
                default:
                    break
                }
            }
            return parameters(from: selected)
        }

        return parameters(from: values)
    }

    private static func nestedItems(from data: JSON) -> [TxHistoryItemNested]? {
        guard let values = data.arrayValue else {
            return nil
        }

        return values.compactMap { value in
            guard let item = value.dictValue else {
                return nil
            }
            let arguments = item["data"]?.dictValue?["args"]?.dictValue ?? [:]
            return TxHistoryItemNested(
                module: primitiveString(item["module"] ?? .null) ?? "",
                method: primitiveString(item["method"] ?? .null) ?? "",
                hash: primitiveString(item["hash"] ?? .null) ?? "",
                data: parameters(from: arguments)
            )
        }
    }

    private static func parameters(from values: [String: JSON]) -> [TxHistoryItemParam] {
        values.map {
            TxHistoryItemParam(
                paramName: $0.key,
                paramValue: primitiveString($0.value) ?? ""
            )
        }
    }

    private static func primitiveString(_ value: JSON) -> String? {
        switch value {
        case let .stringValue(value):
            return value
        case let .unsignedIntValue(value):
            return String(value)
        case let .signedIntValue(value):
            return String(value)
        case let .boolValue(value):
            return String(value)
        case let .doubleValue(value):
            return String(value)
        case .null:
            return "null"
        case .arrayValue, .dictionaryValue:
            return nil
        }
    }
}
