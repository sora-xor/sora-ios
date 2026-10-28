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

import SoraUIKit

final class MoreMenuItem: NSObject {

    let title: String
    let subtitle: String
    let subtitleStream: AsyncStream<String?>?
    let picture: Picture?
    let circleColor: SoramitsuColor?
    let circleColorStream: AsyncStream<SoramitsuColor?>?
    let onTap: (()->())?

    init(
        title: String,
        subtitle: String,
        subtitleStream: AsyncStream<String?>? = nil,
        picture: Picture?,
        circleColor: SoramitsuColor? = nil,
        circleColorStream: AsyncStream<SoramitsuColor?>? = nil,
        onTap: (()->())? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleStream = subtitleStream
        self.picture = picture
        self.circleColor = circleColor
        self.circleColorStream = circleColorStream
        self.onTap = onTap
    }
}

extension MoreMenuItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { MoreMenuCell.self }
    var backgroundColor: SoramitsuColor { .bgPage }
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
