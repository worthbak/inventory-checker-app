//
//  ProjectStoreTests.swift
//  InventoryWatchTests
//
//  Created on 3/9/26.
//

import XCTest
@testable import InventoryWatch

@MainActor
final class ProjectStoreTests: XCTestCase {

    private var testDirectory: URL!
    private var store: ProjectStore!

    override func setUp() async throws {
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InventoryWatchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        store = ProjectStore(directory: testDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testDirectory)
        store = nil
    }

    // MARK: - Create

    func testCreateProjectAddsToList() {
        XCTAssertTrue(store.projects.isEmpty)
        store.createProject()
        XCTAssertEqual(store.projects.count, 1)
    }

    func testCreateProjectReturnsValidProject() {
        let project = store.createProject()
        XCTAssertFalse(project.title.isEmpty)
        XCTAssertFalse(project.id.uuidString.isEmpty)
    }

    func testCreateProjectWritesFile() {
        let project = store.createProject()
        let fileURL = testDirectory.appendingPathComponent("\(project.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Save

    func testSaveProjectUpdatesTitle() {
        var project = store.createProject()
        project.title = "Updated Title"
        store.saveProject(project)

        let saved = store.projects.first(where: { $0.id == project.id })
        XCTAssertEqual(saved?.title, "Updated Title")
    }

    func testSaveProjectUpdatesModifiedAt() {
        let project = store.createProject()
        let originalModified = project.modifiedAt

        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        var updated = project
        updated.body = "New content"
        store.saveProject(updated)

        let saved = store.projects.first(where: { $0.id == project.id })
        XCTAssertNotNil(saved)
        XCTAssertGreaterThan(saved!.modifiedAt, originalModified)
    }

    // MARK: - Delete

    func testDeleteProjectRemovesFromList() {
        let project = store.createProject()
        XCTAssertEqual(store.projects.count, 1)

        store.deleteProject(project)
        XCTAssertTrue(store.projects.isEmpty)
    }

    func testDeleteProjectRemovesFile() {
        let project = store.createProject()
        let fileURL = testDirectory.appendingPathComponent("\(project.id.uuidString).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        store.deleteProject(project)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Load (round-trip)

    func testLoadProjectsRoundTrip() {
        let project = store.createProject()
        var updated = project
        updated.title = "Persisted"
        updated.body = "Some body text"
        store.saveProject(updated)

        // Create a new store pointing at same directory to test loading
        let freshStore = ProjectStore(directory: testDirectory)
        XCTAssertEqual(freshStore.projects.count, 1)

        let loaded = freshStore.projects.first
        XCTAssertEqual(loaded?.id, project.id)
        XCTAssertEqual(loaded?.title, "Persisted")
        XCTAssertEqual(loaded?.body, "Some body text")
    }

    func testLoadProjectsIgnoresNonMdFiles() throws {
        store.createProject()

        // Write a non-md file
        let txtFile = testDirectory.appendingPathComponent("notes.txt")
        try "not a project".write(to: txtFile, atomically: true, encoding: .utf8)

        let freshStore = ProjectStore(directory: testDirectory)
        XCTAssertEqual(freshStore.projects.count, 1)
    }

    func testLoadProjectsSortsByCreatedAtDescending() {
        let p1 = store.createProject()
        Thread.sleep(forTimeInterval: 0.01)
        let p2 = store.createProject()

        // p2 was created later, should appear first
        XCTAssertEqual(store.projects.first?.id, p2.id)
        XCTAssertEqual(store.projects.last?.id, p1.id)
    }

    // MARK: - File format

    func testFileFormatContainsFrontMatter() throws {
        let project = store.createProject()
        let fileURL = testDirectory.appendingPathComponent("\(project.id.uuidString).md")
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(content.hasPrefix("---\n"), "File should start with frontmatter delimiter")
        XCTAssertTrue(content.contains("id: \(project.id.uuidString)"))
        XCTAssertTrue(content.contains("title: \(project.title)"))
        XCTAssertTrue(content.contains("createdAt:"))
        XCTAssertTrue(content.contains("modifiedAt:"))
    }

    func testBodyWithColonInTitleRoundTrips() {
        var project = store.createProject()
        project.title = "My Project: The Sequel"
        store.saveProject(project)

        let freshStore = ProjectStore(directory: testDirectory)
        let loaded = freshStore.projects.first(where: { $0.id == project.id })
        XCTAssertEqual(loaded?.title, "My Project: The Sequel")
    }

    func testMultilineBodyRoundTrips() {
        var project = store.createProject()
        project.body = "Line 1\nLine 2\nLine 3"
        store.saveProject(project)

        let freshStore = ProjectStore(directory: testDirectory)
        let loaded = freshStore.projects.first(where: { $0.id == project.id })
        XCTAssertEqual(loaded?.body, "Line 1\nLine 2\nLine 3")
    }

    func testEmptyBodyRoundTrips() {
        let project = store.createProject()
        // New project has empty body by default
        let freshStore = ProjectStore(directory: testDirectory)
        let loaded = freshStore.projects.first(where: { $0.id == project.id })
        XCTAssertEqual(loaded?.body, "")
    }
}
