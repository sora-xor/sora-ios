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
