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
import SSFUtils

protocol RuntimeCoderFactoryProtocol {
    var specVersion: UInt32 { get }
    var txVersion: UInt32 { get }
    var metadata: RuntimeMetadata { get }

    func createEncoder() -> DynamicScaleEncoding
    func createDecoder(from data: Data) throws -> DynamicScaleDecoding
}

final class RuntimeCoderFactory: RuntimeCoderFactoryProtocol {
    let catalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadata

    init(catalog: TypeRegistryCatalogProtocol, specVersion: UInt32, txVersion: UInt32, metadata: RuntimeMetadata) {
        self.catalog = catalog
        self.specVersion = specVersion
        self.txVersion = txVersion
        self.metadata = metadata
    }

    func createEncoder() -> DynamicScaleEncoding {
        DynamicScaleEncoder(registry: catalog, version: UInt64(specVersion))
    }

    func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
        try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(specVersion))
    }
}
