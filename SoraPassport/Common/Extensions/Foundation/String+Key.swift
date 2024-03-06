//
//  String+Key.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/3/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

enum AssetKeyExtractionError: Error {
    case invalidSize
}

extension String {
    func assetIdFromKey() throws -> String {
        guard self.count > 64 else {
            throw AssetKeyExtractionError.invalidSize
        }
        return "0x" + self.suffix(64)
    }
}
