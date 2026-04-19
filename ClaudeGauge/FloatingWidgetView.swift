import SwiftUI

struct FloatingWidgetView: View {
    @EnvironmentObject var store: UsageStore
    @State private var isHovered = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            if isHovered {
                ExpandedView(showSettings: $showSettings)
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
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
    }
}

// MARK: - Compact Pill (default view)

struct CompactPillView: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        HStack(spacing: 8) {
            // Animated pulse dot
            ZStack {
                Circle()
                    .fill(store.gaugeColor.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .scaleEffect(store.usagePercent > 70 ? 1.3 : 1.0)
                    .animation(
                        store.usagePercent > 70
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: store.usagePercent
                    )

                Circle()
                    .fill(store.gaugeColor)
                    .frame(width: 12, height: 12)
            }

            Text("\(Int(store.usagePercent))%")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(store.gaugeColor.opacity(0.4), lineWidth: 1)
                )
        )
        .shadow(color: store.gaugeColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Expanded View (on hover)

struct ExpandedView: View {
    @EnvironmentObject var store: UsageStore
    @Binding var showSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row
            HStack {
                Text("Claude Gauge")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Big usage number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(store.usagePercent))")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(store.gaugeColor)

                Text("%")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(store.gaugeColor.opacity(0.7))

                Spacer()

                Text(store.gaugeLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(store.gaugeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(store.gaugeColor.opacity(0.15))
                    )
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(store.gaugeColor)
                        .frame(width: geo.size.width * (store.usagePercent / 100), height: 6)
                        .animation(.spring(response: 0.5), value: store.usagePercent)
                }
            }
            .frame(height: 6)

            // 7-day row + last updated
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("7-day: \(Int(store.weeklyPercent))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                if let updated = store.lastUpdated {
                    Text("Updated \(timeAgo(updated))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if store.errorMessage != nil {
                    Text("⚠ No data")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            // Real reset countdown
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(store.timeUntilReset)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Action tip (shown at 40%+)
            if store.usagePercent >= 40 {
                Divider().background(Color.white.opacity(0.1))

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(store.gaugeColor)
                    Text(store.actionTip)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(store.gaugeColor)
                }
            }
        }
        .padding(14)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(store.gaugeColor.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        .shadow(color: store.gaugeColor.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
