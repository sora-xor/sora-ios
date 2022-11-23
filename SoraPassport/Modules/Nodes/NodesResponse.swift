//
//  NodesResponse.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 01.09.2022.
//  Copyright © 2022 Ruslan Rezin. All rights reserved.
//

import Foundation

struct NodesResponse: Decodable {
    var nodes: [ChainNodeModel]

    enum CodingKeys: String, CodingKey {
        case nodes = "DEFAULT_NETWORKS"
    }
}
