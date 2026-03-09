//
//  ProjectNameGeneratorTests.swift
//  InventoryWatchTests
//
//  Created on 3/9/26.
//

import XCTest
@testable import InventoryWatch

final class ProjectNameGeneratorTests: XCTestCase {

    func testGenerateReturnsNonEmptyString() {
        let name = ProjectNameGenerator.generate()
        XCTAssertFalse(name.isEmpty)
    }

    func testGenerateReturnsTwoWords() {
        let name = ProjectNameGenerator.generate()
        let words = name.split(separator: " ")
        XCTAssertEqual(words.count, 2, "Generated name should be two words: '\(name)'")
    }

    func testGenerateUsesKnownAdjectives() {
        let name = ProjectNameGenerator.generate()
        let adjective = String(name.split(separator: " ")[0])
        XCTAssertTrue(
            ProjectNameGenerator.adjectives.contains(adjective),
            "Adjective '\(adjective)' should be from the known list"
        )
    }

    func testGenerateUsesKnownNouns() {
        let name = ProjectNameGenerator.generate()
        let noun = String(name.split(separator: " ")[1])
        XCTAssertTrue(
            ProjectNameGenerator.nouns.contains(noun),
            "Noun '\(noun)' should be from the known list"
        )
    }

    func testAdjectivesAndNounsAreNonEmpty() {
        XCTAssertFalse(ProjectNameGenerator.adjectives.isEmpty)
        XCTAssertFalse(ProjectNameGenerator.nouns.isEmpty)
    }
}
