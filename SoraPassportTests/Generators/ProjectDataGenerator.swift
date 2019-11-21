/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
@testable import SoraPassport

func createRandomProject() -> ProjectData {
    let fundingTarget = Int.random(in: Int(1e3)..<Int(1e8))
    let fundingCurrent = Int.random(in: 0..<fundingTarget)
    let votes = Int.random(in: 0...fundingCurrent)
    let votedFriendsCount = Int32.random(in: 0..<100)
    let fundingDeadline = Int64(Date().timeIntervalSince1970)
    let favorite = [false, true].randomElement()!
    let favoriteCount = Int32((0...100).randomElement()!)
    let unwatched = [false, true].randomElement()!

    return ProjectData(identifier: UUID().uuidString,
                       favorite: favorite,
                       favoriteCount: favoriteCount,
                       unwatched: unwatched,
                       name: UUID().uuidString,
                       description: UUID().uuidString,
                       imageLink: URL(string: "https://google.com"),
                       link: URL(string: "https://google.com"),
                       fundingTarget: String(fundingTarget),
                       fundingCurrent: String(fundingCurrent),
                       fundingDeadline: fundingDeadline,
                       status: .open,
                       statusUpdateTime: (0...Int64.max).randomElement()!,
                       votedFriendsCount: votedFriendsCount,
                       votes: String(votes))
}
