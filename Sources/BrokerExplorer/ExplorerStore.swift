import Foundation
import SwiftUI

@MainActor
final class ExplorerStore: ObservableObject {
    @Published private(set) var openConnection: BrokerConnection?
    @Published private(set) var recentConnections = SettingsStore.loadRecentConnections()
    @Published var connectionDraft = BrokerConnection()
    @Published var connectionSheetOpen = false
    var connection: BrokerConnection { openConnection ?? BrokerConnection() }
    @Published var isConnected = false
    @Published var isScanning = false
    @Published private(set) var connectionFailure: String?
    @Published var messages: [MQTTMessage] = []
    @Published var selectedTopic = ""
    @Published var expandedTopics: Set<String> = []
    @Published var status = ExplorerStatus.idle

    private let mqttService = MQTTService()
    private var scanCompletionTask: Task<Void, Never>?
    private var connectionGeneration = 0
    private var connectionTask: Task<Void, Never>?
    private var shouldReconnectOnActivation = false

    var tree: TopicNode {
        TopicTreeBuilder.build(messages: messages)
    }

    var selectedMessage: MQTTMessage? {
        messages.first { $0.topic == selectedTopic }
    }

    var topicCount: Int {
        messages.count
    }

    func newConnection() {
        connectionDraft = BrokerConnection()
        connectionSheetOpen = true
    }

    func connectDraft() {
        connect(to: connectionDraft)
    }

    func connect() {
        guard let openConnection else { return }
        connect(to: openConnection)
    }

    func connect(to connection: BrokerConnection) {
        openConnection = connection
        connectionSheetOpen = false
        connectionGeneration += 1
        let generation = connectionGeneration
        scanCompletionTask?.cancel()
        shouldReconnectOnActivation = false
        isConnected = false
        connectionFailure = nil
        isScanning = true
        status = .pending("Reading broker...")
        messages = []
        selectedTopic = ""
        expandedTopics = []

        // Await the predecessor even when cancelled: the MQTT operation may still
        // be suspended, and its cleanup must finish before another client opens.
        let previousTask = connectionTask
        previousTask?.cancel()
        connectionTask = Task {
            await previousTask?.value
            guard generation == connectionGeneration, !Task.isCancelled else { return }
            do {
                let brokerName = connection.displayName
                try await mqttService.connect(
                    connection: connection,
                    onConnected: { [weak self] in
                        await self?.remember(connection, generation: generation)
                    },
                    onMessage: { [weak self] message in
                        await self?.receive(message, generation: generation)
                    },
                    onClose: { [weak self] error in
                        await self?.connectionClosed(error: error, generation: generation)
                    }
                )
                guard generation == connectionGeneration else {
                    return
                }

                isConnected = true
                status = .pending("Reading retained topics from \(brokerName)...")
                scheduleScanCompletion()
            } catch {
                try? await mqttService.disconnect()
                guard generation == connectionGeneration else {
                    return
                }

                isConnected = false
                isScanning = false
                connectionFailure = error.localizedDescription
                status = .error(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        openConnection = nil
        connectionSheetOpen = false
        connectionFailure = nil
        connectionGeneration += 1
        scanCompletionTask?.cancel()
        shouldReconnectOnActivation = false
        isConnected = false
        isScanning = false
        clearSession()
        status = .idle

        let generation = connectionGeneration
        let previousTask = connectionTask
        previousTask?.cancel()
        connectionTask = Task {
            await previousTask?.value
            do {
                try await mqttService.disconnect()
            } catch {
                guard generation == connectionGeneration else { return }
                status = .error(error.localizedDescription)
            }
        }
    }

    private func remember(_ connection: BrokerConnection, generation: Int) {
        guard generation == connectionGeneration else { return }
        recentConnections.removeAll { $0.isSameRecentConnection(as: connection) }
        recentConnections.insert(connection, at: 0)
        recentConnections = Array(recentConnections.prefix(5))
        SettingsStore.save(recentConnections: recentConnections)
    }

    func refresh() {
        connect()
    }

    func reconnectWhenActivated() {
        guard openConnection != nil, shouldReconnectOnActivation, !isConnected, !isScanning, connection.canAutoConnect else {
            return
        }

        status = .pending("Reconnecting to \(connection.displayName)...")
        connect()
    }

    func selectTopic(_ topic: String) {
        selectedTopic = topic
    }

    func toggleTopic(_ topic: String) {
        if expandedTopics.contains(topic) {
            expandedTopics.remove(topic)
        } else {
            expandedTopics.insert(topic)
        }
    }

    private func clearSession() {
        messages = []
        selectedTopic = ""
        expandedTopics = []
    }

    func publish(topic: String, payload: String, retain: Bool, qos: Int) {
        let normalized = normalizeTopic(topic)
        guard !normalized.isEmpty else {
            status = .error("Topic is required.")
            return
        }

        selectedTopic = normalized
        expandedTopics.formUnion(ancestorTopics(for: normalized))

        let generation = connectionGeneration
        Task {
            guard generation == connectionGeneration else { return }
            do {
                try await mqttService.publish(topic: normalized, payload: payload, retain: retain, qos: qos)
                guard generation == connectionGeneration else { return }
                publishLocally(topic: normalized, payload: payload, retain: retain, qos: qos)
            } catch {
                guard generation == connectionGeneration else { return }
                status = .error(error.localizedDescription)
            }
        }
    }

    func deleteTree(topic: String) {
        let normalized = normalizeTopic(topic)
        guard !normalized.isEmpty else {
            status = .error("Topic is required.")
            return
        }

        let prefix = "\(normalized)/"
        let topics = messages
            .map(\.topic)
            .filter { $0 == normalized || $0.hasPrefix(prefix) }

        guard !topics.isEmpty else {
            status = .success("No retained topics under \(normalized).")
            return
        }

        let generation = connectionGeneration
        Task {
            guard generation == connectionGeneration else { return }
            do {
                for topic in topics {
                    guard generation == connectionGeneration else { return }
                    try await mqttService.publish(topic: topic, payload: "", retain: true, qos: 1)
                }

                guard generation == connectionGeneration else { return }
                messages.removeAll { topics.contains($0.topic) }
                selectedTopic = messages.first?.topic ?? ""
                status = .success("Deleted \(topics.count) retained \(topics.count == 1 ? "topic" : "topics") under \(normalized).")
            } catch {
                guard generation == connectionGeneration else { return }
                status = .error(error.localizedDescription)
            }
        }
    }

    private func receive(_ message: MQTTMessage, generation: Int) {
        guard generation == connectionGeneration else {
            return
        }

        scanCompletionTask?.cancel()

        if message.payload.isEmpty {
            messages.removeAll { $0.topic == message.topic }
            if selectedTopic == message.topic {
                selectedTopic = messages.first?.topic ?? ""
            }
        } else if let index = messages.firstIndex(where: { $0.topic == message.topic }) {
            messages[index] = message
        } else {
            messages.append(message)
            messages.sort { $0.topic.localizedStandardCompare($1.topic) == .orderedAscending }
        }

        scheduleScanCompletion()
    }

    private func publishLocally(topic: String, payload: String, retain: Bool, qos: Int) {
        let message = MQTTMessage(
            topic: topic,
            payload: payload,
            qos: min(max(qos, 0), 2),
            retain: retain,
            receivedAt: Date()
        )

        if payload.isEmpty && retain {
            messages.removeAll { $0.topic == topic }
            status = .success("Deleted value for \(topic).")
            if selectedTopic == topic {
                selectedTopic = messages.first?.topic ?? ""
            }
            return
        }

        if let index = messages.firstIndex(where: { $0.topic == topic }) {
            messages[index] = message
        } else {
            messages.append(message)
            messages.sort { $0.topic.localizedStandardCompare($1.topic) == .orderedAscending }
        }

        status = .success("Published \(topic) (\(retain ? "retained" : "live"), QoS \(message.qos)).")
    }

    private func scheduleScanCompletion() {
        guard isScanning else {
            return
        }

        scanCompletionTask?.cancel()
        scanCompletionTask = Task {
            try? await Task.sleep(for: .milliseconds(1_800))
            guard !Task.isCancelled else {
                return
            }

            isScanning = false
            status = .success("Connected to \(connection.displayName). Read \(topicCount) retained \(topicCount == 1 ? "topic" : "topics").")
        }
    }

    private func connectionClosed(error: String?, generation: Int) {
        guard generation == connectionGeneration else {
            return
        }

        guard isConnected else {
            return
        }

        isConnected = false
        isScanning = false
        shouldReconnectOnActivation = true
        status = .error(error ?? "Broker connection closed.")
    }
}

enum ExplorerStatus: Equatable {
    case idle
    case pending(String)
    case success(String)
    case error(String)

    var text: String {
        switch self {
        case .idle:
            return ""
        case .pending(let text), .success(let text), .error(let text):
            return text
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "circle"
        case .pending:
            return "clock"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle:
            return .secondary
        case .pending:
            return .secondary
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

extension MQTTMessage {
    static let sampleData = [
        MQTTMessage(
            topic: "home/livingroom/temperature",
            payload: "21.4",
            qos: 0,
            retain: true,
            receivedAt: Date().addingTimeInterval(-12)
        ),
        MQTTMessage(
            topic: "home/livingroom/humidity",
            payload: "45",
            qos: 0,
            retain: true,
            receivedAt: Date().addingTimeInterval(-42)
        ),
        MQTTMessage(
            topic: "home/livingroom/light/state",
            payload: #"{"on":true,"brightness":82,"temperature":2700}"#,
            qos: 1,
            retain: true,
            receivedAt: Date().addingTimeInterval(-88)
        ),
        MQTTMessage(
            topic: "home/office/light/state",
            payload: #"{"on":false,"brightness":0}"#,
            qos: 1,
            retain: false,
            receivedAt: Date().addingTimeInterval(-120)
        ),
        MQTTMessage(
            topic: "home/office/sensor/co2",
            payload: "612",
            qos: 0,
            retain: true,
            receivedAt: Date().addingTimeInterval(-260)
        ),
        MQTTMessage(
            topic: "system/mqtt/status",
            payload: "online",
            qos: 1,
            retain: true,
            receivedAt: Date().addingTimeInterval(-360)
        )
    ]
}
