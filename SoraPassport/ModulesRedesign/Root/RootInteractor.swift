// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SoraKeystore
import IrohaCrypto

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol
    let migrators: [Migrating]
    var securityLayerInteractor: SecurityLayerInteractorInputProtocol
    var networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         migrators: [Migrating],
         securityLayerInteractor: SecurityLayerInteractorInputProtocol,
         networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?) {
        self.settings = settings
        self.keystore = keystore
        self.migrators = migrators
        self.securityLayerInteractor = securityLayerInteractor
        self.networkAvailabilityLayerInteractor = networkAvailabilityLayerInteractor
        checkLegacyUpdate()
    }

    private func configureSecurityService() {
        securityLayerInteractor.setup()
    }

    private func configureDeepLinkService() {
        let invitationLinkService = InvitationLinkService(settings: settings)
        DeepLinkService.shared.setup(children: [invitationLinkService])
    }

    private func configureNetworkAvailabilityService() {
        networkAvailabilityLayerInteractor?.setup()
    }

    private func setupURLHandlingService() {
        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

//        let callbackUrl = applicationConfig.purchaseRedirect
//        let purchaseHandler = PurchaseCompletionHandler(callbackUrl: callbackUrl,
//                                                        eventCenter: eventCenter)

        URLHandlingService.shared.setup(children: [/*purchaseHandler,*/ keystoreImportService])
    }

    var legacyImportInteractor: AccountImportInteractorInputProtocol?

    private func checkLegacyUpdate() {
        if let legacySeed = try? keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue),
           let mnemonic = try? IRMnemonicCreator(language: .english).mnemonic(fromEntropy: legacySeed),
           let importInteractor = AccountImportViewFactory.createSilentImportInteractor() {

            let username = settings.string(for: KeystoreTag.legacyUsername.rawValue) ?? ""
            let request = AccountImportMnemonicRequest(mnemonic: mnemonic.toString(),
                                                       username: username,
                                                       networkType: .sora,
                                                       derivationPath: "",
                                                       cryptoType: .sr25519)
            legacyImportInteractor = importInteractor
            importInteractor.importAccountWithMnemonic(request: request)
        }
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        do {
            if !settings.hasSelectedAccount {
                try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)

                presenter?.didDecideOnboarding()
                return
            } else {
                try? keystore.deleteKeyIfExists(for: KeystoreTag.legacyEntropy.rawValue)
            }

            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            presenter?.didDecideBroken()
        }
    }

    private func runMigrators() {
        migrators.forEach { migrator in
            do {
                try migrator.migrate()
            } catch {
                Logger.shared.error(error.localizedDescription)
            }
        }
    }

    func setup() {
        setupURLHandlingService()
        configureSecurityService()
        configureNetworkAvailabilityService()
        configureDeepLinkService()
        runMigrators()

    }
}
