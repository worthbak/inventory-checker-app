//
//  Countries.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/10/21.
//

import Foundation

/// Represents metadata to pull info about products for specific countries.
///
/// Maybe accurate skucode list: https://discussions.apple.com/thread/251748775
///
/// Also can figure out sku codes by going to a country's web store and adding a non customized item to your cart and looking at the URL in the accessories upsell page:
/// Example: https://www.apple.com/nl/shop/buy-mac/macbook-pro?bfil=0&product=MK1A3N/A&step=attach
/// The item's SKU root is `MK1A3`, the `skucode` is `N` , the `storePathComponent`is  `/nl` , etc.
struct Country: Hashable {
    let name: String
    let storePathComponent: String /// Not actually used, the two letter string key in Countries is the path component that is actually used
    let skuCode: String
    let altSkuCode: String? /// for ipad in some countries
}

let USData = Country(
    name: "United States",
    storePathComponent: "",
    skuCode: "LL",
    altSkuCode: nil
)


let Countries: [String: Country] = [
    "US": USData,
    "CA": Country(
        name: "Canada",
        storePathComponent: "/ca",
        skuCode: "LL",
        altSkuCode: "VC"
    ),
    "AU": Country(
        name: "Australia",
        storePathComponent: "/au",
        skuCode: "X",
        altSkuCode: nil
    ),
    "DE": Country(
        name: "Germany",
        storePathComponent: "/de",
        skuCode: "D",
        altSkuCode: "FD"
    ),
    "NL": Country(
        name: "Netherlands",
        storePathComponent: "/nl",
        skuCode: "N",
        altSkuCode: nil
    ),
    "UK": Country(
        name: "United Kingdom",
        storePathComponent: "/uk",
        skuCode: "B",
        altSkuCode: nil
    ),
    "KR": Country(
        name: "South Korea",
        storePathComponent: "/kr",
        skuCode: "KH",
        altSkuCode: nil
     ),
    "HK": Country(
        name: "Hong Kong",
        storePathComponent: "/hk",
        skuCode: "ZP",
        altSkuCode: nil
    ),
    "SG": Country(
        name: "Singapore",
        storePathComponent: "/sg",
        skuCode: "ZP",
        altSkuCode: nil
    ),
    "JP": Country(
        name: "Japan",
        storePathComponent: "/jp",
        skuCode: "J",
        altSkuCode: nil
    ),
    "CN": Country(
        name: "China",
        storePathComponent: ".cn",
        skuCode: "CH",
        altSkuCode: nil
    ),
    "AT": Country(
        name: "Austria",
        storePathComponent: "/at",
        skuCode: "D",
        altSkuCode: nil
    ),
    "TW": Country(
        name: "Taiwan",
        storePathComponent: "/tw",
        skuCode: "TA",
        altSkuCode: nil
    ),
    //Brazil does not have in store pickup, even though they have apple stores?
//    "BR": Country(
//        name: "Brazil",
//        storePathComponent: "/br",
//        skuCode: "BZ",
//        altSkuCode: nil
//    ),
];

let OrderedCountries = [
    "US",
    "CA",
    "AU",
    "DE",
    "AT",
    "NL",
    "UK",
    "KR",
    "JP",
    "SG",
    "HK",
    "CN",
    "TW",
//    "BR", // doesn't seem to work, no in store pickup?
]
