//
//  ProductType.swift
//  InventoryWatch
//
//  Created by Worth Baker on 7/27/22.
//

import Foundation

enum ProductCategories: String, Codable, CaseIterable, Identifiable {
    var id: Self { self }
    
    case Mac, iPad, iPhone, AppleWatch, Accessories
    
    var products: [ProductType] {
        switch self {
        case .Mac:
            return [.MacStudio, .M2MacBookPro13, .M2MacBookAir, .MacBookPro]
        case .iPad:
            return [
                .iPadMiniWifi,
                .iPadMiniCellular,
                .iPad10thGenWifi,
                .iPad10thGenCellular,
                .iPadProM2_11in_Wifi,
                .iPadProM2_11in_Cellular,
                .iPadProM2_13in_Wifi,
                .iPadProM2_13in_Cellular
            ]
        case .iPhone:
            return [
                .iPhoneRegular13,
                .iPhoneMini13,
                .iPhoneRegular14,
                .iPhonePlus14,
                .iPhonePro14,
                .iPhoneProMax14
            ]
        case .AppleWatch:
            return [.AppleWatchUltra]
        case .Accessories:
            return [.StudioDisplay, .AirPodsProGen2, .ApplePencilUSBCAdapter]
        }
    }
}

enum ProductType: String, Codable, CaseIterable, Identifiable {
    var id: Self { self }
    
    case MacBookPro
    case M2MacBookPro13
    case M2MacBookAir
    case MacStudio
    
    case StudioDisplay
    case AirPodsProGen2
    #warning("this does not work in all countries (yet)")
    case ApplePencilUSBCAdapter
    
    case iPadMiniWifi
    case iPadMiniCellular
    case iPad10thGenWifi
    case iPad10thGenCellular
    case iPadProM2_11in_Wifi
    case iPadProM2_11in_Cellular
    case iPadProM2_13in_Wifi
    case iPadProM2_13in_Cellular
    
    case iPhoneRegular13
    case iPhoneMini13
    case iPhoneRegular14
    case iPhonePlus14
    case iPhonePro14
    case iPhoneProMax14
    
    case AppleWatchUltra
    
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
        case .AirPodsProGen2:
            return "AirPods Pro"
        case .ApplePencilUSBCAdapter:
            return "USB-C to Apple Pencil Adapter"
            
        case .iPadMiniWifi:
            return "iPad mini (Wifi)"
        case .iPadMiniCellular:
            return "iPad mini (Cellular)"
        case .iPad10thGenWifi:
            return "iPad (10th Gen) (Wifi)"
        case .iPad10thGenCellular:
            return "iPad (10th Gen) (Cellular)"
        case .iPadProM2_11in_Wifi:
            return "M2 iPad Pro 11in (Wifi)"
        case .iPadProM2_11in_Cellular:
            return "M2 iPad Pro 11in (Cellular)"
        case .iPadProM2_13in_Wifi:
            return "M2 iPad Pro 12.9in (Wifi)"
        case .iPadProM2_13in_Cellular:
            return "M2 iPad Pro 12.9in (Cellular)"
            
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
            
        case.AppleWatchUltra:
            return "Apple Watch Ultra"
        }
    }
}
