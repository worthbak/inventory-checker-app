//
//  RootView.swift
//  InventoryWatch
//
//  Created on 3/9/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: ViewModel
    @EnvironmentObject var projectStore: ProjectStore

    @State private var selection: SidebarDestination? = .inventory

    var body: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView {
                SidebarView(selection: $selection)
            } detail: {
                switch selection {
                case .inventory, .none:
                    ContentView()
                case .project(let project):
                    ProjectDetailView(project: project)
                        .id(project.id)
                }
            }
        } else {
            ContentView()
        }
    }
}
