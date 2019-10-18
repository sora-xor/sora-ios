/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol VotingRewardCalculatorProtocol {
    func calculate(for votes: Double) -> Double
}

final class VotingRewardCalculator: VotingRewardCalculatorProtocol {
    let rewardPercentage: Double

    init(rewardPercentage: Double) {
        self.rewardPercentage = rewardPercentage
    }

    func calculate(for votes: Double) -> Double {
        return rewardPercentage * votes
    }
}
