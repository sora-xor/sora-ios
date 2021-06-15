/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils

struct EventRecord: Decodable {
    let phase: Phase
    let event: Event

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        phase = try container.decode(Phase.self)
        event = try container.decode(Event.self)
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
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unexpected phase")
        }
    }
}

struct Event: Decodable {
    struct DispatchInfo: Decodable {
        let paysFee: Int
        let `class`: String
        let weight: UInt64
    }
    struct DispatchError: Decodable {
        let error: Int
//        let module: UInt64
        let index: Int

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let array = try container.decode([JSON].self)
            guard let value = array.first(where: { $0.dictValue != nil }), let dict = value.dictValue else { //because there's String "Module" in there
                throw DecodingError.typeMismatch(EventInfo.self, DecodingError.Context.init(codingPath: decoder.codingPath, debugDescription: "parsing error"))
            }
            self.error = Int(dict["error"]!.stringValue!)!
            self.index = Int(dict["index"]!.stringValue!)!
        }
    }

    enum EventInfo: Decodable {
        case dispatchInfo(DispatchInfo)
        case dispatchError(DispatchError)
        case stub

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            do {
                self = try .dispatchError(container.decode(DispatchError.self))
            } catch {
                do {
                    self = try .dispatchInfo(container.decode(DispatchInfo.self))
                } catch {
                    self = .stub
//                    throw DecodingError.typeMismatch(EventInfo.self, DecodingError.Context.init(codingPath: decoder.codingPath, debugDescription: "parsing error"))
                }
            }
        }
    }

    let module: UInt64
    let index: UInt64
    var eventInfo: [EventInfo]? = nil

    var errorInfo: Event.DispatchError? {
        let error = self.eventInfo?.first(where: { (info: EventInfo) -> Bool in
            if case .dispatchError(let error) = info { return true }
            return false
        })
        if case .dispatchError(let info) = error {
            return info
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        module = try container.decode(UInt64.self)
        index = try container.decode(UInt64.self)
        if(index > 0) {
            eventInfo = try container.decode([EventInfo].self)
        }
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

        let type = decoded.dictValue?.keys.first ?? decoded.stringValue
        let value = decoded[type!]

        switch type {
        case ExtrinsicStatus.readyField:
            self = .ready
        case ExtrinsicStatus.broadcastField:
            self = .broadcast((value!.arrayValue!.map({ $0.stringValue!})))
        case ExtrinsicStatus.inBlockField:
            self = .inBlock(value!.stringValue!)
        case ExtrinsicStatus.finalizedField:
            self = .finalized(value!.stringValue!)
        default:
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unexpected extrinsic state")
        }
    }
}
