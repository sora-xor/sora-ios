// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import XCTest
@testable import SoraPassport

final class ActivityWireCodingTests: XCTestCase {
    private let t: Int64 = 9223372036854775807
    private func roundTrip(_ json: String, expected: ActivityOneOfEventData, file: StaticString = #filePath, line: UInt = #line) throws {
        let decoded = try JSONDecoder().decode(ActivityOneOfEventData.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, expected, file: file, line: line)
        let encoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try JSONDecoder().decode(ActivityOneOfEventData.self, from: encoded), expected, file: file, line: line)
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(wire["type"] as? String, original["type"] as? String, file: file, line: line)
    }
    func testFriendRegisteredWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"FriendRegistered","issuedAt":9223372036854775807,"userId":"u"}"#, expected: .friendRegistered(.init(issuedAt: t, userId: "u")))
    }
    func testVotingRightsCreditedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"VotingRightsCredited","issuedAt":9223372036854775807,"userId":"u","votingRights":"123456789012345678901234567890"}"#, expected: .votingRightsCredited(.init(issuedAt: t, userId: "u", votingRights: "123456789012345678901234567890")))
    }
    func testUserReputationChangedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"UserReputationChanged","issuedAt":9223372036854775807,"userId":"u","reputation":"9007199254740993"}"#, expected: .userReputationChanged(.init(issuedAt: t, userId: "u", reputation: "9007199254740993")))
    }
    func testUserRankChangedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"UserRankChanged","issuedAt":9223372036854775807,"rank":3,"totalRank":10}"#, expected: .userRankChanged(.init(issuedAt: t, rank: 3, totalRank: 10)))
    }
    func testProjectCreatedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"ProjectCreated","issuedAt":9223372036854775807,"projectId":"p","name":"Project","description":"Details","fundingTarget":"123.45","fundingDeadline":9007199254740993,"projectLink":"https://example.test/project","imageLink":"https://example.test/image"}"#, expected: .projectCreated(.init(issuedAt: t, projectId: "p", name: "Project", description: "Details", fundingTarget: "123.45", fundingDeadline: 9007199254740993, projectLink: "https://example.test/project", imageLink: "https://example.test/image")))
    }
    func testProjectFundedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"ProjectFunded","issuedAt":9223372036854775807,"projectId":"p"}"#, expected: .projectFunded(.init(issuedAt: t, projectId: "p")))
    }
    func testProjectClosedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"ProjectClosed","issuedAt":9223372036854775807,"projectId":"p"}"#, expected: .projectClosed(.init(issuedAt: t, projectId: "p")))
    }
    func testProjectUpdatedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"ProjectUpdated","issuedAt":9223372036854775807,"projectId":"p","name":"Changed"}"#, expected: .projectUpdated(.init(issuedAt: t, projectId: "p", name: "Changed", description: nil, fundingTarget: nil, fundingDeadline: nil, projectLink: nil, imageLink: nil)))
    }
    func testXORRewardCreditedFromProjectWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"XORRewardCreditedFromProject","issuedAt":9223372036854775807,"userId":"u","reward":"12345678901234567890.123","projectId":"p"}"#, expected: .xorRewardCreditedFromProject(.init(issuedAt: t, userId: "u", reward: "12345678901234567890.123", projectId: "p")))
    }
    func testPushTokenChangedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"PushTokenChanged","issuedAt":9223372036854775807,"userId":"u","newToken":"new"}"#, expected: .pushTokenChanged(.init(issuedAt: t, userId: "u", oldToken: nil, newToken: "new")))
    }
    func testInvitationSentWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"InvitationSent","issuedAt":9223372036854775807,"userId":"u","invitationCode":"code"}"#, expected: .invitationSent(.init(issuedAt: t, userId: "u", invitationCode: "code")))
    }
    func testSenderPermissionGrantedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"SenderPermissionGranted","issuedAt":9223372036854775807,"userId":"u","grantedTo":["friend"]}"#, expected: .senderPermissionGranted(.init(issuedAt: t, userId: "u", grantedTo: ["friend"])))
    }
    func testVotedFriendAddedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"VotedFriendAdded","issuedAt":9223372036854775807,"userId":"u","friendId":"f","projectId":"p"}"#, expected: .friendHasVoted(.init(issuedAt: t, userId: "u", friendId: "f", projectId: "p")))
    }
    func testUserVotedForProjectWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"UserVotedForProject","issuedAt":9223372036854775807,"userId":"u","projectId":"p","givenVotes":"99"}"#, expected: .userHasVoted(.init(issuedAt: t, userId: "u", projectId: "p", givenVotes: "99")))
    }
    func testPotentialRewardCalculatedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"PotentialRewardCalculated","issuedAt":9223372036854775807,"userId":"u","potentialXOR":"123.45"}"#, expected: .potentialRewardCalculated(.init(issuedAt: t, userId: "u", potentialReward: "123.45")))
    }
    func testXORBetweenUsersTransferredWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"XORBetweenUsersTransferred","issuedAt":9223372036854775807,"sender":"sender","receiver":"receiver","message":"memo","amount":"9007199254740993.001"}"#, expected: .xorTransfered(.init(issuedAt: t, source: "sender", destination: "receiver", message: "memo", amount: "9007199254740993.001")))
    }
    func testPushReceiverRegisteredWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"PushReceiverRegistered","issuedAt":9223372036854775807,"userId":"u","didsWhiteList":["d"],"pushTokens":["token"]}"#, expected: .pushReceiverRegistered(.init(issuedAt: t, userId: "u", decentralizedIdentifiers: ["d"], pushTokens: ["token"])))
    }
    func testPushTokensDeletedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"PushTokensDeleted","issuedAt":9223372036854775807,"userId":"u","deletedTokens":["old"]}"#, expected: .pushTokensRemoved(.init(issuedAt: t, userId: "u", removedTokens: ["old"])))
    }
    func testUserRequestedProjectDetailsWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"UserRequestedProjectDetails","issuedAt":9223372036854775807,"userId":"u","projectId":"p"}"#, expected: .userRequestedProjectDetails(.init(issuedAt: t, userId: "u", projectId: "p")))
    }
    func testSenderBannedWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"SenderBanned","issuedAt":9223372036854775807,"userId":"u","bannedDids":["banned"]}"#, expected: .senderBanned(.init(issuedAt: t, userId: "u", bannedIds: ["banned"])))
    }
    func testUserAgentCheckedVersionWireFieldsAndDiscriminatorRoundTrip() throws {
        try roundTrip(#"{"type":"UserAgentCheckedVersion","issuedAt":9223372036854775807,"userId":"u","appVersion":"1.2.3","platform":"iOS","supported":true}"#, expected: .userAgentCheckedVersion(.init(issuedAt: t, userId: "u", appVersion: "1.2.3", platform: "iOS", supported: true)))
    }
    func testUnknownDiscriminatorRemainsReadableAcrossSerialization() throws {
        let data = Data(#"{"type":"FutureEvent","payload":"ignored"}"#.utf8)
        let event = try JSONDecoder().decode(ActivityOneOfEventData.self, from: data)
        XCTAssertEqual(event, .unknown(.init(type: "FutureEvent")))
        let encoded = try JSONEncoder().encode(event)
        XCTAssertEqual(try JSONDecoder().decode(ActivityOneOfEventData.self, from: encoded), event)
    }
    func testRetainedUnknownEventMarkerRemainsReadable() throws {
        let event = try JSONDecoder().decode(ActivityOneOfEventData.self, from: Data(#"{"__type":"RetainedUnknown"}"#.utf8))
        XCTAssertEqual(event, .unknown(.init(type: "RetainedUnknown")))
    }
    func testKnownTransferDoesNotSilentlyDropMalformedAmountsOrIdentity() throws {
        for json in [#"{"type":"XORBetweenUsersTransferred","issuedAt":1,"sender":"s","receiver":"r","message":"memo","amount":12}"#, #"{"type":"XORBetweenUsersTransferred","issuedAt":1,"receiver":"r","message":"memo","amount":"12"}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(ActivityOneOfEventData.self, from: Data(json.utf8)))
        }
    }
    func testKnownEventRequiresAnExactInt64Timestamp() throws {
        for timestamp in ["9223372036854775808", "1.5", "null", "\"bad\""] {
            let json = "{\"type\":\"FriendRegistered\",\"issuedAt\":\(timestamp),\"userId\":\"u\"}"
            XCTAssertThrowsError(try JSONDecoder().decode(ActivityOneOfEventData.self, from: Data(json.utf8)))
        }
    }
    func testMissingDiscriminatorDoesNotBecomeAnInventedEvent() {
        XCTAssertThrowsError(try JSONDecoder().decode(ActivityOneOfEventData.self, from: Data(#"{"issuedAt":1,"userId":"u"}"#.utf8)))
    }
}
