import SCard
import SoraUIKit

extension SCard.Config {
    static let prod = SCard.Config(
        backendUrl: SoraCardCIKeys.backendProdUrl,
        pwAuthDomain: SoraCardCIKeys.domainProd,
        pwApiKey: SoraCardCIKeys.apiKeyProd,
        kycUrl: SoraCardCIKeys.kycEndpointUrlProd,
        kycUsername: SoraCardCIKeys.kycUsernameProd,
        kycPassword: SoraCardCIKeys.kycPasswordProd,
        xOneEndpoint: SoraCardCIKeys.xOneEndpointProd,
        xOneId: SoraCardCIKeys.xOneIdProd,
        environmentType: .prod,
        themeMode: SoramitsuUI.shared.themeMode
    )

    static let test = SCard.Config(
        backendUrl: SoraCardCIKeys.backendTestUrl,
        pwAuthDomain: SoraCardCIKeys.domainTest,
        pwApiKey: SoraCardCIKeys.apiKeyTest,
        kycUrl: SoraCardCIKeys.kycEndpointUrlTest,
        kycUsername: SoraCardCIKeys.kycUsernameTest,
        kycPassword: SoraCardCIKeys.kycPasswordTest,
        xOneEndpoint: SoraCardCIKeys.xOneEndpointTest,
        xOneId: SoraCardCIKeys.xOneIdTest,
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )

    static let local = SCard.Config(
        backendUrl: "https://backend.dev.sora-card.tachi.soramitsu.co.jp/",
        pwAuthDomain: "soracard.com",
        pwApiKey: "",
        kycUrl: "https://kyc-test.soracard.com/mobile",
        kycUsername: "",
        kycPassword: "",
        xOneEndpoint: "",
        xOneId: "",
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )
}
