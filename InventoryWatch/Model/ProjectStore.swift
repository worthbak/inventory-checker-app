//
//  ProjectStore.swift
//  InventoryWatch
//
//  Created on 3/9/26.
//

import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []

    private let projectsDirectory: URL
    private var fileWatcher: FileWatcher?
    private var suppressWatcher = false

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    convenience init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport
            .appendingPathComponent("InventoryWatch", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
        self.init(directory: dir)
    }

    init(directory: URL) {
        projectsDirectory = directory

        ensureDirectoryExists()
        loadProjects()
        startWatching()
    }

    // MARK: - Directory Setup

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: projectsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - CRUD

    func loadProjects() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let mdFiles = files.filter { $0.pathExtension == "md" }
        var loaded: [Project] = []

        for file in mdFiles {
            if let project = parseProjectFile(at: file) {
                loaded.append(project)
            }
        }

        loaded.sort { $0.createdAt > $1.createdAt }
        projects = loaded
    }

    @discardableResult
    func createProject() -> Project {
        let now = Date()
        let project = Project(
            id: UUID(),
            title: ProjectNameGenerator.generate(),
            body: "",
            createdAt: now,
            modifiedAt: now
        )
        performSuppressedWrite { writeProjectFile(project) }
        projects.insert(project, at: 0)
        return project
    }

    func saveProject(_ project: Project) {
        var updated = project
        updated.modifiedAt = Date()
        performSuppressedWrite { writeProjectFile(updated) }

        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = updated
        }
    }

    func deleteProject(_ project: Project) {
        let fileURL = projectsDirectory.appendingPathComponent("\(project.id.uuidString).md")
        performSuppressedWrite { try? FileManager.default.removeItem(at: fileURL) }
        projects.removeAll { $0.id == project.id }
    }

    func reloadProject(id: UUID) {
        let fileURL = projectsDirectory.appendingPathComponent("\(id.uuidString).md")
        guard let project = parseProjectFile(at: fileURL) else { return }
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx] = project
        }
    }

    // MARK: - File I/O

    private func fileURL(for project: Project) -> URL {
        projectsDirectory.appendingPathComponent("\(project.id.uuidString).md")
    }

    private func performSuppressedWrite(_ work: () -> Void) {
        suppressWatcher = true
        work()
        // Brief delay before re-enabling to let kqueue event pass
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.suppressWatcher = false
        }
    }

    private func writeProjectFile(_ project: Project) {
        let created = Self.iso8601.string(from: project.createdAt)
        let modified = Self.iso8601.string(from: project.modifiedAt)

        let content = """
        ---
        id: \(project.id.uuidString)
        title: \(project.title)
        createdAt: \(created)
        modifiedAt: \(modified)
        ---
        \(project.body)
        """

        let url = fileURL(for: project)
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func parseProjectFile(at url: URL) -> Project? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: "\n")
        guard lines.first == "---" else { return nil }

        var frontMatter: [String: String] = [:]
        var bodyStartIndex: Int?

        for i in 1..<lines.count {
            if lines[i] == "---" {
                bodyStartIndex = i + 1
                break
            }
            let parts = lines[i].split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                frontMatter[key] = value
            }
        }

        guard let idString = frontMatter["id"],
              let id = UUID(uuidString: idString),
              let title = frontMatter["title"],
              let bodyStart = bodyStartIndex else { return nil }

        let createdAt = frontMatter["createdAt"].flatMap { Self.iso8601.date(from: $0) } ?? Date()
        let modifiedAt = frontMatter["modifiedAt"].flatMap { Self.iso8601.date(from: $0) } ?? Date()

        let body = lines[bodyStart...].joined(separator: "\n")

        return Project(
            id: id,
            title: title,
            body: body,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - File Watching

    private func startWatching() {
        fileWatcher = FileWatcher(directoryURL: projectsDirectory) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.suppressWatcher else { return }
                self.loadProjects()
            }
        }
        fileWatcher?.startWatching()
    }
}
