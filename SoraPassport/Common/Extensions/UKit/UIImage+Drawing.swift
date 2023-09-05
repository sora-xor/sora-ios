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
