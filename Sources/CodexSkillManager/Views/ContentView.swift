import CodexSkillCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: SkillStore

    var body: some View {
        NavigationSplitView {
            ProjectSidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let location = store.selectedGlobalLocation {
                GlobalSkillDetailView(store: store, location: location)
            } else if let project = store.selectedProject {
                ProjectDetailView(store: store, project: project)
            } else {
                EmptyProjectView(store: store)
            }
        }
        .alert(
            "Skill operation failed",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "Done",
            isPresented: Binding(
                get: { store.statusMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.statusMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                store.statusMessage = nil
            }
        } message: {
            Text(store.statusMessage ?? "")
        }
    }
}
