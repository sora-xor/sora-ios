//
//  ExploreScrollViewDelegate.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 12/3/23.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

protocol ExploreScrollViewDelegateOutput: AnyObject {
    func changeCurrentPage(to number: Int)
}

final class ExploreScrollViewDelegate: NSObject, UIScrollViewDelegate {
    
    weak var delegate: ExploreScrollViewDelegateOutput?
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        let pageFraction = scrollView.contentOffset.x / pageWidth
        guard !(pageFraction.isNaN || pageFraction.isInfinite) else { return }
        
        let currentPage = Int((round(pageFraction)))
       
        delegate?.changeCurrentPage(to: currentPage)
    }
}
