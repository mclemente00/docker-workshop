import SwiftUI
import SwiftData

@main
struct MeetingNotesApp: App {
    let modelContainer: ModelContainer
    let liveActivityCoordinator: LiveActivityCoordinator
    let transcriptionCoordinator: TranscriptionCoordinator

    init() {
        TranscriptionQueue.registerBackgroundTask()

        let schema = Schema(versionedSchema: MeetingNotesSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema)
        do {
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: MeetingNotesMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        liveActivityCoordinator = LiveActivityCoordinator()
        transcriptionCoordinator = TranscriptionCoordinator(
            modelContainer: modelContainer,
            liveActivity: liveActivityCoordinator
        )
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(modelContainer)
        .environment(transcriptionCoordinator)
        .environment(liveActivityCoordinator)
    }
}
