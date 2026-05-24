actor IbanStorage {
    static let shared = IbanStorage()

    var ibansStream = SCStream(wrappedValue: Loadable<[Iban]?, NetworkingError>.inited)

    func set(ibans: Loadable<[Iban]?, NetworkingError>) {
        ibansStream.wrappedValue = ibans
        print("Ibans state: \(ibans)")
    }
}
