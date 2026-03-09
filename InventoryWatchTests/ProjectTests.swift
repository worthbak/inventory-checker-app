//
//  ProjectTests.swift
//  InventoryWatchTests
//
//  Created on 3/9/26.
//

import XCTest
@testable import InventoryWatch

final class ProjectTests: XCTestCase {

    func testProjectIdentifiable() {
        let id = UUID()
        let now = Date()
        let project = Project(id: id, title: "Test", body: "Body", createdAt: now, modifiedAt: now)
        XCTAssertEqual(project.id, id)
        XCTAssertEqual(project.title, "Test")
        XCTAssertEqual(project.body, "Body")
    }

    func testProjectCodableRoundTrip() throws {
        let now = Date()
        let project = Project(id: UUID(), title: "Codable Test", body: "Some body", createdAt: now, modifiedAt: now)

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.id, project.id)
        XCTAssertEqual(decoded.title, project.title)
        XCTAssertEqual(decoded.body, project.body)
    }

    func testProjectHashable() {
        let now = Date()
        let id = UUID()
        let p1 = Project(id: id, title: "A", body: "", createdAt: now, modifiedAt: now)
        let p2 = Project(id: id, title: "A", body: "", createdAt: now, modifiedAt: now)
        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.hashValue, p2.hashValue)
    }
}
