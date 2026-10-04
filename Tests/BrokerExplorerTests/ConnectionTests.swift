import XCTest
@testable import BrokerExplorer

@MainActor
final class ConnectionTests: XCTestCase {
    private var fixture: Process!
    private var ports: [Int] = []
    private var store: ExplorerStore!

    override func setUp() async throws {
        SettingsStore.save(recentConnections: [])
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("broker_fixture.py").path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        fixture = process
        ports = try JSONDecoder().decode([Int].self, from: pipe.fileHandleForReading.availableData)
        store = ExplorerStore()
    }

    override func tearDown() async throws {
        store.disconnect()
        try await Task.sleep(nanoseconds: 800_000_000)
        fixture.terminate()
        store = nil
        SettingsStore.save(recentConnections: [])
    }

    private func connection(_ index: Int, password: String = "") -> BrokerConnection {
        BrokerConnection(url: "mqtt://127.0.0.1", username: "", password: password, port: String(ports[index]))
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<160 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for broker state")
    }

    func testRecentsAreBoundedUpdatedAndPersistedWithoutAutoOpening() async throws {
        for index in 0..<6 {
            store.connect(to: connection(index))
            try await waitFor { self.store.isConnected && self.store.messages.first?.topic == "broker/\(index)" }
        }
        XCTAssertEqual(store.recentConnections.map(\.port), (1...5).reversed().map { String(ports[$0]) })
        store.connect(to: connection(3, password: "test-only-updated-password"))
        try await waitFor { self.store.isConnected && self.store.recentConnections.first?.password == "test-only-updated-password" }
        XCTAssertEqual(store.recentConnections.count, 5)
        XCTAssertEqual(store.recentConnections.filter { $0.port == String(ports[3]) }.count, 1)
        XCTAssertEqual(SettingsStore.loadRecentConnections(), store.recentConnections)
        store.disconnect()
        XCTAssertNil(store.openConnection)
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertEqual(store.recentConnections.count, 5)
        let relaunched = ExplorerStore()
        XCTAssertNil(relaunched.openConnection)
        XCTAssertFalse(relaunched.isConnected)
        XCTAssertEqual(relaunched.recentConnections.count, 5)
    }

    func testDraftCancelDoesNotAffectOpenConnection() async throws {
        store.connect(to: connection(0))
        try await waitFor { self.store.isConnected }
        store.newConnection()
        XCTAssertEqual(store.connectionDraft, BrokerConnection())
        store.connectionDraft = connection(1)
        store.connectionSheetOpen = false
        XCTAssertEqual(store.openConnection, connection(0))
        XCTAssertTrue(store.isConnected)
        XCTAssertEqual(store.recentConnections, [connection(0)])
    }

    func testRapidSwitchAndCloseIgnoreOldCallbacks() async throws {
        store.connect(to: connection(8))
        try await Task.sleep(nanoseconds: 100_000_000)
        store.connect(to: connection(1))
        store.connect(to: connection(2))
        try await waitFor { self.store.isConnected && self.store.messages.first?.topic == "broker/2" }
        XCTAssertEqual(store.openConnection, connection(2))
        XCTAssertEqual(store.recentConnections, [connection(2)])
        store.connect(to: connection(8))
        try await Task.sleep(nanoseconds: 100_000_000)
        store.disconnect()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertNil(store.openConnection)
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertFalse(store.isConnected)
        XCTAssertNil(store.connectionFailure)
        XCTAssertEqual(store.status, .idle)
        XCTAssertEqual(store.recentConnections, [connection(2)])
    }

    func testUnexpectedLossPreservesLogicalConnectionAndMessages() async throws {
        var broker = connection(7, password: "fixture-password")
        broker.username = "fixture-user"
        store.connect(to: broker)
        try await waitFor { self.store.isConnected && !self.store.messages.isEmpty }
        try await waitFor { !self.store.isConnected }
        XCTAssertEqual(store.openConnection, broker)
        XCTAssertEqual(store.messages.first?.topic, "broker/7")
        store.reconnectWhenActivated()
        try await waitFor { self.store.isConnected }
        store.disconnect()
        store.reconnectWhenActivated()
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(store.openConnection)
        XCTAssertFalse(store.isConnected)
    }

    func testAuthenticationFailureNotRememberedButSubscriptionFailureIs() async throws {
        store.connect(to: connection(9))
        try await waitFor { self.store.connectionFailure != nil }
        XCTAssertTrue(store.recentConnections.isEmpty)
        store.connect(to: connection(10))
        try await waitFor { self.store.recentConnections.count == 1 && self.store.connectionFailure != nil }
        XCTAssertEqual(store.recentConnections, [connection(10)])
    }
}
