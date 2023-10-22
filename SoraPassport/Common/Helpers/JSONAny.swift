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

struct JSONAny: Codable {

    private var uint32: UInt32?
    private var string: String?
    private var bool: Bool?
    private var double: Double?
    private var stringArray: [String]?

    init(_ uint32: UInt32) {
        self.uint32 = uint32
    }

    init(_ string: String) {
        self.string = string
    }

    init(_ bool: Bool) {
        self.bool = bool
    }

    init(_ double: Double) {
        self.double = double
    }

    init(_ stringArray: [String]) {
        self.stringArray = stringArray
    }

    init(from decoder: Decoder) throws {
        if let uint32 = try? decoder.singleValueContainer().decode(UInt32.self) {
            self.uint32 = uint32
            return
        }

        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self.string = string
            return
        }

        if let bool = try? decoder.singleValueContainer().decode(Bool.self) {
            self.bool = bool
            return
        }

        if let double = try? decoder.singleValueContainer().decode(Double.self) {
            self.double = double
        }
        
        if let stringArray = try? decoder.singleValueContainer().decode([String].self) {
            self.stringArray = stringArray
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let anyValue = self.value() {
            if let value = anyValue as? UInt32 {
                try container.encode(value)
                return
            }

            if let value = anyValue as? String {
                try container.encode(value)
                return
            }

            if let value = anyValue as? Bool {
                try container.encode(value)
                return
            }

            if let value = anyValue as? Double {
                try container.encode(value)
                return
            }
            
            if let value = anyValue as? [String] {
                try container.encode(value)
                return
            }
        }

        try container.encodeNil()
    }

    func value() -> Any? {
        return self.uint32 ?? self.string ?? self.bool ?? self.double ?? self.stringArray
    }
}
