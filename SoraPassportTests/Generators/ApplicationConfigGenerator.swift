import Foundation

func createRandomApplicationVersion() -> String {
    let major = Int.random(in: 1...Int.max)
    let minor = Int.random(in: 0...Int.max)
    let patch = Int.random(in: 0...Int.max)

    return "\(major).\(minor).\(patch)"
}
