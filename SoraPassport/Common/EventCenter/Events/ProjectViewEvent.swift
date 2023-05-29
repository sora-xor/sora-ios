import Foundation

struct ProjectViewEvent: EventProtocol {
    let projectId: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processProjectView(event: self)
    }
}
