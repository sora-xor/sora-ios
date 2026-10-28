// Released 2.3.1 populate method body; see historical-simulator-writers provenance.
import CoreData
@testable import SoraPassport

enum SimulatorReleased23AccountMapper {
    typealias DataProviderModel = AccountItem
    static func populate(entity: CDAccountItem,
                  from model: DataProviderModel,
                  using context: NSManagedObjectContext) throws {
        entity.identifier = model.address
        entity.cryptoType = Int16(model.cryptoType.rawValue)
        entity.networkType = Int16(model.networkType)
        entity.publicKey = model.publicKeyData
        entity.username = model.username
        entity.order = model.order
    }

}
