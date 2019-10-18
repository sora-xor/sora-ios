import Foundation
import RobinHood

extension SingleValueProvider {
    var getAndRefreshOperation: BaseOperation<Model> {
        return SingleValueOperation(provider: self)
    }
}
