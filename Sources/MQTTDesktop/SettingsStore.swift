import Foundation
import Security

enum SettingsStore {
    private static let urlKey = "broker.url"
    private static let usernameKey = "broker.username"
    private static let portKey = "broker.port"
    private static let settingsOpenKey = "ui.settingsOpen"
    private static let searchTextKey = "ui.searchText"
    private static let keychainService = "se.meg768.mqtt-desktop"
    private static let keychainAccount = "broker.password"

    static func loadConnection() -> BrokerConnection {
        BrokerConnection(
            url: UserDefaults.standard.string(forKey: urlKey) ?? "mqtt://localhost",
            username: UserDefaults.standard.string(forKey: usernameKey) ?? "",
            password: Keychain.password(service: keychainService, account: keychainAccount) ?? "",
            port: UserDefaults.standard.string(forKey: portKey) ?? "1883"
        )
    }

    static func save(connection: BrokerConnection) {
        UserDefaults.standard.set(connection.url, forKey: urlKey)
        UserDefaults.standard.set(connection.username, forKey: usernameKey)
        UserDefaults.standard.set(connection.port, forKey: portKey)

        if connection.password.isEmpty {
            Keychain.deletePassword(service: keychainService, account: keychainAccount)
        } else {
            Keychain.setPassword(connection.password, service: keychainService, account: keychainAccount)
        }
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

private enum Keychain {
    static func password(service: String, account: String) -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard
            status == errSecSuccess,
            let data = item as? Data,
            let password = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return password
    }

    static func setPassword(_ password: String, service: String, account: String) {
        let data = Data(password.utf8)
        let query = baseQuery(service: service, account: account)
        let attributes = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func deletePassword(service: String, account: String) {
        let query = baseQuery(service: service, account: account)
        SecItemDelete(query as CFDictionary)
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

