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

import Foundation
import SoraFoundation

extension NumberFormatter {
    static var vote: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 0
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.usesGroupingSeparator = true
        return numberFormatter
    }

    static var amount: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }
    
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()

    static var historyAmount: NumberFormatter {
        let formatter = Self.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }

    static var reward: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }

    static var poolShare: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }

    static var anyInteger: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 0
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.usesGroupingSeparator = true
        return numberFormatter
    }
    
    static var fiat: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static var polkaswapBalance: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static var apy: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 7
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static var cryptoAssets: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static func inputedAmoutFormatter(with precision: UInt32) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = Int(precision)
        formatter.roundingMode = .floor
        formatter.usesGroupingSeparator = true
        formatter.alwaysShowsDecimalSeparator = false
        formatter.locale = Locale.current
        return formatter
    }
}
