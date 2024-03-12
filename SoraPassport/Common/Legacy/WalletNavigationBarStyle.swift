//
//  WalletNavigationBarStyle.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

public protocol WalletNavigationBarStyleProtocol {
    var barColor: UIColor { get }
    var shadowColor: UIColor { get }
    var itemTintColor: UIColor { get }
    var titleColor: UIColor { get }
    var titleFont: UIFont { get }
    var backButtonImage: UIImage? { get }
}

public struct WalletNavigationBarStyle: WalletNavigationBarStyleProtocol, Equatable {
    public var barColor: UIColor
    public var shadowColor: UIColor
    public var itemTintColor: UIColor
    public var titleColor: UIColor
    public var titleFont: UIFont
    public var backButtonImage: UIImage?

    public init(barColor: UIColor,
                shadowColor: UIColor,
                itemTintColor: UIColor,
                titleColor: UIColor,
                titleFont: UIFont,
                backButtonImage: UIImage? = nil) {
        self.barColor = barColor
        self.shadowColor = shadowColor
        self.itemTintColor = itemTintColor
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.backButtonImage = backButtonImage
    }
}
