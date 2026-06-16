import Foundation
import SwiftUI

@MainActor
final class ExplorerStore: ObservableObject {
    @Published var connection = BrokerConnection()
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var messages: [MQTTMessage] = MQTTMessage.sampleData
    @Published var selectedTopic = "home/livingroom/temperature"
    @Published var expandedTopics: Set<String> = ["home", "home/livingroom", "home/office", "system"]
    @Published var status = ExplorerStatus.idle

    var tree: TopicNode {
        TopicTreeBuilder.build(messages: messages)
    }

    var selectedMessage: MQTTMessage? {
        messages.first { $0.topic == selectedTopic }
    }

    var topicCount: Int {
        messages.count
    }

    func connect() {
        isConnected = true
        isScanning = true
        status = .pending("Reading broker...")

        Task {
            try? await Task.sleep(for: .milliseconds(900))
            isScanning = false
            status = .success("Connected to \(connection.displayName). Read \(topicCount) retained topics.")
        }
    }

    func disconnect() {
        isConnected = false
        isScanning = false
        status = .idle
    }

    func refresh() {
        guard isConnected else {
            connect()
            return
        }

        isScanning = true
        status = .pending("Reading broker...")

        Task {
            try? await Task.sleep(for: .milliseconds(700))
            isScanning = false
            status = .success("Refresh complete. Read \(topicCount) retained topics.")
        }
    }

    func selectTopic(_ topic: String) {
        selectedTopic = topic
        expandedTopics.formUnion(ancestorTopics(for: topic))
    }

    func toggleTopic(_ topic: String) {
        if expandedTopics.contains(topic) {
            expandedTopics.remove(topic)
        } else {
            expandedTopics.insert(topic)
        }
    }

    func publish(topic: String, payload: String, retain: Bool, qos: Int) {
        let normalized = normalizeTopic(topic)
        guard !normalized.isEmpty else {
            status = .error("Topic is required.")
            return
        }

        let message = MQTTMessage(
            topic: normalized,
            payload: payload,
            qos: min(max(qos, 0), 2),
            retain: retain,
            receivedAt: Date()
        )

        if payload.isEmpty && retain {
            messages.removeAll { $0.topic == normalized }
            status = .success("Deleted value for \(normalized).")
            if selectedTopic == normalized {
                selectedTopic = messages.first?.topic ?? ""
            }
        } else if let index = messages.firstIndex(where: { $0.topic == normalized }) {
            messages[index] = message
            status = .success("Published \(normalized) (\(retain ? "retained" : "live"), QoS \(message.qos)).")
            selectTopic(normalized)
        } else {
            messages.append(message)
            messages.sort { $0.topic.localizedStandardCompare($1.topic) == .orderedAscending }
            status = .success("Published \(normalized) (\(retain ? "retained" : "live"), QoS \(message.qos)).")
            selectTopic(normalized)
        }
    }

    func deleteTree(topic: String) {
        let normalized = normalizeTopic(topic)
        guard !normalized.isEmpty else {
            status = .error("Topic is required.")
            return
        }

        let prefix = "\(normalized)/"
        let deletedCount = messages.filter { $0.topic == normalized || $0.topic.hasPrefix(prefix) }.count
        messages.removeAll { $0.topic == normalized || $0.topic.hasPrefix(prefix) }
        selectedTopic = messages.first?.topic ?? ""
        status = .success("Deleted \(deletedCount) retained \(deletedCount == 1 ? "topic" : "topics") under \(normalized).")
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
