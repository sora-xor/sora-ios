import UIKit

enum VotingOneOfViewModel {
    case project(_ project: ProjectOneOfViewModel)
    case referendum(_ referendum: ReferendumViewModel)
}

extension VotingOneOfViewModel {
    var identifier: String {
        switch self {
        case .project(let project):
            return project.identifier
        case .referendum(let referendum):
            return referendum.identifier
        }
    }

    var itemSize: CGSize {
        switch self {
        case .project(let project):
            return project.itemSize
        case .referendum(let referendum):
            return referendum.layout.itemSize
        }
    }
}
