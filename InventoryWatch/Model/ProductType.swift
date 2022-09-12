//
//  ProductType.swift
//  InventoryWatch
//
//  Created by Worth Baker on 7/27/22.
//

import Foundation

enum ProductType: String, Codable, CaseIterable, Identifiable {
    var id: Self { self }
    
    case MacBookPro
    case M2MacBookPro13
    case M2MacBookAir
    case MacStudio
    case StudioDisplay
    case iPadWifi
    case iPadCellular
    case iPhoneRegular13
    case iPhoneMini13
    case iPhoneRegular14
    case iPhonePlus14
    case iPhonePro14
    case iPhoneProMax14
    
    var presentableName: String {
        switch self {
        case .MacBookPro:
            return "MacBook Pro"
        case .M2MacBookPro13:
            return "M2 MacBook Pro 13in"
        case .M2MacBookAir:
            return "M2 MacBook Air"
        case .MacStudio:
            return "Mac Studio"
        case .StudioDisplay:
            return "Studio Display"
        case .iPadWifi:
            return "iPad mini (Wifi)"
        case .iPadCellular:
            return "iPad mini (Cellular)"
        case .iPhoneRegular13:
            return "iPhone 13"
        case .iPhoneMini13:
            return "iPhone 13 mini"
        case .iPhoneRegular14:
            return "iPhone 14"
        case .iPhonePlus14:
            return "iPhone 14 Plus"
        case .iPhonePro14:
            return "iPhone 14 Pro"
        case .iPhoneProMax14:
            return "iPhone 14 Pro Max"
        }
    }
}
