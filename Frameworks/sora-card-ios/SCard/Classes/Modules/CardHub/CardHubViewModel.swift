final class CardHubViewModel {

    var onUpdateUI: ((Iban?, Bool) -> Void)?
    var onAppStore: (() -> Void)?
    var onUpdatePhoneNumber: ((String) -> Void)?

    private let service: KYCService

    func needUpdateApp() async -> Bool {
        switch await service.verionsChangesNeeded() {
        case .major, .minor:
            return true
        case .none, .patch:
            return false
        }
    }

    init(service: KYCService) {
        self.service = service
    }

    func fetchPhoneNumber() {
        Task {
            guard let phoneNumber = await service.getUserData().phoneNumber else { return }
            await MainActor.run {
//                onUpdatePhoneNumber?(phoneNumber)
            }
        }
    }

    func fetchIban() {
        Task {
            let needUpdateApp = await needUpdateApp()
            for await state in await service.ibanStream() {
                await MainActor.run {
                    switch state {
                    case .inited:
                        onUpdateUI?(nil, needUpdateApp)
                    case .loading(let data):
                        onUpdateUI?(data??.first, needUpdateApp)
                    case .success(let data):
                        onUpdateUI?(data?.first, needUpdateApp)
                    case .failure(let failure):
                        onUpdateUI?(nil, needUpdateApp)
                        print(failure)
                    }
                }
            }
        }
    }

    func manageCard() {
        #if DEBUG
        let bundleId = "soracard.wallet.test"
        #elseif F_DEV
        let bundleId = "soracard.wallet.test"
        #elseif F_TEST
        let bundleId = "soracard.wallet.test"
        #elseif F_STAGING
        let bundleId = "soracard.wallet"
        #else
        let bundleId = "soracard.wallet"
        #endif

        let bundleUrl = "\(bundleId)://"
        let appUrl = URL(string: bundleUrl)!

        if UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
        } else {
            onAppStore?()
        }
    }
}
