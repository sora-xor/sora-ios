//
//  ViewController.swift
//  Sample
//
//  Created by Ivan Shlyapkin on 19.07.2022.
//

import UIKit
import SwiftUI
import SoraUIKit

class ViewController: UIViewController {

    private(set) lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10
        return stackView
    }()

    private let tabBarShapeView: TabBarShapeView = {
        let view = TabBarShapeView()
        view.backgroundColor = .red
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let tabbar: TabBar = {
        let tabBarItem = UITabBarItem(title: "Test",
                                      image: UIImage(named: "plus"),
                                      tag: 0)
        let tabBarItem1 = UITabBarItem(title: "Test",
                                      image: UIImage(named: "plus"),
                                      tag: 0)
        let tabBarItem2 = UITabBarItem(title: "Test",
                                      image: UIImage(named: "plus"),
                                      tag: 0)
        let tabBarItem3 = UITabBarItem(title: "Test",
                                      image: UIImage(named: "plus"),
                                      tag: 0)

        let view = TabBar()
        view.items = [tabBarItem, tabBarItem1, tabBarItem2, tabBarItem3]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(stackView)

        let button = SoramitsuButton(size: .large, type: .filled(.primary))
        button.sora.leftImage = UIImage(named: "plus")
        button.sora.title = "Button"
        button.sora.rightImage = UIImage(named: "plus")
        button.sora.associate(states: .default) { sora in
            sora.isHighlited = false
        }
        button.sora.associate(states: .pressed) { sora in
            sora.isHighlited = true
        }

        let button1 = SoramitsuButton(size: .large, type: .bleached(.primary))
        button1.sora.leftImage = UIImage(named: "plus")
        button1.sora.title = "Button1"
        button1.sora.rightImage = UIImage(named: "plus")
        button1.sora.associate(states: .default) { sora in
            sora.isHighlited = false
        }
        button1.sora.associate(states: .pressed) { sora in
            sora.isHighlited = true
        }

        let button2 = SoramitsuButton(size: .large, type: .tonal(.primary))
        button2.sora.leftImage = UIImage(named: "plus")
        button2.sora.title = "Button2"
        button2.sora.rightImage = UIImage(named: "plus")
        button2.sora.associate(states: .default) { sora in
            sora.isHighlited = false
        }
        button2.sora.associate(states: .pressed) { sora in
            sora.isHighlited = true
        }

        let button3 = SoramitsuButton(size: .large, type: .text(.primary))
        button3.sora.leftImage = UIImage(named: "plus")
        button3.sora.title = "Button3"
        button3.sora.rightImage = UIImage(named: "plus")
        button3.sora.associate(states: .default) { sora in
            sora.isHighlited = false
        }
        button3.sora.associate(states: .pressed) { sora in
            sora.isHighlited = true
        }

        let button4 = SoramitsuButton(size: .large, type: .outlined(.primary))
        button4.sora.leftImage = UIImage(named: "plus")
        button4.sora.title = "Button4"
        button4.sora.rightImage = UIImage(named: "plus")
        button4.sora.associate(states: .default) { sora in
            sora.isHighlited = false
        }
        button4.sora.associate(states: .pressed) { sora in
            sora.isHighlited = true
        }

        let inputField = InputField()
        inputField.sora.leftImage = UIImage(named: "burger")
        inputField.sora.titleLabelText = "title text"
        inputField.sora.textFieldPlaceholder = "Placeholder"
        inputField.sora.buttonImage = UIImage(named: "burger")
        inputField.sora.descriptionLabelText = "description"
        inputField.sora.isEnabled = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UIView.animate(withDuration: 0.3, delay: 0) {
                inputField.sora.isEnabled = true
            }
        }


        stackView.addArrangedSubview(inputField)

        stackView.addArrangedSubview(button)
        stackView.addArrangedSubview(button1)
        stackView.addArrangedSubview(button2)
        stackView.addArrangedSubview(button3)
        stackView.addArrangedSubview(button4)

        let assetView = AssetView()
        assetView.sora.firstAssetImage = UIImage(named: "XSTUSD")
        assetView.sora.titleText = "SORA Synthetic USD"
        assetView.sora.subtitleText = "1,677.98 XSTUSD"
        assetView.sora.upAmountText = "$1,677.98"
        assetView.sora.downAmountText = "+ 0.07%"
        assetView.sora.favoriteButtonImage = UIImage(named: "star")
        assetView.sora.unfavoriteButtonImage = UIImage(named: "unstar")
        assetView.sora.visibilityButtonImage = UIImage(named: "eye")
        assetView.sora.dragDropImage = UIImage(named: "burger")
        assetView.favoriteButton.sora.associate(states: .pressed) { sora in
            assetView.sora.isFavorite.toggle()
        }


        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UIView.animate(withDuration: 0.3, delay: 0) {
                assetView.sora.mode = .edit
            }
        }

        let poolView = PoolView()
        poolView.sora.firstPoolImage = UIImage(named: "XOR")
        poolView.sora.secondPoolImage = UIImage(named: "DAI")
        poolView.sora.rewardTokenImage = UIImage(named: "PSWAP")
        poolView.sora.titleText = "SORA Synthetic USD"
        poolView.sora.subtitleText = "1,677.98 XSTUSD"
        poolView.sora.upAmountText = "$1,677.98"
        poolView.sora.downAmountText = "+ 0.07%"
        poolView.sora.favoriteButtonImage = UIImage(named: "star")
        poolView.sora.unfavoriteButtonImage = UIImage(named: "unstar")
        poolView.sora.unvisibilityButtonImage = UIImage(named: "crossedOutEye")
        poolView.favoriteButton.sora.associate(states: .pressed) { sora in
            poolView.sora.isFavorite.toggle()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UIView.animate(withDuration: 0.3, delay: 0) {
                poolView.sora.mode = .edit
            }
        }

        view.addSubview(assetView)
        view.addSubview(poolView)
        view.addSubview(tabBarShapeView)
        view.addSubview(tabbar)

        NSLayoutConstraint.activate([
            assetView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            assetView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            assetView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            poolView.topAnchor.constraint(equalTo: assetView.bottomAnchor),
            poolView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            poolView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            stackView.topAnchor.constraint(equalTo: poolView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            tabBarShapeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarShapeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabBarShapeView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tabBarShapeView.heightAnchor.constraint(equalToConstant: 60),

            tabbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tabbar.heightAnchor.constraint(equalToConstant: 83)
        ])
    }

}

