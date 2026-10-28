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

extension UIColor {

    convenience init(hex: String, alpha: CGFloat = 1.0) {

        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        let offset = hexString.hasPrefix("#") ? 1 : 0
        let start = hexString.index(hexString.startIndex, offsetBy: offset)
        let hexColor = String(hexString[start...])

        let scanner = Scanner(string: hexColor)

        var color: UInt64 = 0
        scanner.scanHexInt64(&color)

        let mask = 0x000000FF
        let red     = Int(color >> 16) & mask
        let green   = Int(color >> 8) & mask
        let blue    = Int(color) & mask

        self.init(red: CGFloat(red) / 255.0,
                  green: CGFloat(green) / 255.0,
                  blue: CGFloat(blue) / 255.0,
                  alpha: alpha)
    }

    func toHexString(_ isUpperCased: Bool = true) -> String {
        var red     = CGFloat.zero
        var green   = CGFloat.zero
        var blue    = CGFloat.zero
        var alpha   = CGFloat.zero

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let rgb: Int = (Int)(red*255)<<16 | (Int)(green*255)<<8 | (Int)(blue*255)<<0
        let result = String(format: "#%06x", rgb)

        return isUpperCased ? result.uppercased() : result
    }
}
