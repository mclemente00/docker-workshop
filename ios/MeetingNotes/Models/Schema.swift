import Foundation
import SwiftData

enum MeetingNotesSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Recording.self, TranscriptSegment.self, Bookmark.self]
    }
}

enum MeetingNotesSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Recording.self, TranscriptSegment.self, Bookmark.self]
    }
}

enum MeetingNotesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MeetingNotesSchemaV1.self, MeetingNotesSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: MeetingNotesSchemaV1.self,
        toVersion: MeetingNotesSchemaV2.self
    )
}

typealias Recording = MeetingNotesSchemaV2.Recording
typealias TranscriptSegment = MeetingNotesSchemaV2.TranscriptSegment
typealias Bookmark = MeetingNotesSchemaV2.Bookmark
