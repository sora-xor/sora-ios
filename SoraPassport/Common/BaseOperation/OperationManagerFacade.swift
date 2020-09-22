import Foundation
import RobinHood

final class OperationManagerFacade {
    static let sharedManager: OperationManagerProtocol = OperationManager()
    static let transfer: OperationManagerProtocol = OperationManager()
}
