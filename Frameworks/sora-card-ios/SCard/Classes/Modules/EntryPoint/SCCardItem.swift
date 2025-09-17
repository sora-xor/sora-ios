import SoraUIKit

public final class SCCardItem: NSObject {

    var onClose: (() -> Void)?
    var onCard: (() -> Void)?
    var onUpdate: ((KYCUserStatus, Int?) -> Void)?
    var userStatus: KYCUserStatus = .none
    var availableBalance: Int?
    var needUpdate = false
    private let service: KYCService

    public init(
        service: SCard,
        onClose: (() -> Void)?,
        onCard: (() -> Void)?
    ) {
        self.onClose = onClose
        self.onCard = onCard
        self.service = service.service
        super.init()

        Task { [weak self] in

            switch await self?.service.verionsChangesNeeded() ?? .none {
            case .major, .minor, .patch:
                self?.needUpdate = true
            case .none:
                self?.needUpdate = false
            }
            for await userStatus in service.userStatusStream {
                self?.userStatus = userStatus
                await self?.updateBalance()
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.onUpdate?(userStatus, self.availableBalance)
                }
            }
        }
    }

    private func updateBalance() async {
        await service.updateIban()
        self.availableBalance = await service.iban()?.availableBalance
    }
}

extension SCCardItem: SoramitsuTableViewItemProtocol {
    public var cellType: AnyClass { SCCardCell.self }
    public var clipsToBounds: Bool { false }
}
