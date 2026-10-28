// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SoraDocuments

enum ResultDataError: Error {
    case missingStatusField
    case unexpectedNumberOfFields
}

struct StatusData: Decodable {
    var code: String
    var message: String

    var isSuccess: Bool {
        return code == "OK"
    }
}

struct StatusResultData: Decodable {
    var status: StatusData
}

struct ResultData<ResultType> where ResultType: Decodable {
    var status: StatusData
    var result: ResultType?
}

extension ResultData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        guard container.allKeys.count > 0, container.allKeys.count < 3 else {
            throw ResultDataError.unexpectedNumberOfFields
        }

        guard let statusKey = DocumentDynamicCodingKey(stringValue: CodingKeys.status.rawValue) else {
            throw ResultDataError.missingStatusField
        }

        status = try container.decode(StatusData.self, forKey: statusKey)

        if let resultKey = container.allKeys.first(where: { $0.stringValue != CodingKeys.status.stringValue }) {
            result = try container.decode(ResultType.self, forKey: resultKey)
        }
    }
}

struct MultifieldResultData<ResultType> where ResultType: Decodable {
    var status: StatusData
    var result: ResultType
}

extension MultifieldResultData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        guard let statusKey = DocumentDynamicCodingKey(stringValue: CodingKeys.status.rawValue) else {
            throw ResultDataError.missingStatusField
        }

        status = try container.decode(StatusData.self, forKey: statusKey)

        result = try ResultType(from: decoder)
    }
}

struct OptionalMultifieldResultData<ResultType> where ResultType: Decodable {
    var status: StatusData
    var result: ResultType?
}

extension OptionalMultifieldResultData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        guard let statusKey = DocumentDynamicCodingKey(stringValue: CodingKeys.status.rawValue) else {
            throw ResultDataError.missingStatusField
        }

        status = try container.decode(StatusData.self, forKey: statusKey)

        if status.isSuccess {
            result = try ResultType(from: decoder)
        } else {
            result = nil
        }
    }
}
