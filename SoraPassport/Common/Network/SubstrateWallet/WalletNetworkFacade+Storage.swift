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
import IrohaCrypto
import BigInt
import SoraKeystore

extension WalletNetworkFacade {
    /// `System.Account` as the runtime's own metadata decodes it, before
    /// the app's balance model is applied. A failure here is a failed read
    /// (no answer, or metadata not ready); whether the app's model
    /// understands the answer is decided by `WalletBalanceReading`.
    func createAccountInfoStorageFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<JSON?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = requestFactory.queryItems(
            engine: engine,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.account
        )

        let mapOperation = ClosureOperation<JSON?> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()
            let key = try StorageKeyFactory().accountInfoKeyForId(accountId)
            guard responses.count == 1, let response = responses.first, response.key == key else {
                throw PortfolioReaderError.invalidStorageResponse
            }
            return response.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    /// - Parameter markingUnavailable: Keep an entry, marked
    ///   `BalanceData.isUnavailable`, for an asset whose balance could not
    ///   be read. Only the wallet's balance provider asks for that, because
    ///   it shows such an asset as "Balance unavailable". Every other caller
    ///   gets no entry for it, which they already treat as "not loaded".
    ///   Either way an unread balance is never reported as zero.
    func fetchBalanceInfoForAssets(_ assets: [WalletAsset], markingUnavailable: Bool = false)
        -> CompoundOperationWrapper<[BalanceData]?> {
        guard !assets.isEmpty else { return .createWithResult([]) }
        //swiftlint:disable force_cast
        let factory = nodeOperationFactory as! WalletNetworkOperationFactory
        //swiftlint:enable force_cast
        do {

            let accountId = try SS58AddressFactory().accountId(
                fromAddress: address,
                type: networkType
            )

            let accountInfoOperation: CompoundOperationWrapper<JSON?> = createAccountInfoStorageFetchOperation(accountId)

            let dependencies = assets.map {
                factory.createUsableBalanceOperation(
                    accountId: address,
                    assetId: $0.identifier
                )
            }
            
            let eraOperation = factory.createActiveEraOperation()
            let stackingInfoOperation = factory.createStackingIngoOperation(accountId: accountId)
            
            let mappingOperation = ClosureOperation<[BalanceData]?> {

                let result = try dependencies.map { operation -> BalanceData in
                    let assetNetworkId = operation.parameters?.last
                    guard let asset = assets.first(where: { assetNetworkId?.contains($0.identifier.dropFirst(2)) ?? false }) else {
                        return .init(identifier: WalletAsset.dummyAsset.identifier, balance: .init(value: 0))
                    }

                    let reading: WalletBalanceReading
                    if asset.identifier == WalletAssetId.xor.rawValue {
                        // No answer for the account at all (offline, node
                        // or runtime not ready) fails the whole read, so the
                        // balances shown so far stay as they are.
                        reading = WalletBalanceReading.xor(
                            account: try accountInfoOperation.targetOperation.extractNoCancellableResultData()
                        )
                    } else {
                        reading = WalletBalanceReading.token(
                            storage: Result { try operation.extractNoCancellableResultData() }
                        )
                    }

                    guard case let .amounts(accountData) = reading else {
                        return BalanceData.unavailable(
                            identifier: asset.identifier,
                            notRead: reading == .notRead
                        )
                    }

                    var context: BalanceContext = BalanceContext(context: [:])
                    do {
                        context = try context.byChangingAccountInfo(accountData, precision: asset.precision)
                    } catch {
                        return .unavailable(identifier: asset.identifier)
                    }
                    
                    if asset.identifier == WalletAssetId.xor.rawValue,
                       let eraInfo = try? eraOperation.targetOperation.extractNoCancellableResultData(),
                       let stackingInfo = try? stackingInfoOperation.extractNoCancellableResultData().underlyingValue {
                        do {
                            context = try context.byChangingStakingInfo(stackingInfo, activeEra: eraInfo, precision: asset.precision)
                        } catch {
                            return .unavailable(identifier: asset.identifier)
                        }
                    }
                    

                    let balanceData = BalanceData(identifier: asset.identifier,
                                                  balance: AmountDecimal(value: context.available),
                                                  context: context.toContext())
                    return balanceData
                }

                return markingUnavailable ? result : result.filter { !$0.isUnavailable }
            }
            let infoDependencies = accountInfoOperation.allOperations
            infoDependencies.forEach { operation in
                mappingOperation.addDependency(operation)
            }
            
            (dependencies + eraOperation.allOperations + [stackingInfoOperation]).forEach { operation in
                mappingOperation.addDependency(operation)
            }

            return CompoundOperationWrapper(targetOperation: mappingOperation,
                                            dependencies: dependencies + infoDependencies + eraOperation.allOperations + [stackingInfoOperation])
        } catch {
            return CompoundOperationWrapper<[BalanceData]?>
                .createWithError(error)
        }
    }

    func queryStorageByKey<T: ScaleDecodable>(_ storageKey: Data) -> CompoundOperationWrapper<T?> {
        let identifier = localStorageIdFactory.createIdentifier(for: storageKey)
        return chainStorage.queryStorageByKey(identifier)
    }
}

/// What one balance read says about one asset.
///
/// A balance is a number only when the chain's answer was understood. When
/// the node answers with a value the app's model cannot read (a field
/// renamed or added by a runtime upgrade, as happened to `System.Account` in
/// May 2026), the balance is unavailable. It is never shown as zero: a
/// holder must not be told the funds are gone because the app is behind the
/// chain.
enum WalletBalanceReading: Equatable {
    case amounts(AccountData)
    /// The node answered and the app does not understand the answer.
    case unavailable
    /// The request for this asset got no answer in this read (a timeout,
    /// a dropped connection). Nothing new is known about the balance.
    case notRead

    /// XOR, from `System.Account` as the runtime metadata decoded it. No
    /// stored value is an account that holds nothing.
    static func xor(account: JSON?) -> WalletBalanceReading {
        guard let account else {
            return .amounts(AccountData(free: 0, reserved: 0, miscFrozen: 0, feeFrozen: 0))
        }
        guard let info = try? account.map(to: AccountInfo.self) else {
            return .unavailable
        }
        return .amounts(info.data)
    }

    /// Any other token, from its `Tokens.Accounts` storage value. A read
    /// that failed is not read in this pass, never zero.
    static func token(storage: Result<OrmlAccountStorage, Error>) -> WalletBalanceReading {
        guard case let .success(storage) = storage else {
            if case let .failure(error) = storage, error is DecodingError {
                // An answer arrived and is not a storage value.
                return .unavailable
            }
            return .notRead
        }
        guard let hex = storage.hex else {
            return .amounts(AccountData(free: 0, reserved: 0, miscFrozen: 0, feeFrozen: 0))
        }
        guard
            let data = try? Data(hexStringSSF: hex),
            let decoder = try? ScaleDecoder(data: data),
            let balances = try? OrmlAccountData(scaleDecoder: decoder),
            // Bytes the model does not account for mean another layout.
            decoder.remained == 0
        else {
            return .unavailable
        }
        return .amounts(AccountData(
            free: balances.free.value,
            reserved: balances.reserved.value,
            miscFrozen: 0,
            feeFrozen: balances.frozen.value
        ))
    }
}

/// The raw storage value of one token account, kept undecoded so that "the
/// node did not answer" and "the answer is not understood" stay apart.
struct OrmlAccountStorage: Decodable {
    /// Nil when the chain stores nothing for this account and token.
    let hex: String?

    init(hex: String?) {
        self.hex = hex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        hex = container.decodeNil() ? nil : try container.decode(String.self)
    }
}

extension BalanceData {
    static let unavailableContextKey = "balanceUnavailable"

    /// The value of `unavailableContextKey` when the request got no answer,
    /// as opposed to an answer that was not understood ("1").
    static let notReadContextValue = "notRead"

    /// An entry for an asset whose balance could not be read. Its `balance`
    /// carries no information and must not be shown.
    ///
    /// - Parameter notRead: The request got no answer in this read, so
    ///   nothing new is known; otherwise the answer was not understood.
    static func unavailable(identifier: String, notRead: Bool = false) -> BalanceData {
        BalanceData(
            identifier: identifier,
            balance: AmountDecimal(value: 0),
            context: [unavailableContextKey: notRead ? notReadContextValue : "1"]
        )
    }

    /// The balance could not be read, for either reason.
    var isUnavailable: Bool {
        context?[Self.unavailableContextKey] != nil
    }

    /// The balance could not be read because its request got no answer.
    var balanceWasNotRead: Bool {
        context?[Self.unavailableContextKey] == Self.notReadContextValue
    }
}
