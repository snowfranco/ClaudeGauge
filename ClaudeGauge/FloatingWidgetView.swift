import SwiftUI

struct FloatingWidgetView: View {
    @EnvironmentObject var store: UsageStore
    @State private var isHovered = false
    @State private var isLocked = false
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
            } else if isLocked || isHovered {
                ExpandedView(showSettings: $showSettings, showPreflight: $showPreflight, isLocked: $isLocked)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .onTapGesture { isLocked.toggle() }
            } else {
                CompactPillView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .onTapGesture { isLocked = true }
            }
        }
        .fixedSize()
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLocked || isHovered)
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
    @AppStorage("widgetTheme") private var themeName: String = "newui"

    var body: some View {
        let accent = store.gaugeColor
        let theme = ThemeConfig.named(themeName)
        let shadow = theme.pillShadow(accent)

        HStack(spacing: 12) {
            // Animated pulse dot
            ZStack {
                Circle()
                    .fill(theme.pillDotGlowColor(accent))
                    .frame(width: 30, height: 30)
                    .scaleEffect(store.usagePercent > 70 ? 1.3 : 1.0)
                    .animation(
                        store.usagePercent > 70
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: store.usagePercent
                    )

                Circle()
                    .fill(theme.pillDotColor(accent))
                    .frame(width: 18, height: 18)
            }

            Text("\(Int(store.usagePercent))%")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.pillTextColor(accent))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            // Status badge in pill
            if let weeklyLabel = store.weeklyWarningLabel {
                let badgeColor = store.weeklyPercent >= 86 ? Color(hex: "#EF4444") : accent
                Text(weeklyLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(badgeColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(badgeColor.opacity(0.12))
                    )
            } else if themeName == "clean" || themeName == "dark" {
                Text(store.gaugeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(accent.opacity(themeName == "dark" ? 0.15 : 0.10))
                    )
                    .overlay(
                        Group {
                            if themeName == "dark" {
                                Capsule()
                                    .strokeBorder(accent.opacity(0.4), lineWidth: 1)
                            }
                        }
                    )
            }
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 15)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: theme.pillCornerRadius)
                .fill(theme.pillBackground(accent))
        )
        .overlay(
            Group {
                if let border = theme.pillBorder(accent) {
                    RoundedRectangle(cornerRadius: theme.pillCornerRadius)
                        .strokeBorder(border.color, lineWidth: border.width)
                }
            }
        )
        .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Expanded View (on hover)

struct ExpandedView: View {
    @EnvironmentObject var store: UsageStore
    @Binding var showSettings: Bool
    @Binding var showPreflight: Bool
    @Binding var isLocked: Bool
    @AppStorage("newChatTarget") private var newChatTarget: String = "web"
    @AppStorage("widgetTheme") private var themeName: String = "newui"

    var body: some View {
        let accent = store.gaugeColor
        let theme = ThemeConfig.named(themeName)
        let badge = theme.badgeStyle(accent)

        VStack(alignment: .leading, spacing: 15) {

            // Header row
            HStack {
                Text("Claude Gauge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.headerTextColor)
                    .onTapGesture { isLocked = false }

                Spacer()

                Button(action: { openNewChat() }) {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 16))
                        .foregroundColor(accent)
                }
                .buttonStyle(.plain)
                .help("New Chat")

                Button(action: { showPreflight = true }) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 16))
                        .foregroundColor(accent)
                }
                .buttonStyle(.plain)
                .help("Preflight")

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(theme.headerTextColor)
                }
                .buttonStyle(.plain)
            }

            // Big usage number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(store.usagePercent))")
                    .font(.system(size: 54, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)

                Text("%")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundColor(accent.opacity(0.7))

                Spacer()

                Text(store.gaugeLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(badge.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(badge.bgColor)
                    )
                    .overlay(
                        Group {
                            if themeName == "dark" {
                                Capsule()
                                    .strokeBorder(accent.opacity(0.4), lineWidth: 1)
                            }
                        }
                    )
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4.5)
                        .fill(theme.progressTrackColor)
                        .frame(height: 9)

                    RoundedRectangle(cornerRadius: 4.5)
                        .fill(accent)
                        .frame(width: geo.size.width * (store.usagePercent / 100), height: 9)
                        .animation(.spring(response: 0.5), value: store.usagePercent)
                }
            }
            .frame(height: 9)

            // Primary risk block (shown at 40%+ or weekly danger)
            if store.usagePercent >= 40 || store.isWeeklyDanger {
                let riskColor = store.isWeeklyDanger ? store.effectiveColor : accent

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.guidanceBody)
                        .font(.system(size: 14))
                        .foregroundColor(themeName == "dark" ? Color.white.opacity(0.85) : .primary.opacity(0.85))

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
                        .fill(theme.riskCardBackground(riskColor))
                )
            }

            Divider().opacity(0.3)

            // Footer metadata row — 3 columns: Resets in · Weekly · Updated
            HStack(spacing: 0) {
                // Col 1: Resets in
                VStack(spacing: 2) {
                    Text("Resets in")
                        .font(.system(size: 9))
                        .foregroundColor(theme.metadataTextColor)
                    Text(store.resetCountdown)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeName == "dark" ? .white : .primary)
                        .lineLimit(1)
                    Text("5-hr window")
                        .font(.system(size: 9))
                        .foregroundColor(theme.metadataTextColor)
                }
                .frame(maxWidth: .infinity)

                // Col 2: Weekly
                VStack(spacing: 2) {
                    Text("Weekly")
                        .font(.system(size: 9))
                        .foregroundColor(theme.metadataTextColor)
                    HStack(spacing: 2) {
                        Text("\(Int(store.weeklyPercent))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(store.isWeeklyDanger ? store.effectiveColor : (themeName == "dark" ? .white : .primary))
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(theme.metadataTextColor)
                        Text(store.weeklyTimeUntilReset)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeName == "dark" ? .white : .primary)
                    }
                    .lineLimit(1)
                    Text("7-day window")
                        .font(.system(size: 9))
                        .foregroundColor(theme.metadataTextColor)
                }
                .frame(maxWidth: .infinity)

                // Col 3: Updated
                VStack(spacing: 2) {
                    Text("Updated")
                        .font(.system(size: 9))
                        .foregroundColor(theme.metadataTextColor)
                    if let updated = store.lastUpdated {
                        Text(timeAgo(updated))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeName == "dark" ? .white : .primary)
                    } else if store.errorMessage != nil {
                        Text("No data")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    } else {
                        Text("—")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.metadataTextColor)
                    }
                    Text(" ")
                        .font(.system(size: 9))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(21)
        .frame(width: 330)
        .background(
            RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                .fill(theme.cardBackground(accent))
        )
        .overlay(
            Group {
                if let border = theme.cardBorder(accent) {
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                        .strokeBorder(border.color, lineWidth: border.width)
                }
            }
        )
        .modifier(MultiShadow(shadows: theme.cardShadow(accent)))
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

                Text("Should I send this?")
                    .font(.system(size: 13, weight: .medium))
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

                // Result card with leading color stripe
                if let risk = result {
                    HStack(spacing: 0) {
                        // Leading color stripe
                        RoundedRectangle(cornerRadius: 2)
                            .fill(risk.color)
                            .frame(width: 4)

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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(risk.color.opacity(0.05))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
