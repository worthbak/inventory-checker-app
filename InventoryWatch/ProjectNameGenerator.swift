//
//  ProjectNameGenerator.swift
//  InventoryWatch
//
//  Created on 3/9/26.
//

import Foundation

struct ProjectNameGenerator {
    static let adjectives = [
        "Crimson", "Silent", "Cosmic", "Velvet", "Amber",
        "Crystal", "Lunar", "Golden", "Emerald", "Mystic",
        "Hidden", "Distant", "Ancient", "Bright", "Swift"
    ]

    static let nouns = [
        "Falcon", "Horizon", "Thunder", "Meadow", "Phoenix",
        "Cascade", "Summit", "Nebula", "Glacier", "Compass",
        "Harbor", "Beacon", "Orchid", "Prism", "Voyage"
    ]

    static func generate() -> String {
        let adj = adjectives.randomElement()!
        let noun = nouns.randomElement()!
        return "\(adj) \(noun)"
    }
}
