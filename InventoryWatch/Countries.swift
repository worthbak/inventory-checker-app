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
        name: "Austrailia",
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
