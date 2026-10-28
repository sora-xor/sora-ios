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

public protocol SoraMessageBuilderProtocol {
    func with(title: String?) -> Self
    func with(subtitle: String?) -> Self
    func with(image: UIImage?) -> Self
    func build() -> SoraMessageProtocol
}

public protocol MessageViewProtocol: AnyObject {
    func set(message: SoraMessageProtocol)
}

public protocol MessageViewWireframeProtocol: AnyObject {
    func show(message: SoraMessageProtocol, on window: UIWindow, animated: Bool)
    func hide(on window: UIWindow, animated: Bool)
}

public protocol MessageViewFactoryProtocol: AnyObject {
    func createMessageView() -> MessageViewProtocol
}

public protocol MessageViewDisplayProtocol: AnyObject {
    func show(message: SoraMessageProtocol, on window: UIWindow?)
}

extension MessageViewDisplayProtocol {
    public func show(message: SoraMessageProtocol, on window: UIWindow?) {
        let currentWindow = window ?? UIApplication.shared.delegate?.window as? UIWindow
        if let existingWindow = currentWindow {
            MessageViewWireframe.shared.show(message: message, on: existingWindow, animated: true)
        }
    }
}
