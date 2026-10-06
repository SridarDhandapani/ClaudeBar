import SwiftUI
import Domain

/// Displays the Claude Code session's status in the menu popover.
/// `SessionsCardView` shows it when exactly one session is running.
struct SessionIndicatorView: View {
    let session: ClaudeSession

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            // Phase indicator dot
            Circle()
                .fill(phaseColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(phaseColor.opacity(0.4))
                        .frame(width: 14, height: 14)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Claude Code")
                        .font(theme.font(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(phaseLabel)
                        .font(theme.font(size: 9, weight: .medium))
                        .foregroundStyle(phaseLabelColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(phaseColor.opacity(0.15))
                        )
                }

                HStack(spacing: 8) {
                    if session.completedTaskCount > 0 {
                        Label("\(session.completedTaskCount) tasks", systemImage: "checkmark.circle.fill")
                            .font(theme.font(size: 9, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }

                    if session.activeSubagentCount > 0 {
                        Label("\(session.activeSubagentCount) agents", systemImage: "person.2.fill")
                            .font(theme.font(size: 9, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }

                    Text(session.durationDescription)
                        .font(theme.font(size: 9, weight: .medium))
                        .foregroundStyle(theme.textTertiary)

                    Spacer()

                    // Working directory (last path component)
                    Text(cwdShort)
                        .font(theme.font(size: 9, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .fill(theme.cardGradient).themeShadow(theme)

                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(phaseColor.opacity(0.3), lineWidth: 1)
            }
        )
    }

    // MARK: - Phase Display

    private var phaseLabel: String { session.phase.label }
    private var phaseColor: Color { session.phase.color }

    private var phaseLabelColor: Color {
        session.phase == .ended ? theme.textTertiary : session.phase.color
    }

    private var cwdShort: String {
        (session.cwd as NSString).lastPathComponent
    }
}
