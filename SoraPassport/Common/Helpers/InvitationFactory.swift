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

protocol InvitationFactoryProtocol {
    func createInvitation(for code: String, enviroment: RemoteEnviroment, locale: Locale?) -> String
    func createInvitationLink(for code: String, enviroment: RemoteEnviroment) -> URL
}

extension InvitationFactoryProtocol {
    func createInvitation(from code: String, locale: Locale?) -> String {
        #if F_DEV
        return createInvitation(for: code, enviroment: .development, locale: locale)
        #elseif F_TEST
        return createInvitation(for: code, enviroment: .test, locale: locale)
        #elseif F_STAGING
        return createInvitation(for: code, enviroment: .staging, locale: locale)
        #else
        return createInvitation(for: code, enviroment: .release, locale: locale)
        #endif
    }
}

struct InvitationFactory: InvitationFactoryProtocol {
    let host: URL

    func createInvitationLink(for code: String, enviroment: RemoteEnviroment) -> URL {
        var url = host

        if !enviroment.rawValue.isEmpty {
            url = url.appendingPathComponent(enviroment.rawValue)
        }

        return url//.appendingPathComponent("/join/\(code)")
    }

    func createInvitation(for code: String, enviroment: RemoteEnviroment, locale: Locale?) -> String {
        let url = createInvitationLink(for: code, enviroment: enviroment)
        return R.string.localizable.inviteLinkFormat(url.absoluteString,
                                                     preferredLanguages: locale?.rLanguages)
    }
}
