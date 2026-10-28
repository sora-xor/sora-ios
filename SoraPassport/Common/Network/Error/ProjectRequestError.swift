// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

enum VoteDataError: Error {
    case projectNotFound
    case votingNotAllowed
    case votesNotEnough
    case incorrectVotesFormat

    static func error(from status: StatusData) -> VoteDataError? {
        switch status.code {
        case "PROJECT_NOT_FOUND":
            return .projectNotFound
        case "VOTING_NOT_ALLOWED":
            return .votingNotAllowed
        case "VOTES_NOT_ENOUGH":
            return .votesNotEnough
        case "INCORRECT_VOTES_VALUE_FORMAT":
            return .incorrectVotesFormat
        default:
            return nil
        }
    }
}

enum ReferendumVoteDataError: Error {
    case referendumNotFound
    case votingNotAllowed
    case votesNotEnough
    case userNotFound

    static func error(from status: StatusData) -> ReferendumVoteDataError? {
        switch status.code {
        case "REFERENDUM_NOT_FOUND":
            return .referendumNotFound
        case "VOTING_NOT_ALLOWED":
            return .votingNotAllowed
        case "VOTES_NOT_ENOUGH":
            return .votesNotEnough
        case "USER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}

enum ProjectFavoriteToggleDataError: Error {
    case projectNotFound
    case userNotFound

    static func error(from status: StatusData) -> ProjectFavoriteToggleDataError? {
        switch status.code {
        case "PROJECT_NOT_FOUND":
            return .projectNotFound
        case "USER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}

enum ProjectDetailsDataError: Error {
    case projectNotFound

    static func error(from status: StatusData) -> ProjectDetailsDataError? {
        switch status.code {
        case "PROJECT_NOT_FOUND":
            return .projectNotFound
        default:
            return nil
        }
    }
}
