//
//  Countries.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/10/21.
//

import Foundation

struct Country: Hashable {
    let name: String
    let storePathComponent: String
    let skuCode: String
    let altSkuCode: String? // for ipad in some countries
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
    )
];

let OrderedCountries = [
    "US",
    "CA",
    "AU",
    "DE",
    "UK",
    "KR",
    "HK",
]
