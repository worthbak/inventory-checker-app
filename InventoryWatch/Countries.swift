//
//  Countries.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/10/21.
//

import Foundation

struct Country: Hashable {
    let name: String
    
    #warning("storePathComponent is unused currently")
    let storePathComponent: String
    let skuCode: String
    
    private static let GermanyAltCode = "FD"
    private static let CanadaAltCode = "VC"
    private static let FranceAltCode = "NF"
    private static let ItalyAltCode = "TY"
    
    /// Some countries have alternate country code schemes for specific products, which are accounted for here.
    func skuCode(for product: ProductType) -> String? {
        switch product {
        case .MacStudio, .StudioDisplay:
            return name == "Canada" ? Country.CanadaAltCode : nil
        case .iPadWifi, .iPadCellular:
            switch name {
            case "Germany":
                return Country.GermanyAltCode
            case "Canada":
                return Country.CanadaAltCode
            case "France":
                return Country.FranceAltCode
            case "Italy":
                return Country.ItalyAltCode
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
    storePathComponent: "",
    skuCode: "LL"
)

let Countries: [String: Country] = [
    "US": USData,
    "CA": Country(
        name: "Canada",
        storePathComponent: "/ca",
        skuCode: "LL"
    ),
    "AU": Country(
        name: "Australia",
        storePathComponent: "/au",
        skuCode: "X"
    ),
    "DE": Country(
        name: "Germany",
        storePathComponent: "/de",
        skuCode: "D"
    ),
    "UK": Country(
        name: "United Kingdom",
        storePathComponent: "/uk",
        skuCode: "B"
    ),
    "KR": Country(
        name: "South Korea",
        storePathComponent: "/kr",
        skuCode: "KH"
                 ),
    "HK": Country(
        name: "Hong Kong",
        storePathComponent: "/hk",
        skuCode: "ZP"
    ),
    "FR": Country(name: "France", storePathComponent: "/fr", skuCode: "FN"),
    "IT": Country(name: "Italy", storePathComponent: "/it", skuCode: "T"),
    "JP": Country(name: "Japan", storePathComponent: "/jp", skuCode: "J")
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
    "JP"
]
