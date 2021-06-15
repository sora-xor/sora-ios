import Foundation

struct ProjectFavoriteToggleEvent: EventProtocol {
    let projectId: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processProjectFavoriteToggle(event: self)
    }
}
