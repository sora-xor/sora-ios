import Foundation

struct MigrationEvent: EventProtocol {

    let service: MigrationServiceProtocol

    func accept(visitor: EventVisitorProtocol) {
        visitor.processMigration(event: self)
    }
}

struct MigrationSuccsessEvent: EventProtocol {

    let service: MigrationServiceProtocol

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSuccsessMigration(event: self)
    }
}
