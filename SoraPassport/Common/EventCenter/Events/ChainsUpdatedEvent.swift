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

struct ChainsUpdatedEvent: EventProtocol {
    let updatedChains: [ChainModel]

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainsUpdated(event: self)
    }
}

/// The wallet's screens were built while there was no asset list at all (a
/// first launch on which no node answered yet), and the list has now arrived.
/// The screens are built from the list, so they have to be built again.
struct WalletAssetListArrived: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletAssetListArrived(event: self)
    }
}
