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

/// Native exact PI price model. This deliberately does not expose a KMM
/// `KotlinDouble`; the decimal wire value stays intact until a UI formatter
/// requests `PIQuantity.decimalValue`.
struct PIExactFiatData: Equatable, Sendable {
    let id: String
    let priceUsd: PIQuantity?
}

protocol FiatServiceObserverProtocol: AnyObject {
    func processFiat(data: [PIExactFiatData])
}

protocol FiatServiceProtocol: Actor {
    func getFiat() async -> [PIExactFiatData]
}

struct FiatServiceObserver {
    weak var observer: FiatServiceObserverProtocol?
}

actor FiatService: FiatServiceProtocol {
    static let shared = FiatService()
    private let client = PIIndexerClient()
    private var expiredDate = Date.distantPast
    private var fiatData: [PIExactFiatData] = []

    func getFiat() async -> [PIExactFiatData] {
        if !fiatData.isEmpty, Date() < expiredDate {
            return fiatData
        }

        do {
            let response = try await client.allAssets().map {
                PIExactFiatData(id: $0.id, priceUsd: $0.priceUSD)
            }
            fiatData = response
            expiredDate = Date().addingTimeInterval(600)
            return response
        } catch {
            // Preserve the last fully validated PI snapshot. An unavailable
            // price must never affect balances or authorize a transaction.
            return fiatData
        }
    }
}
