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

import UIKit
import SoraUIKit

import RobinHood
import SoraFoundation

protocol SlippageToleranceViewModelProtocol: InputAccessoryViewDelegate, SlippageToleranceViewDelegate {
    func viewDidLoad()
    func doneButtonTapped()
}

final class SlippageToleranceViewModel {
    
    weak var view: SlippageToleranceViewProtocol?
    var completion: ((PolkaswapSlippage) -> Void)?
    var currentValue: PolkaswapSlippage? {
        didSet {
            view?.setupDoneButton(isEnabled: currentValue != nil)
        }
    }
    
    init(value: PolkaswapSlippage) {
        self.currentValue = value
    }
}

extension SlippageToleranceViewModel: SlippageToleranceViewModelProtocol {
    func viewDidLoad() {
        if let currentValue {
            view?.setup(tolerance: currentValue)
        }
        view?.setupDoneButton(isEnabled: currentValue != nil)
    }
    
    func doneButtonTapped() {
        guard let currentValue else { return }
        view?.controller.navigationController?.popViewController(animated: true)
        completion?(currentValue)
    }
}

extension SlippageToleranceViewModel: InputAccessoryViewDelegate {
    func didSelect(variant: Decimal) {
        guard let value = PolkaswapSlippage(percent: variant) else { return }
        view?.setup(tolerance: value)
        currentValue = value
    }
}

extension SlippageToleranceViewModel: SlippageToleranceViewDelegate {
    func slippageToleranceChanged(_ to: PolkaswapSlippage?) {
        currentValue = to
    }
}
