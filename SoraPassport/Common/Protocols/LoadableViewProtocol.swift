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
import SoraUI

protocol LoadableViewProtocol: AnyObject {
    var loadableContentView: UIView! { get }
    var shouldDisableInteractionWhenLoading: Bool { get }

    func didStartLoading()
    func didStopLoading()
}

struct LoadableViewProtocolConstants {
    static let activityIndicatorIdentifier: String = "LoadingIndicatorIdentifier"
    static let animationDuration = 0.35
}

extension LoadableViewProtocol where Self: UIViewController {
    var loadableContentView: UIView! {
        return view
    }

    var shouldDisableInteractionWhenLoading: Bool {
        return true
    }

    func didStartLoading() {
        let activityIndicator = loadableContentView.subviews.first {
            $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
        }

        guard activityIndicator == nil else {
            return
        }

        let newIndicator = SoraLoadingViewFactory.createLoadingView()
        newIndicator.accessibilityIdentifier = LoadableViewProtocolConstants.activityIndicatorIdentifier
        newIndicator.frame = loadableContentView.bounds
        newIndicator.autoresizingMask = UIView.AutoresizingMask.flexibleWidth.union(.flexibleHeight)
        newIndicator.alpha = 0.0
        loadableContentView.addSubview(newIndicator)

        loadableContentView.isUserInteractionEnabled = !shouldDisableInteractionWhenLoading

        newIndicator.startAnimating()

        UIView.animate(withDuration: LoadableViewProtocolConstants.animationDuration) {
            newIndicator.alpha = 1.0
        }
    }

    func didStopLoading() {
        let activityIndicator = loadableContentView.subviews.first {
            $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
        }

        guard let currentIndicator = activityIndicator as? LoadingView else {
            return
        }

        currentIndicator.accessibilityIdentifier = nil
        loadableContentView.isUserInteractionEnabled = true

        UIView.animate(withDuration: LoadableViewProtocolConstants.animationDuration,
                       animations: {
                        currentIndicator.alpha = 0.0
        }, completion: { _ in
            currentIndicator.stopAnimating()
            currentIndicator.removeFromSuperview()
        })
    }
}
