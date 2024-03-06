//
//  PolkaswapAPYService.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/4/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import IrohaCrypto
import RobinHood
import sorawallet

enum PolkaswapAPYServiceError: Swift.Error {
    case unexpectedError
}

protocol PolkaswapAPYService: Actor {
    func getApy(reservesId: String) async throws -> Decimal
}

public actor PolkaswapAPYServiceDefault {
    private let worker: PolkaswapAPYWorker
    private var apyCache: [String: Decimal] = [:]
    
    //TODO: delete it
    public init(worker: PolkaswapAPYWorker) {
        self.worker = worker
    }
}

extension PolkaswapAPYServiceDefault: PolkaswapAPYService {

    func getApy(reservesId: String) async throws -> Decimal {
        if let apy = apyCache[reservesId] {
            return apy
        }
        
        let apyInfo = try await worker.getAPYInfo()

        apyInfo.forEach { apy in
            apyCache[apy.id] = apy.sbApy?.decimalValue
        }
        
        if let apy = apyCache[reservesId] {
            return apy
        }

        throw PolkaswapAPYServiceError.unexpectedError
    }
}
