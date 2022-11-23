//
//  UIScreen+Size.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 02.06.2022.
//  Copyright © 2022 Ruslan Rezin. All rights reserved.
//

import Foundation
import UIKit

extension UIScreen {
    var isSmallSizeScreen: Bool {
        bounds.height == 568
    }
}
