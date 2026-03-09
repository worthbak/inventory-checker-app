//
//  Project.swift
//  InventoryWatch
//
//  Created on 3/9/26.
//

import Foundation

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var modifiedAt: Date
}
