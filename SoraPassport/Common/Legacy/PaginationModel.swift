//
//  Pagination.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public typealias PaginationContext = [String: String]

public struct Pagination: Codable, Equatable {
    public let context: PaginationContext?
    public let count: Int

    public init(count: Int, context: [String: String]? = nil) {
        self.count = count
        self.context = context
    }
}
