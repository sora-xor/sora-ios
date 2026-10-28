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

public class MessageViewFactory: MessageViewFactoryProtocol {
    public func createMessageView() -> MessageViewProtocol {
        let messageView = MessageView()
        messageView.backgroundColor = R.color.baseBackgroundHover()!

        messageView.contentInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        messageView.horizontalSpacing = 12.0
        messageView.verticalSpacing = 2.0

        messageView.titleColor = UIColor.white
        messageView.titleFont = UIFont.styled(for: .paragraph1)

        messageView.subtitleColor = UIColor.white
        messageView.subtitleFont = UIFont.styled(for: .paragraph2)

        messageView.imageTintColor = UIColor.white

        return messageView
    }
}
