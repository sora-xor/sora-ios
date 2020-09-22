import Foundation

struct ActivatedInvitationsData: Codable, Equatable {
    var invitedUsers: [InvitedUserData]
    var parentInfo: ParentInfoData?
}
