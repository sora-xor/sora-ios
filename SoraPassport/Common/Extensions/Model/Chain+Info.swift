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
            return "fb589ecdc56362972e05d1bf4e74210a17319af53c9e1cc8f62d4e64f5dac6f8" //<- dev || stg -> "addfb88ccb44d6777c5a09c428c438f57367111bd03ce60e5104e9e0c1726850"
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
            return Decimal(string: "1")!
        }
    }

    func addressType() -> SNAddressType {
        if let external = SettingsManager.shared.externalAddressPrefix {
            return UInt8(external)
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
            let url = String(format: "https://raw.githubusercontent.com/sora-xor/sora2-types/master/%@sora2_types.json", repoPrefix)
            return URL(string: url)
        case .polkadot:
            return base?.appendingPathComponent("polkadot.json")
        }
    }
    //swiftlint:enable line_length

    var repoPrefix: String {
        #if F_RELEASE
            return "prod/"
        #elseif F_STAGING
            return "stage/"
        #elseif F_TEST
            return "test/"
        #else
            return "dev/"
        #endif
    }
}
