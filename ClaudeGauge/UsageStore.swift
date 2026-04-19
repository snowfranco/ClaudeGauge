import SwiftUI
import Combine

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

    // MARK: - Computed: Color based on 5-hour window
    var gaugeColor: Color {
        switch usagePercent {
        case 0..<40:   return Color(hex: "#22C55E")
        case 40..<70:  return Color(hex: "#EAB308")
        case 70..<85:  return Color(hex: "#F97316")
        default:       return Color(hex: "#EF4444")
        }
    }

    var gaugeLabel: String {
        switch usagePercent {
        case 0..<40:   return "Good"
        case 40..<70:  return "Moderate"
        case 70..<85:  return "High"
        default:       return "Critical"
        }
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

    var actionTip: String {
        switch usagePercent {
        case 85...: return "Start a fresh conversation now"
        case 70..<85: return "Consider switching to Sonnet"
        case 40..<70: return "Start a new chat soon"
        default: return ""
        }
    }

    private var pollingTimer: Timer?

    init() {
        loadSaved()
        startPolling()
    }

    // MARK: - Polling

    func startPolling(interval: TimeInterval = 60) {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
        fetchUsage()
    }

    func stopPolling() {
        pollingTimer?.invalidate()
    }

    // MARK: - Connect: cookie only, org ID auto-detected

    func connectWithCookie(_ cookie: String) {
        sessionCookie = cookie
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

        URLSession.shared.dataTask(with: makeRequest(url: url)) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = "Network: \(error.localizedDescription)"
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
