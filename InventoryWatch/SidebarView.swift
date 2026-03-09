//
//  SidebarView.swift
//  InventoryWatch
//
//  Created on 3/9/26.
//

import SwiftUI

enum SidebarDestination: Hashable {
    case inventory
    case project(Project)
}

@available(macOS 13.0, *)
struct SidebarView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var selection: SidebarDestination?

    @State private var projectToDelete: Project?
    @State private var showDeleteConfirmation = false
    @State private var renamingProject: Project?
    @State private var renameText: String = ""

    var body: some View {
        List(selection: $selection) {
            Section("Inventory") {
                NavigationLink(value: SidebarDestination.inventory) {
                    Label("Inventory", systemImage: "shippingbox")
                }
            }

            Section("Projects") {
                ForEach(projectStore.projects) { project in
                    NavigationLink(value: SidebarDestination.project(project)) {
                        if renamingProject?.id == project.id {
                            TextField("Name", text: $renameText, onCommit: {
                                commitRename(project)
                            })
                            .textFieldStyle(.plain)
                        } else {
                            Text(project.title)
                        }
                    }
                    .contextMenu {
                        Button("Rename") {
                            renamingProject = project
                            renameText = project.title
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            projectToDelete = project
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button(action: addProject) {
                    Image(systemName: "plus")
                }
                .help("New Project")
            }
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    projectStore.deleteProject(project)
                    if case .project(let selected) = selection, selected.id == project.id {
                        selection = .inventory
                    }
                }
                projectToDelete = nil
            }
        } message: {
            if let project = projectToDelete {
                Text("Are you sure you want to delete \"\(project.title)\"? This cannot be undone.")
            }
        }
    }

    private func addProject() {
        let project = projectStore.createProject()
        selection = .project(project)
    }

    private func commitRename(_ project: Project) {
        let newTitle = renameText.trimmingCharacters(in: .whitespaces)
        guard !newTitle.isEmpty else {
            renamingProject = nil
            return
        }
        var updated = project
        updated.title = newTitle
        projectStore.saveProject(updated)

        // Re-read the saved project from the store to get the correct modifiedAt
        if case .project(let selected) = selection, selected.id == project.id,
           let saved = projectStore.projects.first(where: { $0.id == project.id }) {
            selection = .project(saved)
        }

        renamingProject = nil
    }
}
