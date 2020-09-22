import Foundation

extension CountryData {
    var countries: [Country] {
        return topics.map { (key, value) in
            return Country(identitfier: key,
                           name: value.name,
                           dialCode: value.dialCode,
                           supported: value.csp == .supported)
        }
    }
}
