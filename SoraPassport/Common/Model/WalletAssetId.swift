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

enum WalletAssetId: String {
    case xor =      "0x0200000000000000000000000000000000000000000000000000000000000000"
    case val =      "0x0200040000000000000000000000000000000000000000000000000000000000"
    case pswap =    "0x0200050000000000000000000000000000000000000000000000000000000000"
    case xst =      "0x0200090000000000000000000000000000000000000000000000000000000000"
    case xstusd =   "0x0200080000000000000000000000000000000000000000000000000000000000"
    case tbcd =     "0x02000a0000000000000000000000000000000000000000000000000000000000"
    case kusd =     "0x02000c0000000000000000000000000000000000000000000000000000000000"
    static let eth = "0x0200070000000000000000000000000000000000000000000000000000000000"
    static let kxor = "0x02000e0000000000000000000000000000000000000000000000000000000000"
}
