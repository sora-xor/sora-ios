/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

//
//  ChildViewController.swift
//  SoraUI_Example
//
//  Created by ifoatov on 6/15/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class ChildViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 200).isActive = true
        view.backgroundColor = .green
    }
    
}
