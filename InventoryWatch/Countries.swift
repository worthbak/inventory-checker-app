//
//  Countries.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/10/21.
//

import Foundation

struct Country: Hashable {
    let name: String
    let shortcode: String
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
        case .iPadMiniWifi, .iPadMiniCellular, .iPad10thGenWifi, .iPad10thGenCellular, .iPadProM2_11in_Wifi, .iPadProM2_11in_Cellular, .iPadProM2_13in_Wifi, .iPadProM2_13in_Cellular:
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
        case .AirPodsProGen2, .ApplePencilUSBCAdapter:
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
    shortcode: "US",
    locale: "en_US",
    skuCode: "LL"
)

let AllCountries = [
    USData,
    Country(name: "Canada", shortcode: "CA", locale: "en_CA", skuCode: "LL"),
    Country(name: "Australia", shortcode: "AU", locale: "en_AU", skuCode: "X"),
    Country(name: "Germany", shortcode: "DE", locale: "de_DE", skuCode: "D"),
    Country(name: "United Kingdom", shortcode: "UK", locale: "en_GB", skuCode: "B"),
    Country(name: "South Korea", shortcode: "KR", locale: "ko_KR", skuCode: "KH"),
    Country(name: "Hong Kong", shortcode: "HK", locale: "en_HK", skuCode: "ZP"),
    Country(name: "France", shortcode: "FR", locale: "fr_FR", skuCode: "FN"),
    Country(name: "Italy", shortcode: "IT", locale: "it_IT", skuCode: "T"),
    Country(name: "Japan", shortcode: "JP", locale: "ja_JP", skuCode: "J"),
    Country(name: "Austria", shortcode: "AT", locale: "de_AT", skuCode: "D"),
    Country(name: "Netherlands", shortcode: "NL", locale: "nl_NL", skuCode: "N"),
    Country(name: "Thailand", shortcode: "TH", locale: "th_TH", skuCode: "TH"),
]
let Countries: [CountryCode: Country] = Dictionary(uniqueKeysWithValues: AllCountries.map { ($0.shortcode, $0) })
let OrderedCountries: [CountryCode] = AllCountries.map { $0.shortcode }
