/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
@testable import SoraPassport

func createRandomUserId() -> String {
    let identifier = (0..<20).map({ _ in
        return String((0..<10).randomElement()!)
    }).joined()

    return "did:sora:\(identifier)"
}

func createRandomPhoneNumber() -> String {
    let length = (4..<15).randomElement()!
    return (0..<length).map({ _ in
        return String((0..<10).randomElement()!)
    }).joined()
}

func createRandomUserValue(for userId: String) -> UserValuesData {
    return UserValuesData(userId: userId,
                          invitationCode: Constants.dummyInvitationCode)
}

func createRandomUser() -> UserData {
    let userId = createRandomUserId()
    let parentId = createRandomUserId()
    let userValues = createRandomUserValue(for: userId)

    return UserData(userId: userId,
                    firstName: UUID().uuidString,
                    lastName: UUID().uuidString,
                    country: UUID().uuidString,
                    phone: createRandomPhoneNumber(),
                    inviteAcceptExpirationMoment: Int64(Date().timeIntervalSince1970),
                    parentId: parentId,
                    status: "REGISTERED",
                    services: [],
                    values: userValues)
}

func createRandomInvitedUserData() -> InvitedUserData {
    return InvitedUserData(userId: createRandomUserId(),
                           firstName: UUID().uuidString,
                           lastName: UUID().uuidString)
}

func createRandomParentInfo() -> ParentInfoData {
    return ParentInfoData(firstName: UUID().uuidString,
                          lastName: UUID().uuidString)
}

func createRandomActivatedInvitationsData() -> ActivatedInvitationsData {
    let length = (0..<10).randomElement()!
    let invitedUsers = (0..<length).map { _ in createRandomInvitedUserData() }

    return ActivatedInvitationsData(invitedUsers: invitedUsers,
                                    parentInfo: createRandomParentInfo())
}
