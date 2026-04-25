import SwiftUI
import Combine
import UserNotifications

class UsageStore: ObservableObject {
    @Published var usagePercent: Double = 0.0       // 5-hour window utilization (primary)
    @Published var weeklyPercent: Double = 0.0       // 7-day window utilization
    @Published var resetsAt: Date? = nil             // when 5-hour window resets
    @Published var weeklyResetsAt: Date? = nil
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var sessionCookie: String = ""
    @Published var organizationId: String = ""       // auto-detected, not user-entered
    @Published var errorMessage: String? = nil
    @Published var isDetectingOrg: Bool = false
    @Published var cookieExpired: Bool = false

    // MARK: - Computed: Color based on 5-hour window
    var gaugeColor: Color {
        switch usagePercent {
        case 0..<40:   return Color(hex: "#22C55E")
        case 40..<70:  return Color(hex: "#EAB308")
        case 70..<85:  return Color(hex: "#F97316")
        default:       return Color(hex: "#EF4444")
        }
    }

    var isWeeklyDanger: Bool { weeklyPercent >= 85 }

    var gaugeLabel: String {
        if isWeeklyDanger && usagePercent >= 85 { return "Hold off" }
        if isWeeklyDanger { return "Protect your week" }
        switch usagePercent {
        case 0..<40:   return "Good"
        case 40..<70:  return "Watch it"
        case 70..<85:  return "Conserve"
        default:       return "Recovery soon"
        }
    }

    var guidanceBody: String {
        if isWeeklyDanger && usagePercent >= 85 {
            return "Save heavy tasks for when headroom returns."
        }
        if isWeeklyDanger {
            return "Weekly capacity is the real risk now."
        }
        switch usagePercent {
        case 0..<40:   return ""
        case 40..<70:  return "This thread is getting expensive."
        case 70..<85:  return "Fresh chat will likely save usage."
        default:       return "This thread is getting expensive."
        }
    }

    var guidanceAction: String {
        if isWeeklyDanger && usagePercent >= 85 {
            return "Send one focused prompt only if necessary."
        }
        if isWeeklyDanger {
            return "Use Claude only for priority work."
        }
        switch usagePercent {
        case 0..<40:   return ""
        case 40..<70:  return "Start a fresh chat for the next topic."
        case 70..<85:  return "Batch your next ask before sending."
        default:       return "Start a fresh chat now or pause heavy work."
        }
    }

    /// Short weekly warning label for the compact pill (e.g. "W!92")
    var weeklyWarningLabel: String? {
        guard isWeeklyDanger else { return nil }
        return "W!\(Int(weeklyPercent))"
    }

    var statusEmoji: String {
        switch usagePercent {
        case 0..<40:   return "🟢"
        case 40..<70:  return "🟡"
        case 70..<85:  return "🟠"
        default:       return "🔴"
        }
    }

    var timeUntilReset: String {
        guard let resetDate = resetsAt else {
            switch usagePercent {
            case 85...: return "~45m to recover"
            case 70..<85: return "~1.5h to recover"
            default: return "Plenty of headroom"
            }
        }
        let seconds = Int(resetDate.timeIntervalSinceNow)
        if seconds <= 0 { return "Resetting now..." }
        if seconds < 60 { return "Resets in \(seconds)s" }
        if seconds < 3600 { return "Resets in \(seconds / 60)m" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return m > 0 ? "Resets in \(h)h \(m)m" : "Resets in \(h)h"
    }

    /// Effective color — overrides to red if weekly danger is the primary risk
    var effectiveColor: Color {
        if isWeeklyDanger && usagePercent < 70 { return Color(hex: "#EF4444") }
        return gaugeColor
    }

    @Published var smartPollingEnabled: Bool = true

    /// Tracks whether the threshold notification has already fired for the current crossing
    private var hasNotifiedThreshold: Bool = false

    /// Tracks the previous poll's utilization to detect reset crossings
    private var previousUtilization: Double = 0

    /// Tracks whether the Pushcut reset webhook has already fired for this cycle
    private var hasNotifiedReset: Bool = false

    /// The alert threshold as a percentage (0–100). Reads from UserDefaults, defaults to 85.
    private var alertThresholdPercent: Double {
        let stored = UserDefaults.standard.double(forKey: "alertThreshold")
        return stored > 0 ? stored * 100 : 85
    }

    private var pollingTimer: Timer?

    /// Returns the appropriate polling interval based on current usage
    var smartPollingInterval: TimeInterval {
        switch usagePercent {
        case 70...:    return 30    // High/Critical: every 30s
        case 40..<70:  return 60    // Moderate: every 60s
        default:       return 300   // Good: every 5 minutes
        }
    }

    init() {
        loadSaved()
        smartPollingEnabled = UserDefaults.standard.object(forKey: "smart_polling_enabled") as? Bool ?? true
        startPolling()
    }

    // MARK: - Polling

    func startPolling(interval: TimeInterval = 60) {
        pollingTimer?.invalidate()
        let effectiveInterval = smartPollingEnabled ? smartPollingInterval : interval
        pollingTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
        fetchUsage()
    }

    /// Reschedule the polling timer based on the current usage level
    func reschedulePolling() {
        guard smartPollingEnabled else { return }
        pollingTimer?.invalidate()
        let interval = smartPollingInterval
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
    }

    // MARK: - Connect: cookie only, org ID auto-detected

    func connectWithCookie(_ cookie: String) {
        sessionCookie = cookie
        cookieExpired = false
        UserDefaults.standard.set(cookie, forKey: "claude_session_cookie")

        if !organizationId.isEmpty {
            // Already have org ID, just fetch usage
            fetchUsage()
            return
        }

        // Auto-detect org ID first
        isDetectingOrg = true
        errorMessage = "Detecting account..."

        detectOrgId { [weak self] success in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isDetectingOrg = false
                if success {
                    self.fetchUsage()
                }
            }
        }
    }

    // MARK: - Org ID Detection

    private func detectOrgId(completion: @escaping (Bool) -> Void) {
        // Strategy 1: /api/organizations (returns array)
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: makeRequest(url: url)) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                // Strategy 2: try bootstrap as fallback
                self?.detectOrgFromBootstrap(completion: completion)
                return
            }

            if let orgId = self.parseOrgIdFromOrganizations(data) {
                DispatchQueue.main.async {
                    self.organizationId = orgId
                    UserDefaults.standard.set(orgId, forKey: "claude_org_id")
                    self.errorMessage = nil
                }
                completion(true)
            } else {
                self.detectOrgFromBootstrap(completion: completion)
            }
        }.resume()
    }

    private func detectOrgFromBootstrap(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://claude.ai/api/bootstrap") else {
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: makeRequest(url: url)) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Could not detect org. Enter it manually in Settings."
                }
                completion(false)
                return
            }

            if let orgId = self.extractOrgId(from: json) {
                DispatchQueue.main.async {
                    self.organizationId = orgId
                    UserDefaults.standard.set(orgId, forKey: "claude_org_id")
                    self.errorMessage = nil
                }
                completion(true)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not detect org. Enter it manually in Settings."
                }
                completion(false)
            }
        }.resume()
    }

    private func parseOrgIdFromOrganizations(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        // Array of orgs
        if let arr = json as? [[String: Any]], let first = arr.first {
            return first["uuid"] as? String ?? first["id"] as? String
        }
        // Dict with organizations key
        if let dict = json as? [String: Any],
           let orgs = dict["organizations"] as? [[String: Any]],
           let first = orgs.first {
            return first["uuid"] as? String ?? first["id"] as? String
        }
        return nil
    }

    private func extractOrgId(from json: [String: Any]) -> String? {
        // account.memberships[0].organization.uuid
        if let account = json["account"] as? [String: Any],
           let memberships = account["memberships"] as? [[String: Any]],
           let first = memberships.first,
           let org = first["organization"] as? [String: Any] {
            return org["uuid"] as? String ?? org["id"] as? String
        }
        // organizations[0].uuid
        if let orgs = json["organizations"] as? [[String: Any]], let first = orgs.first {
            return first["uuid"] as? String ?? first["id"] as? String
        }
        // organization.uuid
        if let org = json["organization"] as? [String: Any] {
            return org["uuid"] as? String ?? org["id"] as? String
        }
        return nil
    }

    // MARK: - Fetch Usage

    func fetchUsage() {
        guard !sessionCookie.isEmpty else {
            DispatchQueue.main.async { self.errorMessage = "No session cookie set" }
            return
        }
        guard !organizationId.isEmpty else {
            // Trigger auto-detect if no org ID
            detectOrgId { [weak self] success in
                if success { self?.fetchUsage() }
            }
            return
        }

        DispatchQueue.main.async { self.isLoading = true }

        let urlString = "https://claude.ai/api/organizations/\(organizationId)/usage"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: makeRequest(url: url)) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = "Network: \(error.localizedDescription)"
                    return
                }

                // Check for HTTP 401/403 → cookie expired
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    self?.cookieExpired = true
                    self?.errorMessage = "Session expired — paste a fresh cookie"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                self?.parseUsageResponse(data)
            }
        }.resume()
    }

    // MARK: - Parse Usage Response

    private func parseUsageResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let raw = String(data: data, encoding: .utf8) ?? "unreadable"
            self.errorMessage = "Parse failed: \(raw.prefix(200))"
            return
        }

        // Check for auth error in response body
        if let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            let lower = message.lowercased()
            if lower.contains("unauthorized") || lower.contains("unauthenticated") {
                self.cookieExpired = true
                self.errorMessage = "Session expired — paste a fresh cookie"
                return
            }
        }

        // Successful response — cookie is valid
        self.cookieExpired = false

        if let fiveHour = json["five_hour"] as? [String: Any] {
            if let u = fiveHour["utilization"] as? Double {
                self.usagePercent = min(100, max(0, u))
            }
            if let s = fiveHour["resets_at"] as? String {
                self.resetsAt = ISO8601DateFormatter.withFractionalSeconds(s)
            }
        }

        if let sevenDay = json["seven_day"] as? [String: Any] {
            if let u = sevenDay["utilization"] as? Double {
                self.weeklyPercent = min(100, max(0, u))
            }
            if let s = sevenDay["resets_at"] as? String {
                self.weeklyResetsAt = ISO8601DateFormatter.withFractionalSeconds(s)
            }
        }

        self.lastUpdated = Date()
        self.errorMessage = nil

        // Reschedule polling based on updated usage level
        reschedulePolling()

        // Check threshold notification
        checkThresholdNotification()

        // Check Pushcut reset notification
        checkResetNotification()

        print("[ClaudeGauge] utilization: \(usagePercent)")

        // Update previous utilization for next poll comparison
        previousUtilization = usagePercent
    }

    // MARK: - Threshold Notification

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkThresholdNotification() {
        let threshold = alertThresholdPercent
        if usagePercent >= threshold {
            guard !hasNotifiedThreshold else { return }
            hasNotifiedThreshold = true
            sendThresholdNotification(threshold: Int(threshold))
        } else {
            // Reset so it can fire again next time usage crosses the threshold
            hasNotifiedThreshold = false
        }
    }

    private func sendThresholdNotification(threshold: Int) {
        // Play "Basso" system sound
        if let sound = NSSound(named: "Basso") {
            sound.play()
        }

        // Send macOS notification
        let content = UNMutableNotificationContent()
        content.title = "Claude Gauge"
        content.body = "Claude usage at \(threshold)% — start a fresh conversation"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Basso"))

        let request = UNNotificationRequest(
            identifier: "claude-usage-threshold",
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Pushcut Reset Notification

    private func checkResetNotification() {
        let threshold = alertThresholdPercent
        if previousUtilization > threshold && usagePercent < 5 {
            guard !hasNotifiedReset else { return }
            hasNotifiedReset = true
            print("[ClaudeGauge] Reset detected — Pushcut notification fired")
            firePushcutWebhook()
        } else if usagePercent >= threshold {
            // Reset so it can fire again after the next reset cycle
            hasNotifiedReset = false
        }
    }

    func firePushcutWebhook() {
        let webhookURL = UserDefaults.standard.string(forKey: "pushcutWebhookURL") ?? ""
        guard !webhookURL.isEmpty, let url = URL(string: webhookURL) else { return }
        URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
    }

    // MARK: - Shared request builder

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        return request
    }

    // MARK: - Manual Override

    func setManualUsage(_ percent: Double) {
        self.usagePercent = percent
        self.resetsAt = nil
        self.lastUpdated = Date()
        self.errorMessage = nil
    }

    // MARK: - Persistence

    func saveCredentials(cookie: String, orgId: String = "") {
        sessionCookie = cookie
        if !orgId.isEmpty {
            organizationId = orgId
            UserDefaults.standard.set(orgId, forKey: "claude_org_id")
        }
        UserDefaults.standard.set(cookie, forKey: "claude_session_cookie")
    }

    func saveCookie(_ cookie: String) {
        connectWithCookie(cookie)
    }

    private func loadSaved() {
        sessionCookie = UserDefaults.standard.string(forKey: "claude_session_cookie") ?? ""
        organizationId = UserDefaults.standard.string(forKey: "claude_org_id") ?? ""
    }
}

// MARK: - ISO8601 helper with fractional seconds support

extension ISO8601DateFormatter {
    static func withFractionalSeconds(_ string: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: string) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: string)
    }
}
