extension KYCService {

    func updateCountries() async -> Result<[SCCountry], NetworkingError> {
        let request = APIRequest(method: .get, endpoint: SCEndpoint.countryCodes)
        let response: Result<[String: SCCountryModel], NetworkingError> = await client.performDecodable(
            request: request,
            withAuthorization: false
        )

        switch response {
        case .success(let countryMap):
            let countries = countryMap.sorted(by: { $0.value.name < $1.value.name }) .map {
                SCCountry(
                    name: $0.value.name,
                    code: $0.key,
                    dialCode: $0.value.dialCode
                )
            }
            self.countries = countries
            return .success(countries)
        case .failure(let failure):
            return .failure(failure)
        }
    }
}

extension SCCountry {
    static let usa = SCCountry(name: "United States", code: "US", dialCode: "+1")
}

struct SCCountry {
    let name: String
    let code: String
    let dialCode: String

    var originalName: String {
        let localeId = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
        return NSLocale(localeIdentifier: code).displayName(forKey: NSLocale.Key.identifier, value: localeId) ?? name
    }

    var localizedName: String {
        let currentLocaleID = NSLocale.current.identifier
        let localeId = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
        return NSLocale(localeIdentifier: currentLocaleID).displayName(forKey: NSLocale.Key.identifier, value: localeId) ?? name
    }

    var flagEmoji: String {
        func isLowercaseASCIIScalar(_ scalar: Unicode.Scalar) -> Bool {
            return scalar.value >= 0x61 && scalar.value <= 0x7A
        }

        func regionalIndicatorSymbol(for scalar: Unicode.Scalar) -> Unicode.Scalar {
            precondition(isLowercaseASCIIScalar(scalar))

            // 0x1F1E6 marks the start of the Regional Indicator Symbol range and corresponds to 'A'
            // 0x61 marks the start of the lowercase ASCII alphabet: 'a'
            return Unicode.Scalar(scalar.value + (0x1F1E6 - 0x61))!
        }

        let lowercasedCode = code.lowercased()
        guard lowercasedCode.count == 2 else { return "" }
        guard lowercasedCode.unicodeScalars.reduce(true, { accum, scalar in accum && isLowercaseASCIIScalar(scalar) }) else { return "" }

        let indicatorSymbols = lowercasedCode.unicodeScalars.map({ regionalIndicatorSymbol(for: $0) })
        return String(indicatorSymbols.map({ Character($0) }))
    }

    var flag: UIImage {
        flagEmoji.image(withAttributes: [
                .backgroundColor: UIColor.red,
                .font: UIFont.systemFont(ofSize: 24 * 1.85)
            ], size: nil
        ) ?? .init()
    }
}

struct SCCountryModel: Codable {
    let name: String
    let dialCode: String

    enum CodingKeys: String, CodingKey {
        case name
        case dialCode = "dial_code"
    }
}
