import Foundation

final class MigrationInteractor {
    weak var presenter: MigrationPresenter!
    let migrationService: MigrationServiceProtocol

    init(migrationService: MigrationServiceProtocol) {
        self.migrationService = migrationService
    }

    func startMigration() {
        migrationService.requestMigration(completion: { [weak self] result in
            switch result {
            case .success(_):
                print("migration seems to be ok")
            case .failure(_):
                self?.presenter.retry()
            }
        })
    }
}
