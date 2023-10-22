// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import CoreData
import RobinHood
import IrohaCrypto

extension CDAccountItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: AccountItem.CodingKeys.self)

        let isNewItem = identifier == nil

        let address = try container.decode(String.self, forKey: .address)

        identifier = address
        username = try container.decode(String.self, forKey: .username)
        publicKey = try container.decode(Data.self, forKey: .publicKeyData)
        cryptoType = try container.decode(Int16.self, forKey: .cryptoType)
        networkType = try SS58AddressFactory().type(fromAddress: address).int16Value

        if isNewItem {
            let fetchRequest: NSFetchRequest<CDAccountItem> = CDAccountItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "%K > 0", #keyPath(CDAccountItem.order))
            let sortDescriptor = NSSortDescriptor(key: #keyPath(CDAccountItem.order), ascending: false)
            fetchRequest.sortDescriptors = [sortDescriptor]
            fetchRequest.fetchLimit = 1

            if let lastItem = try context.fetch(fetchRequest).first {
                order = lastItem.order + 1
            } else {
                order = 1
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AccountItem.CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .address)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(publicKey, forKey: .publicKeyData)
        try container.encode(cryptoType, forKey: .cryptoType)
    }
}
