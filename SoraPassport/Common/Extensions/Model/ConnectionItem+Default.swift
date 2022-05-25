import Foundation
import IrohaCrypto
import SoraKeystore

extension ConnectionItem {
    static var defaultConnection: ConnectionItem {
        #if F_RELEASE
        return ConnectionItem(title: "Sora, Release",
                       url: URL(string: "wss://ws.mof.sora.org")!,
                       type: Self.addressType)
        #elseif F_STAGING
        return ConnectionItem(title: "Sora, Stage",
                       url: URL(string: "wss://ws.stage.sora2.soramitsu.co.jp")!,
                       type: Self.addressType)
        #elseif F_TEST //soralution
        return ConnectionItem(title: "Sora, Soralution",
                       url: URL(string: "wss://ws.stage.sora2.soramitsu.co.jp")!,
                       type: Self.addressType)
        #else
        return ConnectionItem(title: "Sora, Dev",
                       url: URL(string: "wss://ws.framenode-3.s3.dev.sora2.soramitsu.co.jp/")!,
                       type: Self.addressType)
        #endif
    }

    static var supportedConnections: [ConnectionItem] {
        [
            ConnectionItem(title: "Sora, Stage",
                           url: URL(string: "wss://ws.stage.sora2.soramitsu.co.jp")!,
                           type: Self.addressType)
        ]
    }

    static var addressType: SNAddressType {
        return SNAddressType(SettingsManager.shared.externalAddressPrefix ?? 69)
    }
}
