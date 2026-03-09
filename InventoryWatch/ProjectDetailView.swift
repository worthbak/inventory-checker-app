//
//  ProjectDetailView.swift
//  InventoryWatch
//
//  Created on 3/9/26.
//

import SwiftUI
import Combine

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var projectStore: ProjectStore

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Project Title", text: $title)
                .textFieldStyle(.plain)
                .font(.largeTitle.weight(.bold))
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

            Divider()

            TextEditor(text: $content)
                .font(.body)
                .padding(4)
        }
        .frame(
            minWidth: 400,
            maxWidth: .infinity,
            minHeight: 300,
            maxHeight: .infinity
        )
        .onAppear {
            title = project.title
            content = project.body
        }
        .onChange(of: project) { newProject in
            title = newProject.title
            content = newProject.body
        }
        .onChange(of: title) { _ in
            scheduleSave()
        }
        .onChange(of: content) { _ in
            scheduleSave()
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            var updated = project
            updated.title = title
            updated.body = content
            projectStore.saveProject(updated)
        }
    }
}
