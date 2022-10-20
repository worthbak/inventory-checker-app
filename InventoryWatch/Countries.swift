//
//  Countries.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/10/21.
//

import Foundation

struct Country: Hashable {
    let name: String
    
    let locale: String
    let skuCode: String
    
    private static let GermanyAltCode = "FD"
    private static let CanadaAltCode = "VC"
    private static let FranceAltCode = "NF"
    private static let ItalyAltCode = "TY"
    private static let AustriaAltCode = "FD"
    private static let NetherlandsAltCodeStudio = "FN"
    private static let NetherlandsAltCodeiPad = "NF"
    
    /// Some countries have alternate country code schemes for specific products, which are accounted for here.
    func skuCode(for product: ProductType) -> String? {
        switch product {
        case .MacStudio, .StudioDisplay:
            switch self.name {
            case "Canada":
                return Country.CanadaAltCode
            case "Netherlands":
                return Country.NetherlandsAltCodeStudio
            default:
                return nil
            }
        case .iPadMiniWifi, .iPadMiniCellular, .iPad10thGenWifi, .iPad10thGenCellular:
            switch name {
            case "Germany":
                return Country.GermanyAltCode
            case "Canada":
                return Country.CanadaAltCode
            case "France":
                return Country.FranceAltCode
            case "Italy":
                return Country.ItalyAltCode
            case "Austria":
                return Country.AustriaAltCode
            case "Netherlands":
                return Country.NetherlandsAltCodeiPad
            default:
                return nil
            }
        case .AirPodsProGen2:
            switch self.name {
            case "United States", "Canada":
                return "AM"
            case "Germany", "United Kingdom", "France", "Austria", "Netherlands":
                return "ZM"
            case "Australia", "Thailand":
                return "ZA"
            case "Italy":
                return "TY"
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

let USData = Country(
    name: "United States",
    locale: "en_US",
    skuCode: "LL"
)

let Countries: [String: Country] = [
    "US": USData,
    "CA": Country(name: "Canada", locale: "en_CA", skuCode: "LL"),
    "AU": Country(name: "Australia", locale: "en_AU", skuCode: "X"),
    "DE": Country(name: "Germany", locale: "de_DE", skuCode: "D"),
    "UK": Country(name: "United Kingdom", locale: "en_GB", skuCode: "B"),
    "KR": Country(name: "South Korea", locale: "ko_KR", skuCode: "KH"),
    "HK": Country(name: "Hong Kong", locale: "en_HK", skuCode: "ZP"),
    "FR": Country(name: "France", locale: "fr_FR", skuCode: "FN"),
    "IT": Country(name: "Italy", locale: "it_IT", skuCode: "T"),
    "JP": Country(name: "Japan", locale: "ja_JP", skuCode: "J"),
    "AT": Country(name: "Austria", locale: "de_AT", skuCode: "D"),
    "NL": Country(name: "Netherlands", locale: "nl_NL", skuCode: "N"),
    "TH": Country(name: "Thailand", locale: "th_TH", skuCode: "TH"),
];

let OrderedCountries = [
    "US",
    "CA",
    "AU",
    "DE",
    "UK",
    "KR",
    "HK",
    "FR",
    "IT",
    "JP",
    "AT",
    "NL",
    "TH"
]
