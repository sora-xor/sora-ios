//
//  DeltaPriceBuilder.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 9/26/23.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import sorawallet
import SoraUIKit
import SoraFoundation

struct DeltaPriceBuilder {
    private let priceTrendService: PriceTrendServiceProtocol = PriceTrendService()
    
    func build(fiatData: [FiatData], marketCapInfo: Set<MarketCapInfo>, assetId: String) -> SoramitsuTextItem? {
        let deltaPrice = priceTrendService.getPriceTrend(for: assetId,
                                                         fiatData: fiatData,
                                                         marketCapInfo: marketCapInfo)
        
        var deltaArributedText: SoramitsuTextItem?
        if let deltaPrice {
            let deltaText = "\(NumberFormatter.fiat.stringFromDecimal(deltaPrice * 100) ?? "")%"
            let deltaTextReversed = "%\(NumberFormatter.fiat.stringFromDecimal(deltaPrice * 100) ?? "")"
            let deltaColor: SoramitsuColor = deltaPrice > 0 ? .statusSuccess : .statusError
            let isRTL = LocalizationManager.shared.isRightToLeft
            deltaArributedText = SoramitsuTextItem(text: isRTL ? deltaTextReversed : deltaText,
                                                   attributes: SoramitsuTextAttributes(fontData: FontType.textBoldXS,
                                                                                       textColor: deltaColor,
                                                                                       alignment: .right))
        }
        
        return deltaArributedText
    }
}
