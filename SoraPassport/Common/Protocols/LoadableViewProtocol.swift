// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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

        loadableContentView.isUserInteractionEnabled = shouldDisableInteractionWhenLoading

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
