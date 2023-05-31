import Foundation
import FearlessUtils
import BigInt
import IrohaCrypto

struct ExtrinsicProcessingResult {
    let extrinsic: Extrinsic
    let callPath: CallCodingPath
    let fee: BigUInt?
    let peerId: AccountAddress?
    let isSuccess: Bool
}

protocol ExtrinsicProcessing {
    func process(
        extrinsicIndex: UInt32,
        extrinsicData: Data,
        eventRecords: [EventRecord],
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult?
}

final class ExtrinsicProcessor {
    let accountId: AccountAddress
    var account: MultiAddress {
        // swiftlint:disable:next force_try
        MultiAddress.accoundId(try! Data(hexString: accountId))
        //probably should be address32
    }

    init(accountId: AccountAddress) {
        self.accountId = accountId
    }

    private func matchStatus(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> Bool? {
        eventRecords.filter { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                       return false
            }

            return [.extrinsicSuccess, .extrinsicFailed].contains(eventPath)
        }.first.map { metadata.createEventCodingPath(from: $0.event) == .extrinsicSuccess }
    }

    private func findFee(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> BigUInt? {
        eventRecords.compactMap { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return nil
            }
            if eventPath == .balanceDeposit {
                return try? record.event.data.map(to: BalanceDepositEvent.self).amount
            }

            if eventPath == .feeWitdrawn {
                return BigUInt((record.event.data.arrayValue ?? []).last?.stringValue ?? "0")
            }

            return nil
        }.reduce(BigUInt(0)) { (totalFee: BigUInt, partialFee: BigUInt) in
            totalFee + partialFee
        }
    }

    private func matchBatch(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {
        let batch = try? extrinsic.call.map(to: RuntimeCall<BatchArgs>.self)

        let calls = batch?.args.calls ?? []
        for call in calls {
            let innerExtrinsic = Extrinsic(signature: extrinsic.signature, call: call)
            process(extrinsicIndex: extrinsicIndex, extrinsic: innerExtrinsic, eventRecords: eventRecords, metadata: metadata)
        }
        return nil
    }

    private func matchTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {
        do {
            let sender = try extrinsic.signature?.address.map(to: MultiAddress.self)
            let accData = try? SS58AddressFactory().accountId(fromAddress: accountId, type: 69)

            let call = try extrinsic.call.map(to: RuntimeCall<SoraTransferCall>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = account == sender || account == call.args.receiver

            guard
                callPath.isTransfer,
                isAccountMatched,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: metadata
            )

            let peerId = account == sender ? call.args.receiver : sender

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: fee,
                peerId: try? SS58AddressFactory().addressFromAccountId(data: peerId!.data, type: 69),
                isSuccess: isSuccess
            )

        } catch {
            return nil
        }
    }

    private func matchMigration(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {
        do {
            let sender = try extrinsic.signature?.address.map(to: MultiAddress.self)
            let call = try extrinsic.call.map(to: RuntimeCall<MigrateCall>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = account == sender

            guard
                isAccountMatched,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: nil,
                peerId: nil,
                isSuccess: isSuccess
            )

        } catch {
            return nil
        }
    }

    private func matchExtrinsic(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {
        do {
            let sender = try extrinsic.signature?.address.map(to: MultiAddress.self)
            let call = try extrinsic.call.map(to: RuntimeCall<NoRuntimeArgs>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = account == sender

            guard
                isAccountMatched,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: metadata
            )

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: fee,
                peerId: nil,
                isSuccess: isSuccess
            )

        } catch let error {
            return nil
        }
    }
}

extension ExtrinsicProcessor: ExtrinsicProcessing {
    func process(
        extrinsicIndex: UInt32,
        extrinsicData: Data,
        eventRecords: [EventRecord],
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult? {
        do {
            let decoder = try coderFactory.createDecoder(from: extrinsicData)
            let extrinsic: Extrinsic = try decoder.read(of: GenericType.extrinsic.name)
            return process(extrinsicIndex: extrinsicIndex,
                           extrinsic: extrinsic,
                           eventRecords: eventRecords,
                           metadata: coderFactory.metadata)

        } catch let error {
            print(error)
            return nil
        }
    }

    func process(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata:  RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {

        if let result = matchBatch(
            extrinsicIndex: extrinsicIndex,
            extrinsic: extrinsic,
            eventRecords: eventRecords,
            metadata: metadata
        ) {
            return nil
        }

        if let processingResult = matchTransfer(
            extrinsicIndex: extrinsicIndex,
            extrinsic: extrinsic,
            eventRecords: eventRecords,
            metadata: metadata
        ) {
            return processingResult
        }

        if let migrationResult = matchMigration(
            extrinsicIndex: extrinsicIndex,
            extrinsic: extrinsic,
            eventRecords: eventRecords,
            metadata: metadata
        ) {
            return migrationResult
        }

        return matchExtrinsic(
            extrinsicIndex: extrinsicIndex,
            extrinsic: extrinsic,
            eventRecords: eventRecords,
            metadata: metadata
        )
    }
}