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
import SSFUtils

struct EventRecord: Decodable {
    enum CodingKeys: String, CodingKey {
        case phase
        case event
    }

    let phase: Phase
    let event: Event

    init(from decoder: Decoder) throws {
        var container = try decoder.container(keyedBy: CodingKeys.self)

        phase = try container.decode(Phase.self, forKey: .phase)
        event = try container.decode(Event.self, forKey: .event)
    }
}

extension EventRecord {
    var extrinsicIndex: UInt32? {
        if case let .applyExtrinsic(index) = phase {
            return index
        } else {
            return nil
        }
    }
}

enum Phase: Decodable {
    static let extrinsicField = "ApplyExtrinsic"
    static let finalizationField = "Finalization"
    static let initializationField = "Initialization"

    case applyExtrinsic(index: UInt32)
    case finalization
    case initialization

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Phase.extrinsicField:
            let index = try container.decode(StringScaleMapper<UInt32>.self).value
            self = .applyExtrinsic(index: index)
        case Phase.finalizationField:
            self = .finalization
        case Phase.initializationField:
            self = .initialization
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected phase"
            )
        }
    }
}

struct EventWrapper: Decodable {}

struct Event: Decodable {
    let section: String
    let method: String
    let data: JSON

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        section = try unkeyedContainer.decode(String.self)
        var arrayContainer = try unkeyedContainer.nestedUnkeyedContainer()
        method = try arrayContainer.decode(String.self)
        data = try arrayContainer.decode(JSON.self)
    }
}

private extension Optional {
    func unwrap(throwing error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}

enum ExtrinsicStatus: Decodable {
    static let readyField = "ready"
    static let broadcastField = "broadcast"
    static let inBlockField = "inBlock"
    static let finalizedField = "finalized"

    case ready
    case broadcast([String])
    case inBlock(String)
    case finalized(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try container.decode(JSON.self)

        let decodingError = DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unexpected extrinsic state"
        )

        let type = try (decoded.dictValue?.keys.first ?? decoded.stringValue).unwrap(throwing: decodingError)
        if type == ExtrinsicStatus.readyField {
            self = .ready
            return
        }
        let value = try decoded[type].unwrap(throwing: decodingError)

        switch type {
        case ExtrinsicStatus.broadcastField:
            self = .broadcast(
                try value.arrayValue
                    .unwrap(throwing: decodingError)
                    .map { try $0.stringValue.unwrap(throwing: decodingError) }
            )
        case ExtrinsicStatus.inBlockField:
            self = .inBlock(try value.stringValue.unwrap(throwing: decodingError))
        case ExtrinsicStatus.finalizedField:
            self = .finalized(try value.stringValue.unwrap(throwing: decodingError))
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extrinsic state"
            )
        }
    }
}
