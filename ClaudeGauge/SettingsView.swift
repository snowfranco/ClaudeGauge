import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: UsageStore
    @Environment(\.dismiss) var dismiss

    @State private var cookieInput: String = ""
    @State private var manualPercent: Double = 0
    @State private var useManual: Bool = false
    @State private var showCookieHelp = false
    @State private var pollingInterval: Double = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Title bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude Gauge")
                        .font(.system(size: 16, weight: .bold))
                    Text("Settings")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Live Data Section
                    SectionHeader(title: "Live Data", icon: "wifi")

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Session Cookie")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Button("How to get this →") {
                                showCookieHelp = true
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }

                        SecureField("Paste your sessionKey value here", text: $cookieInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))

                        HStack(spacing: 8) {
                            Button("Save & Connect") {
                                store.connectWithCookie(cookieInput)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(cookieInput.isEmpty)

                            if store.isDetectingOrg {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Detecting account...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else if let error = store.errorMessage {
                                Text(error.prefix(50))
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                            } else if store.lastUpdated != nil {
                                Label("Connected", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                        }

                        if !store.organizationId.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("Org: \(store.organizationId.prefix(8))...")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("Polling every \(Int(pollingInterval))s")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("30s")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Slider(value: $pollingInterval, in: 30...300, step: 30)
                            Text("5m")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))

                    // MARK: Manual Override Section
                    SectionHeader(title: "Manual / Test Mode", icon: "slider.horizontal.3")

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Use manual override", isOn: $useManual)
                            .font(.system(size: 13))

                        if useManual {
                            HStack {
                                Text("Usage: \(Int(manualPercent))%")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(colorForPercent(manualPercent))
                                Spacer()
                            }
                            Slider(value: $manualPercent, in: 0...100, step: 1)
                                .accentColor(colorForPercent(manualPercent))
                                .onChange(of: manualPercent) { value in
                                    store.setManualUsage(value)
                                }

                            HStack(spacing: 8) {
                                ForEach([0.0, 40.0, 70.0, 85.0, 100.0], id: \.self) { val in
                                    Button("\(Int(val))%") {
                                        manualPercent = val
                                        store.setManualUsage(val)
                                    }
                                    .font(.system(size: 10))
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))

                    // MARK: Color Legend
                    SectionHeader(title: "Color Guide", icon: "circle.fill")

                    VStack(spacing: 6) {
                        ColorLegendRow(color: Color(hex: "#22C55E"), range: "0–39%",  label: "Good — work freely")
                        ColorLegendRow(color: Color(hex: "#EAB308"), range: "40–69%", label: "Moderate — consider new chat")
                        ColorLegendRow(color: Color(hex: "#F97316"), range: "70–84%", label: "High — switch to Sonnet")
                        ColorLegendRow(color: Color(hex: "#EF4444"), range: "85–100%",label: "Critical — start fresh now")
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 580)
        .onAppear {
        cookieInput = store.sessionCookie
        manualPercent = store.usagePercent
        }
        .sheet(isPresented: $showCookieHelp) {
            CookieHelpView()
        }
    }

    func colorForPercent(_ p: Double) -> Color {
        switch p {
        case 0..<40:  return Color(hex: "#22C55E")
        case 40..<70: return Color(hex: "#EAB308")
        case 70..<85: return Color(hex: "#F97316")
        default:      return Color(hex: "#EF4444")
        }
    }
}

// MARK: - Cookie Help View

struct CookieHelpView: View {
    @Environment(\.dismiss) var dismiss

    let steps = [
        ("1", "Open claude.ai in Safari or Chrome and make sure you're logged in."),
        ("2", "Open Developer Tools: ⌘ + Option + I (Chrome) or ⌘ + Option + C (Safari)."),
        ("3", "Go to the Application tab → Cookies → https://claude.ai"),
        ("4", "Find the cookie named sessionKey."),
        ("5", "Copy its entire Value and paste it into Claude Gauge settings.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("How to Get Your Session Cookie")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    InfoBox(
                        icon: "lock.shield.fill",
                        color: .blue,
                        text: "Your session cookie is stored locally on your Mac only. It is never sent anywhere except directly to claude.ai to fetch your usage."
                    )

                    ForEach(steps, id: \.0) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text(step.0)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.blue))

                            Text(step.1)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    InfoBox(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        text: "Your session cookie expires when you log out of claude.ai. If the widget stops updating, just paste a fresh cookie."
                    )
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 420)
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

struct ColorLegendRow: View {
    let color: Color
    let range: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(range)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 60, alignment: .leading)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

struct InfoBox: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08)))
    }
}
