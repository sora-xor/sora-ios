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
import SoraKeystore

extension Chain {
    func genesisHash() -> String {
        if let external = SettingsManager.shared.externalGenesis {
            return external
        }
        switch self {
        case .polkadot:
            return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .sora:
            return "0x7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5" //<- PROD
        }
    }

    func existentialDeposit() -> Decimal {
        if let external = SettingsManager.shared.externalExistentialDeposit {
            return Decimal(external)
        }
        switch self {
        case .polkadot:
            return Decimal(string: "1")!
        case .sora:
            return Decimal(string: "0")!
        }
    }

    func addressType() -> SNAddressType {
        if let external = SettingsManager.shared.externalAddressPrefix {
            return UInt16(external)
        }
        switch self {
        case .sora:
            return 69
        default:
            return 0
        }
    }

    func polkascanExtrinsicURL(_ hash: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/extrinsic/\(hash)")
        case .sora:
            return nil
        }
    }

    func polkascanAddressURL(_ address: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/account/\(address)")
        case .sora:
            return nil
        }
    }

    func subscanExtrinsicURL(_ hash: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/extrinsic/\(hash)")
        case .sora:
            return nil
        }
    }

    func subscanAddressURL(_ address: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/account/\(address)")
        case .sora:
            return nil
        }
    }

    func preparedWhiteListPath() -> String? {
        return R.file.whitelistJson.path()
    }

    func preparedDefaultTypeDefPath() -> String? {
        return R.file.runtimeDefaultJson.path()
    }

    func preparedNetworkTypeDefPath() -> String? {
        switch self {
        case .polkadot:
            return R.file.runtimePolkadotJson.path()
        case .sora:
            return R.file.runtimeSoraJson.path()
        }
    }

    //swiftlint:disable line_length
    func typeDefDefaultFileURL() -> URL? {
        URL(string: "https://raw.githubusercontent.com/polkascan/py-scale-codec/master/scalecodec/type_registry/default.json")
    }

    func typeDefNetworkFileURL() -> URL? {
        let base = URL(string: "https://raw.githubusercontent.com/polkascan/py-scale-codec/master/scalecodec/type_registry")
        switch self {
        case .sora:
            let url = "https://raw.githubusercontent.com/sora-xor/sora2-substrate-js-library/master/packages/types/src/metadata/\(repoPrefix)/types_scalecodec_mobile.json"
            return URL(string: url)
        case .polkadot:
            return base?.appendingPathComponent("polkadot.json")
        }
    }
    //swiftlint:enable line_length

    var repoPrefix: String {
        #if F_RELEASE
            return "prod"
        #elseif F_STAGING
            return "stage"
        #elseif F_TEST
            return "test"
        #else
            return "dev"
        #endif
    }
}
