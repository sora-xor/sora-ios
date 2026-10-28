// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import CoreGraphics
import UIKit
import Combine

protocol ReferrerLinkViewModelProtocol {
    var isEnabled: Bool? { get}
    var interactor: InputLinkInteractorInputProtocol? { get }
}

final class ReferrerLinkViewModel: ReferrerLinkViewModelProtocol {
    
    @Published var isEnabled: Bool?
    weak var interactor: InputLinkInteractorInputProtocol?
    var address: String = ""

    init(isEnabled: Bool?,
         interactor: InputLinkInteractorInputProtocol?) {
        self.isEnabled = isEnabled
        self.interactor = interactor
    }
    
    func userChangeTextField(with text: String) {
        address = text.components(separatedBy: "/").last ?? ""
        let isCurrentUser = interactor?.isCurrentUserAddress(with: address) ?? false
        let isEnableButton = !isCurrentUser && (interactor?.getAccountId(from: address) != nil)
        isEnabled = isEnableButton
    }
    
    func userTappedOnActivate() {
        guard let accountId = interactor?.getAccountId(from: address)?.toHex(includePrefix: true) else { return }
        interactor?.sendSetReferrerRequest(with: accountId)
    }
}

extension ReferrerLinkViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return ReferrerLinkCell.reuseIdentifier
    }
}

