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

import Foundation
import SwiftyBeaver

public protocol LoggerProtocol {
    func verbose(message: String, file: String, function: String, line: Int)
    func debug(message: String, file: String, function: String, line: Int)
    func info(message: String, file: String, function: String, line: Int)
    func warning(message: String, file: String, function: String, line: Int)
    func error(message: String, file: String, function: String, line: Int)
}

extension LoggerProtocol {
    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        verbose(message: message, file: file, function: function, line: line)
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message: message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message: message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message: message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message: message, file: file, function: function, line: line)
    }
}

final class Logger {
    static let shared = Logger()

    let log = SwiftyBeaver.self

    private init() {
        let destination = ConsoleDestination()

        #if F_DEV
            destination.minLevel = .verbose
        #elseif F_TEST
            destination.minLevel = .info
        #else
            destination.minLevel = .info
        #endif

        log.addDestination(destination)
    }
}

extension Logger: LoggerProtocol {
    func verbose(message: String, file: String, function: String, line: Int) {
        log.custom(level: .verbose,
                   message: message,
                   file: file,
                   function: function,
                   line: line)
    }

    func debug(message: String, file: String, function: String, line: Int) {
        log.custom(level: .debug,
                   message: message,
                   file: file,
                   function: function,
                   line: line)
    }

    func info(message: String, file: String, function: String, line: Int) {
        log.custom(level: .info,
                   message: message,
                   file: file,
                   function: function,
                   line: line)
    }

    func warning(message: String, file: String, function: String, line: Int) {
        log.custom(level: .warning,
                   message: message,
                   file: file,
                   function: function,
                   line: line)
    }

    func error(message: String, file: String, function: String, line: Int) {
        log.custom(level: .error,
                   message: message,
                   file: file,
                   function: function,
                   line: line)
    }
}
