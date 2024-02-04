//
//  DexInfos.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 1/23/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

struct DexInfos: Decodable {
    var baseAssetId: AssetId
    var syntheticBaseAssetId: AssetId
    var isPublic: Bool
}
