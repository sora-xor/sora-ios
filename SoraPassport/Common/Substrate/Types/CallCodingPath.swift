/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct CallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension CallCodingPath {
    static var transfer: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer")
    }

    static var transferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer_keep_alive")
    }

    static var swap: CallCodingPath {
        CallCodingPath(moduleName: "LiquidityProxy", callName: "swap")
    }

    static var migration: CallCodingPath {
        CallCodingPath(moduleName: "IrohaMigration", callName: "migrate")
    }
    static var depositLiquidity: CallCodingPath {
        CallCodingPath(moduleName: "PoolXYK", callName: "deposit_liquidity")
    }

    static var withdrawLiquidity: CallCodingPath {
        CallCodingPath(moduleName: "PoolXYK", callName: "withdraw_liquidity")
    }

    static var setReferral: CallCodingPath {
        CallCodingPath(moduleName: "Referrals", callName: "set_referrer")
    }

    static var bondReferralBalance: CallCodingPath {
        CallCodingPath(moduleName: "Referrals", callName: "reserve")
    }

    static var unbondReferralBalance: CallCodingPath {
        CallCodingPath(moduleName: "Referrals", callName: "unreserve")
    }

    var isTransfer: Bool {
        [.transfer, .transferKeepAlive].contains(self)
    }

    var isSwap: Bool {
        [.swap].contains(self)
    }

    var isMigration: Bool {
        [.migration].contains(self)
    }

    var isDepositLiquidity: Bool {
        [.depositLiquidity].contains(self)
    }

    var isWithdrawLiquidity: Bool {
        [.withdrawLiquidity].contains(self)
    }

    var isReferral: Bool {
        [.setReferral, .bondReferralBalance, .unbondReferralBalance].contains(self)
    }
}
