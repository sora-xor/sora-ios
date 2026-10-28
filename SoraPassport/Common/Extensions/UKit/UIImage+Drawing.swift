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

extension UIImage {
    public static func background(from color: UIColor,
                                  size: CGSize = CGSize(width: 1.0, height: 1.0),
                                  cornerRadius: CGFloat = 0.0,
                                  contentScale: CGFloat = 1.0) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        let bezierPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        UIGraphicsBeginImageContextWithOptions(size, false, contentScale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setFillColor(color.cgColor)
        context.addPath(bezierPath.cgPath)
        context.fillPath()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    func crop(targetSize: CGSize, cornerRadius: CGFloat, contentScale: CGFloat) -> UIImage? {
        guard size.width > 0, size.height > 0 else {
            return nil
        }

        guard targetSize.width > 0, targetSize.height > 0 else {
            return nil
        }

        var drawingSize = CGSize(width: targetSize.width, height: targetSize.width * size.height / size.width)

        if drawingSize.height < targetSize.height {
            drawingSize.height = targetSize.height
            drawingSize.width = targetSize.height * size.width / size.height
        }

        UIGraphicsBeginImageContextWithOptions(targetSize, false, contentScale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        let contextRect = CGRect(origin: .zero, size: targetSize)

        let drawingOrigin = CGPoint(x: contextRect.midX - drawingSize.width / 2.0,
                                    y: contextRect.midY - drawingSize.height / 2.0)
        let drawingRect = CGRect(origin: drawingOrigin, size: drawingSize)

        let scaledCornerRadius = cornerRadius
        let bezierPath = UIBezierPath(roundedRect: contextRect, cornerRadius: scaledCornerRadius)
        context.addPath(bezierPath.cgPath)
        context.clip()

        draw(in: drawingRect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    func tinted(with color: UIColor, opaque: Bool = false) -> UIImage? {
        let templateImage = withRenderingMode(.alwaysTemplate)

        UIGraphicsBeginImageContextWithOptions(size, false, scale)

        color.set()
        templateImage.draw(in: CGRect(origin: .zero, size: size))

        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return tintedImage
    }
}
