import Quotas
import DataSources
import Providers
import Foundation
import Observation

/// Monitors Claude Code sessions by processing hook events.
/// Single source of truth for session state, similar to QuotaMonitor for providers.
/// Isolated to @MainActor since it's consumed by SwiftUI views.
///
/// Several sessions can run at once (one per terminal), and each is tracked on
/// its own. A session is picked up from whichever of its events arrives first,
/// not only `SessionStart`: one that was already running when ClaudeBar
/// launched sent its `SessionStart` before anything was listening.
@MainActor
@Observable
public final class SessionMonitor {
    /// Every session that is still running, in the order they were first seen.
    public private(set) var sessions: [ClaudeSession] = []

    /// Recently completed sessions (most recent first)
    public private(set) var recentSessions: [ClaudeSession] = []

    /// When each running session last sent an event, by session ID.
    private var lastEventAt: [String: Date] = [:]

    /// Maximum number of recent sessions to keep
    private let maxRecentSessions: Int

    public init(maxRecentSessions: Int = 10) {
        self.maxRecentSessions = maxRecentSessions
    }

    // MARK: - Event Processing

    /// Processes a session event and updates state accordingly.
    public func processEvent(_ event: SessionEvent) {
        if event.eventName == .sessionEnd {
            endSession(event.sessionId, at: event.receivedAt)
            return
        }

        let index = indexOfSession(for: event)
        lastEventAt[event.sessionId] = event.receivedAt

        switch event.eventName {
        case .sessionStart:
            // Also fires for a session that is already running (resume, compaction),
            // which must keep its progress.
            sessions[index].resume()
        case .sessionEnd:
            break
        case .taskCompleted:
            sessions[index].taskCompleted()
        case .subagentStart:
            sessions[index].subagentStarted()
        case .subagentStop:
            sessions[index].subagentStopped()
        case .stop:
            sessions[index].stop(at: event.receivedAt)
        case .userPromptSubmit:
            sessions[index].resume()
        case .notification:
            sessions[index].awaitInput(event.message, at: event.receivedAt)
        }
    }

    // MARK: - Queries

    /// Every running session, the one that most needs the user's eye first:
    /// a blocked session outranks one with agents working, which outranks one
    /// working alone, which outranks one that has stopped. Among equals, the
    /// one heard from last comes first. This is the order a list shows them in.
    public var sessionsByProminence: [ClaudeSession] {
        sessions.sorted { lhs, rhs in
            let left = Self.prominence(of: lhs.phase)
            let right = Self.prominence(of: rhs.phase)
            guard left == right else { return left > right }
            return lastHeard(from: lhs) > lastHeard(from: rhs)
        }
    }

    /// The one session to show where there is room for a single status (the
    /// menu bar glyph): the first by prominence. nil when no session is running.
    public var activeSession: ClaudeSession? {
        sessionsByProminence.first
    }

    /// Whether there's an active Claude Code session
    public var hasActiveSession: Bool {
        !sessions.isEmpty
    }

    // MARK: - Private

    private func lastHeard(from session: ClaudeSession) -> Date {
        lastEventAt[session.id] ?? session.startedAt
    }

    private static func prominence(of phase: ClaudeSession.Phase) -> Int {
        switch phase {
        case .awaitingInput: 3
        case .subagentsWorking: 2
        case .active: 1
        case .stopped, .ended: 0
        }
    }

    /// The position of the event's session, adding it first if this is the
    /// first event seen from it. For a session picked up mid-flight, `startedAt`
    /// is when ClaudeBar first heard from it, not when it really began, and it
    /// starts out stopped unless the event itself shows a turn underway: a
    /// late `SubagentStop` or `TaskCompleted` says nothing about that, and
    /// claiming "Working" would stick until the next prompt.
    private func indexOfSession(for event: SessionEvent) -> Int {
        if let index = sessions.firstIndex(where: { $0.id == event.sessionId }) {
            return index
        }
        var session = ClaudeSession(
            id: event.sessionId,
            cwd: event.cwd,
            startedAt: event.receivedAt
        )
        switch event.eventName {
        case .sessionStart, .userPromptSubmit, .subagentStart, .notification:
            break
        case .subagentStop, .taskCompleted, .stop, .sessionEnd:
            session.stop(at: event.receivedAt)
        }
        sessions.append(session)
        return sessions.count - 1
    }

    private func endSession(_ id: String, at date: Date) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        var session = sessions.remove(at: index)
        lastEventAt.removeValue(forKey: id)
        session.end(at: date)
        recentSessions.insert(session, at: 0)
        if recentSessions.count > maxRecentSessions {
            recentSessions = Array(recentSessions.prefix(maxRecentSessions))
        }
    }
}
