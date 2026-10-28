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

protocol GenesisProviderProtocol {
    /// The genesis hash that identifies the SORA network for this installation.
    func load() -> String
}

/// Answers the genesis hash locally, in every build configuration: the hash
/// saved by an earlier launch, or SORA mainnet's.
///
/// Release builds have always done this (genesis pinning). Other builds used
/// to ask the launch node for block 0 and waited up to 10 seconds for it,
/// which held up wallet startup whenever that node was unreachable. Startup
/// must not depend on a node, and the nodes bundled with the app are SORA
/// mainnet nodes in every build configuration.
struct GenesisProvider: GenesisProviderProtocol {
    func load() -> String {
        Chain.sora.genesisHash()
    }
}
