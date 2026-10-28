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

protocol DeviceInfoFactoryProtocol {
    func createDeviceInfo() -> DeviceInfo
}

struct DeviceInfoFactory: DeviceInfoFactoryProtocol {
    func createDeviceInfo() -> DeviceInfo {
        let screen = UIScreen.main
        let device = UIDevice.current
        let locale = Locale.current
        let timezone = TimeZone.current

        return DeviceInfo(model: device.model,
                          osVersion: device.systemVersion,
                          screenWidth: Int(screen.bounds.width),
                          screenHeight: Int(screen.bounds.height),
                          language: locale.languageCode ?? "",
                          country: locale.regionCode ?? "",
                          timezone: timezone.secondsFromGMT() / 3600)
    }
}
