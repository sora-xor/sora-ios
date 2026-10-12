import CoreData
import Foundation

@objc(CDSingleValue)
public final class CDSingleValue: NSManagedObject {
    @NSManaged public var identifier: String?
    @NSManaged public var payload: Data?
}
