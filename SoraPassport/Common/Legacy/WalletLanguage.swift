//
//  WalletLanguage.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation


private let kDefaultsKeyName = "l10n_lang"


public enum WalletLanguage: CaseIterable {
    public static var allCases: [Self] {
        [
            .english,
            .japan,
            .russian,
            .spanishCo,
            .khmer,
            .bashkir,
            .italian,
            .french,
            .ukrainian,
            .chineseSimplified,
            .chineseTaiwan,
            .croatian,
            .estonian,
            .filipino,
            .finnish,
            .indonesian,
            .korean,
            .malay,
            .spanishEs,
            .swedish,
            .thai,
        ]
    }

    case english
    case japan
    case russian
    case spanishCo
    case khmer
    case bashkir
    case italian
    case french
    case ukrainian
    case chineseSimplified
    case chineseTaiwan
    case croatian
    case estonian
    case filipino
    case finnish
    case indonesian
    case korean
    case malay
    case spanishEs
    case swedish
    case thai
    case new(val:String)
}


public extension WalletLanguage {

    init?(rawValue: String) {
        if let int = Self.allCases.firstIndex( where: {$0.rawValue == rawValue }) {
            self = Self.allCases[int]
        } else {
            self = .new(val: rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .english: return "en"
        case .japan: return "ja"
        case .russian: return "ru"
        case .spanishCo: return "es-CO"
        case .khmer: return "km"
        case .bashkir: return "ba-RU"
        case .italian: return "it"
        case .french: return "fr"
        case .ukrainian: return "uk"
        case .chineseSimplified: return "zh-Hans"
        case .chineseTaiwan: return "zh-Hant-TW"
        case .croatian: return "hr"
        case .estonian: return "et"
        case .filipino: return "fil"
        case .finnish: return "fi"
        case .indonesian: return "id"
        case .korean: return "ko"
        case .malay: return "ms"
        case .spanishEs: return "es"
        case .swedish: return "sv"
        case .thai: return "th"
        case .new(let val): return val
        default:
            return Self.defaultLanguage.rawValue
        }
    }

    static var defaultLanguage: WalletLanguage {
        return .english
    }
}
