//
//  WalletCommand.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public protocol WalletCommandProtocol: AnyObject {
    func execute() throws
}
