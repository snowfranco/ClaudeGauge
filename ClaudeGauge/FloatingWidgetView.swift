import SwiftUI

struct FloatingWidgetView: View {
    @EnvironmentObject var store: UsageStore
    @State private var isHovered = false
    @State private var showSettings = false
    @State private var showPreflight = false

    var body: some View {
        ZStack {
            if store.cookieExpired {
                ReconnectPillView(showSettings: $showSettings)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            } else if isHovered {
                ExpandedView(showSettings: $showSettings, showPreflight: $showPreflight)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            } else {
                CompactPillView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.cookieExpired)
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showPreflight) {
            PreflightView()
                .environmentObject(store)
        }
    }
}

// MARK: - Reconnect Pill (cookie expired)

struct ReconnectPillView: View {
    @Binding var showSettings: Bool

    var body: some View {
        Button(action: { showSettings = true }) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)

                Text("Reconnect")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 21)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 33)
                    .fill(Color(hex: "#EF4444"))
            )
            .shadow(color: Color(hex: "#EF4444").opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Pill (default view)

struct CompactPillView: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        HStack(spacing: 12) {
            // Animated pulse dot (white on colored background)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .scaleEffect(store.usagePercent > 70 ? 1.3 : 1.0)
                    .animation(
                        store.usagePercent > 70
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: store.usagePercent
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
            }

            Text("\(Int(store.usagePercent))%")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            if let weeklyLabel = store.weeklyWarningLabel {
                Text(weeklyLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.white.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 33)
                .fill(store.gaugeColor)
        )
        .shadow(color: store.gaugeColor.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Expanded View (on hover)

struct ExpandedView: View {
    @EnvironmentObject var store: UsageStore
    @Binding var showSettings: Bool
    @Binding var showPreflight: Bool
    @AppStorage("newChatTarget") private var newChatTarget: String = "web"

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // Header row
            HStack {
                Text("Claude Gauge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { openNewChat() }) {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 16))
                        .foregroundColor(store.gaugeColor)
                }
                .buttonStyle(.plain)
                .help("New Chat")

                Button(action: { showPreflight = true }) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 16))
                        .foregroundColor(store.gaugeColor)
                }
                .buttonStyle(.plain)
                .help("Preflight")

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Big usage number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(store.usagePercent))")
                    .font(.system(size: 54, weight: .bold, design: .monospaced))
                    .foregroundColor(store.gaugeColor)

                Text("%")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundColor(store.gaugeColor.opacity(0.7))

                Spacer()

                Text(store.gaugeLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(store.gaugeColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(store.gaugeColor.opacity(0.15))
                    )
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4.5)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 9)

                    RoundedRectangle(cornerRadius: 4.5)
                        .fill(store.gaugeColor)
                        .frame(width: geo.size.width * (store.usagePercent / 100), height: 9)
                        .animation(.spring(response: 0.5), value: store.usagePercent)
                }
            }
            .frame(height: 9)

            // Primary risk block (shown at 40%+ or weekly danger)
            if store.usagePercent >= 40 || store.isWeeklyDanger {
                let riskColor = store.isWeeklyDanger ? store.effectiveColor : store.gaugeColor

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.guidanceBody)
                        .font(.system(size: 14))
                        .foregroundColor(.primary.opacity(0.85))

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(riskColor)
                        Text(store.guidanceAction)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(riskColor)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(riskColor.opacity(0.1))
                )
            }

            Divider().background(Color.white.opacity(0.1))

            // Metadata rows
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("7-day: \(Int(store.weeklyPercent))%")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(store.isWeeklyDanger ? store.effectiveColor : .secondary)

                Spacer()

                if let updated = store.lastUpdated {
                    Text(timeAgo(updated))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else if store.errorMessage != nil {
                    Text("No data")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(store.timeUntilReset)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(21)
        .frame(width: 330)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(store.gaugeColor.opacity(0.15))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(store.gaugeColor.opacity(0.25), lineWidth: 1)
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
        .shadow(color: store.gaugeColor.opacity(0.15), radius: 30, x: 0, y: 0)
    }

    func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }

    func openNewChat() {
        let urlString = newChatTarget == "desktop" ? "claude://" : "https://claude.ai/new"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preflight View

enum PreflightRisk: String {
    case low = "Low"
    case moderate = "Moderate"
    case weeklyRisky = "Weekly-risky"

    var color: Color {
        switch self {
        case .low:          return Color(hex: "#22C55E")
        case .moderate:     return Color(hex: "#F97316")
        case .weeklyRisky:  return Color(hex: "#EF4444")
        }
    }

    var body: String {
        switch self {
        case .low:          return "This looks reasonable."
        case .moderate:     return "This thread is getting expensive.\nFresh chat will likely save usage."
        case .weeklyRisky:  return "Weekly capacity is the real risk now.\nSave heavy tasks for when headroom returns."
        }
    }

    var action: String {
        switch self {
        case .low:          return "Send as-is or keep it concise."
        case .moderate:     return "Open a new chat before sending."
        case .weeklyRisky:  return "Send one focused version only."
        }
    }
}

struct PreflightView: View {
    @EnvironmentObject var store: UsageStore
    @Environment(\.dismiss) var dismiss

    @State private var promptText: String = ""
    @State private var result: PreflightRisk?

    /// "Long" prompt threshold — roughly 4+ paragraphs
    private let longPromptThreshold = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Title bar
            HStack {
                Label("Preflight", systemImage: "checklist.checked")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 14) {

                Text("Paste your next prompt to check risk before sending.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextEditor(text: $promptText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 80, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                HStack {
                    Button("Check") {
                        result = evaluateRisk()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if result != nil {
                        Button("Clear") {
                            result = nil
                            promptText = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Result card
                if let risk = result {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(risk.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(risk.color)

                        Text(risk.body)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.85))

                        HStack(spacing: 5) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(risk.color)
                            Text(risk.action)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(risk.color)
                        }

                        // Project hint — show when prompt is long and risk is moderate+
                        if risk != .low && promptText.count > longPromptThreshold {
                            Divider()
                            HStack(spacing: 5) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("You may be repeating context often. A Claude Project could reduce rework.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(risk.color.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(risk.color.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding(16)
        }
        .frame(width: 340)
    }

    private func evaluateRisk() -> PreflightRisk {
        if store.weeklyPercent >= 85 {
            return .weeklyRisky
        }
        let isLongPrompt = promptText.count >= longPromptThreshold
        if store.usagePercent >= 70 || isLongPrompt {
            return .moderate
        }
        return .low
    }
}
