//
//  DexInfos.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 1/23/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

struct DexInfos: Decodable {
    let baseAssetId: AssetId
    let syntheticBaseAssetId: AssetId
    let isPublic: Bool
}
