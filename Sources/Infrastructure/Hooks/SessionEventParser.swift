import Foundation
import Domain

/// Parses Claude Code hook event JSON payloads into SessionEvent domain objects.
public enum SessionEventParser {
    /// Parses raw JSON data from a hook HTTP request into a SessionEvent.
    /// Claude Code sends JSON with fields: session_id, hook_event_name, cwd, etc.
    public static func parse(_ data: Data) -> SessionEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let sessionId = json["session_id"] as? String,
              let eventNameRaw = json["hook_event_name"] as? String,
              let eventName = SessionEvent.EventName(rawValue: eventNameRaw) else {
            return nil
        }

        let cwd = json["cwd"] as? String ?? ""
        // What the event is about, when it says: `StopFailure` carries `error`,
        // `Notification` carries `message`.
        let message = (json["error"] ?? json["message"]) as? String

        return SessionEvent(
            sessionId: sessionId,
            eventName: eventName,
            cwd: cwd,
            message: message
        )
    }
}
