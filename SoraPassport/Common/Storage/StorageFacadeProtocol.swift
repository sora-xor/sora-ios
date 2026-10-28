// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RobinHood
import CoreData

protocol StorageFacadeProtocol: AnyObject {
    var databaseService: CoreDataServiceProtocol { get }

    func createRepository<T, U>(filter: NSPredicate?,
                                sortDescriptors: [NSSortDescriptor],
                                mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject
}

extension StorageFacadeProtocol {
    func createRepository<T, U>(mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable, U: NSManagedObject {
        return createRepository(filter: nil, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>() -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>(filter: NSPredicate) -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: filter, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>(sortDescriptors: [NSSortDescriptor]) -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, sortDescriptors: sortDescriptors, mapper: mapper)
    }

    func createRepository<T, U>(filter: NSPredicate, sortDescriptors: [NSSortDescriptor])
        -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: filter, sortDescriptors: sortDescriptors, mapper: mapper)
    }
}
