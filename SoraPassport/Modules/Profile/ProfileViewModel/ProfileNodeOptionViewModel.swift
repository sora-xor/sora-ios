//
//  ProfileNodeOptionViewModel.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 02.09.2022.
//  Copyright © 2022 Ruslan Rezin. All rights reserved.
//

import Foundation
import UIKit

struct ProfileNodeOptionViewModel: ProfileOptionViewModelProtocol {
    var cellReuseIdentifier: String {
        ProfileNodeTableViewCell.reuseIdentifier
    }

    static var cellType: Reusable.Type { ProfileTableViewCell.self }

    static var locale: Locale = Locale.current

    var option: ProfileOption

    var iconImage: UIImage?
    var title: String

    var accessoryContent: ProfileOptionAccessoriableProtocol?
    var switchContent: ProfileOptionSwitchableProtocol?

    let curentNodeName: String?


    init(by option: ProfileOption, curentNodeName: String?) {
        self.option = option
        self.curentNodeName = curentNodeName

        self.iconImage = option.iconImage()
        self.title = option.title(for: Self.locale)
    }
}
