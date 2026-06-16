import Foundation

enum SettingsStore {
    private static let urlKey = "broker.url"
    private static let usernameKey = "broker.username"
    private static let passwordKey = "broker.password"
    private static let portKey = "broker.port"
    private static let settingsOpenKey = "ui.settingsOpen"
    private static let searchTextKey = "ui.searchText"

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

    static func loadSettingsOpen() -> Bool {
        guard UserDefaults.standard.object(forKey: settingsOpenKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: settingsOpenKey)
    }

    static func save(settingsOpen: Bool) {
        UserDefaults.standard.set(settingsOpen, forKey: settingsOpenKey)
    }

    static func loadSearchText() -> String {
        UserDefaults.standard.string(forKey: searchTextKey) ?? ""
    }

    static func save(searchText: String) {
        UserDefaults.standard.set(searchText, forKey: searchTextKey)
    }
}
