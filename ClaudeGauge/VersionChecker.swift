import Foundation

class VersionChecker: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var downloadURL = ""

    private let remoteURL = "https://raw.githubusercontent.com/snowfranco/ClaudeGauge/main/version.json"

    func checkForUpdate() {
        guard let url = URL(string: remoteURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let remote = json["version"],
                  let dlURL = json["url"] else { return }

            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

            DispatchQueue.main.async {
                if self.isNewer(remote: remote, current: current) {
                    self.latestVersion = remote
                    self.downloadURL = dlURL
                    self.updateAvailable = true
                }
            }
        }.resume()
    }

    /// Semantic version comparison: returns true if remote > current
    private func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}
