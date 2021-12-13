import Foundation

struct ActivityUserData: Codable, Equatable {
    var firstName: String
    var lastName: String
}

struct ActivityProjectData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case name = "projectName"
    }

    var name: String
}

struct ActivityData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case events = "activity"
        case users = "usersDict"
        case projects = "projectsDict"
    }

    var events: [ActivityOneOfEventData]
    var users: [String: ActivityUserData]?
    var projects: [String: ActivityProjectData]?
}

extension ActivityData {
    static var empty: ActivityData {
        return ActivityData(events: [], users: nil, projects: nil)
    }
}
