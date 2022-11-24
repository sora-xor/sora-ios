/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit

protocol Reusable: UITableViewCell {
    static var reuseIdentifier: String { get }
    func bind(viewModel: CellViewModel)
}

extension Reusable {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
    
    func bind(viewModel: CellViewModel) {
    }
}

protocol CellViewModel {
    var cellReuseIdentifier: String { get }
}

protocol ReusableHeader: UITableViewHeaderFooterView {
    static var reuseIdentifier: String { get }
    func bind(viewModel: CellViewModel)
}

extension ReusableHeader {
    static var reuseIdentifier: String {
        return String(describing: self)
    }

    func bind(viewModel: CellViewModel) {
    }
}
