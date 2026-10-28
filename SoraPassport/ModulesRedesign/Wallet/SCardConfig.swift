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

import SCard
import SoraUIKit

extension SCard.Config {
    static let prod = SCard.Config(
        appStoreUrl: "https://apps.apple.com/us/app/sora-wallet-polkaswap/id1457566711",
        backendUrl: SoraCardCIKeys.backendProdUrl,
        pwAuthDomain: SoraCardCIKeys.domainProd,
        pwApiKey: SoraCardCIKeys.apiKeyProd,
        appPlatformId: SoraCardCIKeys.appPlatformIdProd,
        recaptchaKey: SoraCardCIKeys.recaptchaKeyProd,
        kycUrl: SoraCardCIKeys.kycEndpointUrlProd,
        kycUsername: SoraCardCIKeys.kycUsernameProd,
        kycPassword: SoraCardCIKeys.kycPasswordProd,
        xOneEndpoint: SoraCardCIKeys.xOneEndpointProd,
        xOneId: SoraCardCIKeys.xOneIdProd,
        environmentType: .prod,
        themeMode: SoramitsuUI.shared.themeMode
    )

    static let test = SCard.Config(
        appStoreUrl: "https://apps.apple.com/us/app/sora-wallet-polkaswap/id1457566711",
        backendUrl: SoraCardCIKeys.backendTestUrl,
        pwAuthDomain: SoraCardCIKeys.domainTest,
        pwApiKey: SoraCardCIKeys.apiKeyTest,
        appPlatformId: SoraCardCIKeys.appPlatformIdTest,
        recaptchaKey: SoraCardCIKeys.recaptchaKeyTest,
        kycUrl: SoraCardCIKeys.kycEndpointUrlTest,
        kycUsername: SoraCardCIKeys.kycUsernameTest,
        kycPassword: SoraCardCIKeys.kycPasswordTest,
        xOneEndpoint: SoraCardCIKeys.xOneEndpointTest,
        xOneId: SoraCardCIKeys.xOneIdTest,
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )

    static let dev = SCard.Config(
        appStoreUrl: "https://apps.apple.com/us/app/sora-wallet-polkaswap/id1457566711",
        backendUrl: SoraCardCIKeys.backendTestUrl,
        pwAuthDomain: SoraCardCIKeys.domainTest,
        pwApiKey: SoraCardCIKeys.apiKeyTest,
        appPlatformId: SoraCardCIKeys.appPlatformIdDev,
        recaptchaKey: SoraCardCIKeys.recaptchaKeyDev,
        kycUrl: SoraCardCIKeys.kycEndpointUrlTest,
        kycUsername: SoraCardCIKeys.kycUsernameTest,
        kycPassword: SoraCardCIKeys.kycPasswordTest,
        xOneEndpoint: SoraCardCIKeys.xOneEndpointTest,
        xOneId: SoraCardCIKeys.xOneIdTest,
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )

    // Dev
    static let local = SCard.Config(
        appStoreUrl: "https://apps.apple.com/us/app/sora-wallet-polkaswap/id1457566711",
        backendUrl: "https://backend.dev.sora-card.tachi.soramitsu.co.jp/",
        pwAuthDomain: "soracard.com",
        pwApiKey: "",
        appPlatformId: "",
        recaptchaKey: "",
        kycUrl: "https://kyc-test.soracard.com/mobile",
        kycUsername: "",
        kycPassword: "",
        xOneEndpoint: "",
        xOneId: "",
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )
}
