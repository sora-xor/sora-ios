/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class CurrencyViewController: SelectionListViewController {
    var presenter: CurrencyPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()

        presenter.viewIsReady()
    }

    private func configureView() {
        title = R.string.localizable.currencyTitle()
    }
}

extension CurrencyViewController: CurrencyViewProtocol {}
