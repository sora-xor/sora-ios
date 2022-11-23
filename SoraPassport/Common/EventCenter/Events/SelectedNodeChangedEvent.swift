import Foundation

struct SelectedNodeChangedEvent: EventProtocol {

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedNodeUpdated(event: self)
    }
}
