import Foundation
import EventKit

struct CalendarEventSuggestion: Sendable, Equatable {
    var title: String
    var attendeeCount: Int
}

/// Looks up a calendar event overlapping "now" to suggest a recording title — turns
/// "Recording 14" into "Q3 Planning — 6 attendees" with no typing. Always an optional suggestion
/// the user must accept, never applied automatically, and the app stays fully functional if
/// calendar access is declined.
enum CalendarService {
    // A single EKEventStore instance, read from a background Task but never mutated concurrently
    // — EventKit itself isn't audited Sendable, but this usage is safe.
    nonisolated(unsafe) private static let store = EKEventStore()

    static var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    @discardableResult
    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Finds the event overlapping `date`, preferring the shortest (most specific) match if
    /// several overlap (e.g. a recurring all-day block plus an actual meeting).
    static func suggestion(overlapping date: Date = .now) -> CalendarEventSuggestion? {
        guard authorizationStatus == .fullAccess else { return nil }

        let predicate = store.predicateForEvents(
            withStart: date.addingTimeInterval(-5 * 60),
            end: date.addingTimeInterval(5 * 60),
            calendars: nil
        )
        let overlapping = store.events(matching: predicate).filter {
            $0.startDate <= date && $0.endDate >= date
        }

        guard let event = overlapping.min(by: {
            $0.endDate.timeIntervalSince($0.startDate) < $1.endDate.timeIntervalSince($1.startDate)
        }) else {
            return nil
        }

        return CalendarEventSuggestion(
            title: event.title ?? "Untitled Event",
            attendeeCount: event.attendees?.count ?? 0
        )
    }
}
