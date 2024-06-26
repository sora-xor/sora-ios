//
//  String+Kensetsu.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 6/24/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

extension String {
    var kensetsuCase: String {
        self == WalletAssetId.kxor ? WalletAssetId.xor.rawValue : self
    }
}
