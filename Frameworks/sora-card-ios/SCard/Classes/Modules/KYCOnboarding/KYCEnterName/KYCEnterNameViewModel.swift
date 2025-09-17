import Foundation

final class KYCEnterNameViewModel {
    var onContinue: ((KYCUserDataModel) -> Void)?

    init(data: KYCUserDataModel) {
        self.data = data
    }

    let data: KYCUserDataModel

    var isContinueEnabled: Bool {
        !(data.name.isEmpty || data.lastname.isEmpty)
    }
}
