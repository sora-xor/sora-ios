//
//  String+Key.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/3/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

extension String {
    func assetIdFromKey() -> String {
        return "0x" + self.suffix(64)
    }
}
