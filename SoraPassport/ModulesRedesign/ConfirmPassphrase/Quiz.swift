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

final class Quiz {
    let correctAnswers: [Int]
    let quizArray: [[String]]
    
    convenience init(words: [String]) {
        var generator = SystemRandomNumberGenerator()
        self.init(words: words, using: &generator)
    }

    init<Generator: RandomNumberGenerator>(words: [String], using generator: inout Generator) {
        // All BIP39 phrase lengths are supported by account import. A malformed
        // phrase must never produce a confirmation that can be completed.
        guard [12, 15, 18, 21, 24].contains(words.count) else {
            correctAnswers = []
            quizArray = []
            return
        }
        correctAnswers = words.indices.shuffled(using: &generator).prefix(3).map { $0 + 1 }
        let uniqueWords = words.reduce(into: [String]()) { result, word in
            if !result.contains(word) { result.append(word) }
        }
        quizArray = correctAnswers.map { answer in
            let correct = words[answer - 1]
            let alternatives = uniqueWords.filter { $0 != correct }.shuffled(using: &generator).prefix(2)
            return ([correct] + alternatives).shuffled(using: &generator)
        }
    }
}
