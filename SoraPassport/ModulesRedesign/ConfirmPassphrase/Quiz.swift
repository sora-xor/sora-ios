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
    
    init(words: [String]) {
        correctAnswers = [ Int.random(in: 1..<13), Int.random(in: 1..<13), Int.random(in: 1..<13)]
        
        var quizArray: [[String]] = []
        
        for answer in correctAnswers {
            let quizVariants = Int.getUniqueRandomNumbers(min: 1, max: 11, count: 3, requiredElement: answer)
            let quiz = quizVariants.map { words[$0 - 1] }
            quizArray.append(quiz)
        }
        
        self.quizArray = quizArray
    }
}
