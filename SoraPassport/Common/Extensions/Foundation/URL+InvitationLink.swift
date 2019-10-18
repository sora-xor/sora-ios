/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension URL {
    static func invitationLink(for code: String, enviroment: RemoteEnviroment) -> URL? {
        var urlString = "https://ref.sora.org"

        guard let encodedCode = code.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) else {
            return nil
        }

        if !enviroment.rawValue.isEmpty {
            urlString = urlString.appending("/\(enviroment.rawValue)")
        }

        urlString = urlString.appending("/join/\(encodedCode)")

        return URL(string: urlString)
    }
}
