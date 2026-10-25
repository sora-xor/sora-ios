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
import Combine
import BigInt

/// Exact pool-share selection used for Demeter deposit/withdraw amounts.
/// UIKit's Float-backed slider is converted to this value at the view boundary;
/// transaction math uses only the integer basis points and Decimal adapters.
struct FarmShareSelection: Equatable, Hashable, Sendable {
    static let maximumBasisPoints: UInt16 = 10_000
    static let zero = FarmShareSelection(uncheckedBasisPoints: 0)
    static let maximum = FarmShareSelection(
        uncheckedBasisPoints: maximumBasisPoints
    )

    let basisPoints: UInt16

    init?(basisPoints: UInt16) {
        guard basisPoints <= Self.maximumBasisPoints else { return nil }
        self.basisPoints = basisPoints
    }

    init?(percent: Decimal) {
        guard percent >= 0, percent <= 100 else { return nil }
        var scaled = percent * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        let rawValue = NSDecimalNumber(decimal: rounded).uint64Value
        guard rawValue <= UInt64(Self.maximumBasisPoints) else { return nil }
        self.init(basisPoints: UInt16(rawValue))
    }

    init?(sliderValue: Float) {
        guard sliderValue.isFinite else { return nil }
        let clamped = min(max(sliderValue, 0), 1)
        let rawValue = UInt16(
            (clamped * Float(Self.maximumBasisPoints)).rounded()
        )
        self.init(basisPoints: rawValue)
    }

    var percent: Decimal {
        Decimal(Int(basisPoints)) / 100
    }

    var fraction: Decimal {
        Decimal(Int(basisPoints)) / 10_000
    }

    /// Presentation-only adapter for UISlider.
    var sliderValue: Float {
        Float(basisPoints) / Float(Self.maximumBasisPoints)
    }

    private init(uncheckedBasisPoints: UInt16) {
        basisPoints = uncheckedBasisPoints
    }
}


protocol EditFarmItemServiceProtocol {
    func setup()
}

enum FarmTransaction {
    case deposit
    case withdraw

    var transactionType: TransactionType {
        switch self {
        case .deposit:
            return TransactionType.demeterDeposit
        case .withdraw:
            return TransactionType.demeterWithdraw
        }
    }
}

final class EditFarmItemService: EditFarmItemServiceProtocol {
    @Published var isMaxButtonHidden: Bool = false
    @Published var confirmButtonEnabled: Bool = false
    @Published var feeText: String?
    @Published var networkFeeText: String = ""
    @Published var percentageText: String = ""
    @Published var willBePercentageText: String = ""

    var amount: Decimal = Decimal(0)
    var farmTransaction: FarmTransaction = .deposit
    var networkFeeAmount: Decimal = Decimal(0)

    private var feeInfo: (depositFee: Decimal, withdrawFee: Decimal)? {
        didSet {
            guard let feeInfo else { return }
            let feeText = NumberFormatter.cryptoAssets.stringFromDecimal(feeInfo.depositFee) ?? ""
            networkFeeText = feeText + " XOR"
            if let selectedSelection {
                apply(selection: selectedSelection)
            }
        }
    }

    private let poolInfo: PoolInfo
    private let userFarm: UserFarm
    private let currentSelection: FarmShareSelection
    private let feePercentage: Decimal

    private let feeProvider: FeeProviderProtocol
    private let userBalance: Decimal
    private let callFactory = SubstrateCallFactory()
    private var cancellables = Set<AnyCancellable>()
    private let output: PassthroughSubject<Void, Never> = .init()
    private var selectedSelection: FarmShareSelection?

    init(
        poolInfo: PoolInfo,
        userFarm: UserFarm,
        feeProvider: FeeProviderProtocol,
        currentSelection: FarmShareSelection,
        feePercentage: Decimal,
        userBalance: Decimal
    ) {
        self.userFarm = userFarm
        self.feeProvider = feeProvider
        self.currentSelection = currentSelection
        self.feePercentage = feePercentage
        self.poolInfo = poolInfo
        self.userBalance = userBalance
    }

    func setup() {
        Task { [weak self] in
            self?.feeInfo = try? await self?.loadFeeInfo()
        }
    }

    func transform(input: AnyPublisher<FarmShareSelection, Never>) -> AnyPublisher<Void, Never> {
        input.sink { [weak self] selection in
            self?.apply(selection: selection)
        }.store(in: &cancellables)
        return output.eraseToAnyPublisher()
    }
}

private extension EditFarmItemService {
    func apply(selection: FarmShareSelection) {
        selectedSelection = selection

        let isDeposit = selection.basisPoints > currentSelection.basisPoints
        farmTransaction = isDeposit ? .deposit : .withdraw
        isMaxButtonHidden = selection.basisPoints == FarmShareSelection.maximumBasisPoints

        let percent = NumberFormatter.percent.string(from: selection.percent as NSNumber) ?? ""
        percentageText = percent + "%"

        let feePercentageIsValid = feePercentage >= 0 && feePercentage <= 100
        let appliedFeePercentage = isDeposit && feePercentageIsValid
            ? feePercentage
            : 0
        feeText = "\(appliedFeePercentage)%"

        if let feeInfo {
            networkFeeAmount = isDeposit ? feeInfo.depositFee : feeInfo.withdrawFee

            let feeText = NumberFormatter.cryptoAssets.stringFromDecimal(networkFeeAmount) ?? ""
            networkFeeText = feeText + " XOR"
        }

        let accountPoolBalance = poolInfo.accountPoolBalance ?? Decimal(0)
        let pooledTokens = userFarm.pooledTokens ?? Decimal(0)
        let poolStateIsValid = accountPoolBalance > 0
            && pooledTokens >= 0
            && pooledTokens <= accountPoolBalance

        amount = abs((accountPoolBalance * selection.fraction) - pooledTokens)
        let feeAmount = isDeposit ? amount * appliedFeePercentage / 100 : 0
        let stakingAmountWithoutFee = amount - feeAmount

        let adjustedPoolBalance = accountPoolBalance - feeAmount
        var shareWillBe = adjustedPoolBalance > 0
            ? ((stakingAmountWithoutFee + pooledTokens) / adjustedPoolBalance) * 100
            : selection.percent

        if selection.percent < shareWillBe {
            shareWillBe = selection.percent
        }

        confirmButtonEnabled = feeInfo != nil
            && feePercentageIsValid
            && poolStateIsValid
            && networkFeeAmount >= 0
            && userBalance > networkFeeAmount
            && selection != currentSelection
            && amount > 0
            && adjustedPoolBalance > 0

        let shareWillBePercent = NumberFormatter.percent.stringFromDecimal(shareWillBe) ?? ""
        willBePercentageText = shareWillBePercent + "%"
        output.send(())
    }

    private func loadFeeInfo() async throws -> (depositFee: Decimal, withdrawFee: Decimal) {
        let depositFee = try await getDepositFee()
        let withdrawFee = try await getWithdrawFee()
        return (depositFee: depositFee, withdrawFee: withdrawFee)
    }

    func getDepositFee() async throws -> Decimal {
        let call = try callFactory.depositLiquidityToDemeterFarmCall(baseAssetId: userFarm.baseAssetId,
                                                                     targetAssetId: userFarm.poolAssetId,
                                                                     rewardAssetId: userFarm.rewardAssetId,
                                                                     isFarm: userFarm.isFarm,
                                                                     amount: BigUInt(1))

        return await feeProvider.getFee(for: call)
    }

    func getWithdrawFee() async throws -> Decimal {
        let call = try callFactory.withdrawLiquidityFromDemeterFarmCall(baseAssetId: userFarm.baseAssetId,
                                                                        targetAssetId: userFarm.poolAssetId,
                                                                        rewardAssetId: userFarm.rewardAssetId,
                                                                        isFarm: userFarm.isFarm,
                                                                        amount: BigUInt(1))

        return await feeProvider.getFee(for: call)
    }
}
