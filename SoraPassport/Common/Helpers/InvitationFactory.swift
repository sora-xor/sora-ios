/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol InvitationFactoryProtocol {
    func createInvitation(for code: String, enviroment: RemoteEnviroment) -> String
    func createInvitationLink(for code: String, enviroment: RemoteEnviroment) -> URL
}

extension InvitationFactoryProtocol {
    func createInvitation(from code: String) -> String {
        #if F_DEV
        return createInvitation(for: code, enviroment: .development)
        #elseif F_TEST
        return createInvitation(for: code, enviroment: .test)
        #elseif F_STAGING
        return createInvitation(for: code, enviroment: .staging)
        #else
        return createInvitation(for: code, enviroment: .release)
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

        return url.appendingPathComponent("/join/\(code)")
    }

    func createInvitation(for code: String, enviroment: RemoteEnviroment) -> String {
        let url = createInvitationLink(for: code, enviroment: enviroment)
        return "Join Sora using link below:\n\(url.absoluteString)"
    }
}
