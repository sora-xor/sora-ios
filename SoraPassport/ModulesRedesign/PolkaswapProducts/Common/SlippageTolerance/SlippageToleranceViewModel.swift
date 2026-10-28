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
    var completion: ((Float) -> Void)?
    var currentValue: Float {
        didSet {
            view?.setupDoneButton(isEnabled: currentValue != 0)
        }
    }
    
    init(value: Float) {
        self.currentValue = value
    }
}

extension SlippageToleranceViewModel: SlippageToleranceViewModelProtocol {
    func viewDidLoad() {
        view?.setup(tolerance: currentValue)
    }
    
    func doneButtonTapped() {
        view?.controller.navigationController?.popViewController(animated: true)
        completion?(currentValue)
    }
}

extension SlippageToleranceViewModel: InputAccessoryViewDelegate {
    func didSelect(variant: Float) {
        view?.setup(tolerance: variant)
        currentValue = variant
    }
}

extension SlippageToleranceViewModel: SlippageToleranceViewDelegate {
    func slippageToleranceChanged(_ to: Float) {
        currentValue = to
    }
}
