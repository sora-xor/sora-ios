import Foundation

extension String {
    var firstName: String? {
        let components = self.components(separatedBy: CharacterSet.whitespaces)

        guard components.count > 0 else {
            return nil
        }

        if components.count == 1 {
            return components[0]
        } else {
            return components[0..<(components.count - 1)].joined(separator: " ")
        }
    }

    var lastName: String? {
        let components = self.components(separatedBy: CharacterSet.whitespaces)

        guard components.count > 1 else {
            return nil
        }

        return components[components.count - 1]
    }

    var soraConcat: String {
        if self.count < 11 {return self}
        let prefix = self.prefix(5)
        let suffix = self.suffix(5)
        return "\(prefix)…\(suffix)"
    }
}
