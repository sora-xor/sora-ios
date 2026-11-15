//
//  ImageButton.swift
//  SoraUIKit
//
//  Created by Ivan Shlyapkin on 14.09.2022.
//

import Foundation
import UIKit

public final class ImageButton: UIButton, Molecule {

    public let sora: ImageButtonConfiguration<ImageButton>

    private var size: CGSize = .zero

    init(style: SoramitsuStyle, size: CGSize) {
        sora = ImageButtonConfiguration(style: style)
        self.size = size
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // UIButton adds its image view lazily, under anything already placed behind it.
        if let imageView { bringSubviewToFront(imageView) }
    }

    public override var isHighlighted: Bool {
        didSet { if isHighlighted != oldValue { LitMotion.press(self, pressed: isHighlighted, scale: 0.92) } }
    }
}

private extension ImageButton {
    func setup() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size.height),
            widthAnchor.constraint(equalToConstant: size.width)
        ])
    }
}

public extension ImageButton {
    convenience init(size: CGSize) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, size: size)
    }
}
