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

struct KmmCallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension KmmCallCodingPath {
    static var transfer: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "assets", callName: "transfer")
    }

    static var transferKeepAlive: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "assets", callName: "transferKeepAlive")
    }

    static var swap: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "liquidityProxy", callName: "swap")
    }

    static var migration: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "irohaMigration", callName: "migrate")
    }
    static var depositLiquidity: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "poolXYK", callName: "depositLiquidity")
    }

    static var withdrawLiquidity: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "poolXYK", callName: "withdrawLiquidity")
    }

    static var setReferral: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "setReferrer")
    }

    static var bondReferralBalance: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "reserve")
    }

    static var unbondReferralBalance: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "unreserve")
    }
    
    static var batchUtility: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "utility", callName: "batch")
    }
    
    static var batchAllUtility: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "utility", callName: "batchAll")
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
