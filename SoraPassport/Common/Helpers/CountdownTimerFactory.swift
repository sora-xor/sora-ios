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

import Foundation
import SoraFoundation

enum TimerNotificationInterval: TimeInterval {
    case second = 1.0
    case minute = 60.0
}

protocol CountdownFactoryProtocol {
    func createTimer(with delegate: CountdownTimerDelegate,
                     notificationInterval: TimeInterval) -> CountdownTimerProtocol
}

extension CountdownFactoryProtocol {
    func createTimer(with delegate: CountdownTimerDelegate) -> CountdownTimerProtocol {
        return createTimer(with: delegate,
                           notificationInterval: TimerNotificationInterval.second.rawValue)
    }
}

struct CountdownTimerFactory: CountdownFactoryProtocol {
    func createTimer(with delegate: CountdownTimerDelegate,
                     notificationInterval: TimeInterval) -> CountdownTimerProtocol {
        return CountdownTimer(delegate: delegate,
                              applicationHander: ApplicationHandler(),
                              notificationInterval: notificationInterval)
    }
}
