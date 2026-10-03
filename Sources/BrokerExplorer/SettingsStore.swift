import Foundation

enum SettingsStore {
    private static let urlKey = "broker.url"
    private static let usernameKey = "broker.username"
    private static let passwordKey = "broker.password"
    private static let portKey = "broker.port"
    private static let searchTextKey = "ui.searchText"
    private static let topicPanelWidthKey = "ui.topicPanelWidth"
    private static let surfaceThemeKey = "ui.surfaceTheme"

    static var hasBrokerConfiguration: Bool {
        guard let url = UserDefaults.standard.string(forKey: urlKey) else { return false }
        return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func loadConnection() -> BrokerConnection {
        BrokerConnection(
            url: UserDefaults.standard.string(forKey: urlKey) ?? "mqtt://localhost",
            username: UserDefaults.standard.string(forKey: usernameKey) ?? "",
            password: UserDefaults.standard.string(forKey: passwordKey) ?? "",
            port: UserDefaults.standard.string(forKey: portKey) ?? "1883"
        )
    }

    static func save(connection: BrokerConnection) {
        UserDefaults.standard.set(connection.url, forKey: urlKey)
        UserDefaults.standard.set(connection.username, forKey: usernameKey)
        UserDefaults.standard.set(connection.password, forKey: passwordKey)
        UserDefaults.standard.set(connection.port, forKey: portKey)
    }

    static func loadSearchText() -> String {
        UserDefaults.standard.string(forKey: searchTextKey) ?? ""
    }

    static func save(searchText: String) {
        UserDefaults.standard.set(searchText, forKey: searchTextKey)
    }

    static func loadTopicPanelWidth() -> CGFloat? {
        guard UserDefaults.standard.object(forKey: topicPanelWidthKey) != nil else {
            return nil
        }

        let width = UserDefaults.standard.double(forKey: topicPanelWidthKey)
        return width > 0 ? CGFloat(width) : nil
    }

    static func save(topicPanelWidth: CGFloat?) {
        guard let topicPanelWidth else {
            UserDefaults.standard.removeObject(forKey: topicPanelWidthKey)
            return
        }

        UserDefaults.standard.set(Double(topicPanelWidth), forKey: topicPanelWidthKey)
    }

    static func loadSurfaceTheme() -> AppSurfaceTheme {
        guard
            let rawValue = UserDefaults.standard.string(forKey: surfaceThemeKey),
            let surface = AppSurfaceTheme(rawValue: rawValue)
        else {
            return .grass
        }

        return surface
    }

    static func save(surfaceTheme: AppSurfaceTheme) {
        UserDefaults.standard.set(surfaceTheme.rawValue, forKey: surfaceThemeKey)
    }
}
