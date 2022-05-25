import Foundation
import FearlessUtils
import BigInt

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
        eventRecords.filter { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }
            return eventPath == .feeWitdrawn
        }.reduce(BigUInt(0)) { totalFee, record in
            guard let deposit = try? record.event.params.map(to: BalanceDepositEvent.self) else {
                return totalFee
            }

            return totalFee + deposit.amount
        }
    }

    private func matchTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {
        do {
            let sender = extrinsic.signature?.address.stringValue
            let call = try extrinsic.call.map(to: RuntimeCall<SoraTransferCall>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == sender || accountId == call.args.receiver

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

            let peerId = accountId == sender ? call.args.receiver : sender

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: fee,
                peerId: peerId,
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
            let sender = extrinsic.signature?.address.stringValue
            let call = try extrinsic.call.map(to: RuntimeCall<MigrateCall>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == sender

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
            let sender = extrinsic.signature?.address.stringValue
            let call = try extrinsic.call.map(to: RuntimeCall<NoRuntimeArgs>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == sender

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

        } catch {
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

            if let processingResult = matchTransfer(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata
            ) {
                return processingResult
            }

            if let migrationResult = matchMigration(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata
            ) {
                return migrationResult
            }

            return matchExtrinsic(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata
            )
        } catch {
            return nil
        }
    }
}
