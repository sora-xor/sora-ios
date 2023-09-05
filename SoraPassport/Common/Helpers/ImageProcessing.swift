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
import Kingfisher
import SVGKit


final class RemoteSerializer: CacheSerializer {
    static let shared = RemoteSerializer()

    func data(with _: KFCrossPlatformImage, original: Data?) -> Data? {
        original
    }

    func image(with string: String) -> KFCrossPlatformImage? {

        guard var str = string.removingPercentEncoding else { return nil }
        let base64: Bool = str.contains("base64")
        if let index = str.firstIndex(of: ",") {
            str.removeSubrange(...index)
        }

        guard let data = base64 ? Data(base64Encoded: str) : Data(str.utf8) else { return nil }
        let targetSize = CGSize(width: 24, height: 24)
        let processor = SVGProcessor()
            |> DownsamplingImageProcessor(size: targetSize)
            |> RoundCornerImageProcessor(cornerRadius: targetSize.height / 2.0)
        let options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteSerializer.shared),
            .cacheOriginalImage,
            .diskCacheExpiration(.days(1))
        ]

        return image(with: data, options: KingfisherParsedOptionsInfo(options))
    }

    func image(with data: Data, options _: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        if let uiImage = UIImage(data: data) {
            return uiImage
        } else {
            let imsvg = SVGKImage(data: data)
            return imsvg?.uiImage ?? UIImage()
        }
    }
}

private final class SVGProcessor: ImageProcessor {
    let identifier: String = "jp.co.soramitsu.sora.kf.svg.processor"

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            return image
        case let .data(data):
            return RemoteSerializer.shared.image(with: data, options: options)
        }
    }
}
