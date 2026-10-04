import Foundation

enum SettingsStore {
    private static let recentsKey = "broker.recents"
    private static let searchTextKey = "ui.searchText"
    private static let topicPanelWidthKey = "ui.topicPanelWidth"
    private static let surfaceThemeKey = "ui.surfaceTheme"

    static func loadRecentConnections() -> [BrokerConnection] {
        guard let data = UserDefaults.standard.data(forKey: recentsKey),
              let connections = try? JSONDecoder().decode([BrokerConnection].self, from: data) else { return [] }
        return Array(connections.prefix(5))
    }

    static func save(recentConnections: [BrokerConnection]) {
        guard let data = try? JSONEncoder().encode(Array(recentConnections.prefix(5))) else { return }
        UserDefaults.standard.set(data, forKey: recentsKey)
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
