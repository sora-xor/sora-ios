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

struct SignedBlock: Decodable {
    let block: Block
    let justification: Data?
}

struct Block: Decodable {
    struct Digest: Decodable {
        let logs: [String]
    }

    struct Header: Decodable {
        let digest: Digest
        let extrinsicsRoot: String
        let number: String
        let stateRoot: String
        let parentHash: String
    }

    let extrinsics: [String]
    let header: Header
}
