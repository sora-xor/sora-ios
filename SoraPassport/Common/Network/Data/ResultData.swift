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
