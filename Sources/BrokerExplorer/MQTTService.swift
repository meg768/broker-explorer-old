import Foundation
import MQTTNIO
import NIOCore
import NIOPosix

actor MQTTService {
    private var client: MQTTClient?
    private var listenerTask: Task<Void, Never>?

    func connect(
        connection: BrokerConnection,
        onMessage: @escaping @Sendable (MQTTMessage) async -> Void,
        onClose: @escaping @Sendable (String?) async -> Void
    ) async throws {
        try await disconnect()

        let endpoint = try MQTTEndpoint(connection: connection)
        let client = MQTTClient(
            host: endpoint.host,
            port: endpoint.port,
            identifier: "broker-explorer-\(UUID().uuidString)",
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            configuration: .init(
                userName: endpoint.username,
                password: endpoint.password,
                useSSL: endpoint.useSSL
            )
        )

        self.client = client

        client.addCloseListener(named: "broker-explorer-close") { result in
            Task {
                switch result {
                case .success:
                    await onClose(nil)
                case .failure(let error):
                    await onClose(error.localizedDescription)
                }
            }
        }

        try await client.connect()

        let listener = client.createPublishListener()
        listenerTask = Task {
            for await result in listener {
                switch result {
                case .success(let publish):
                    let message = Self.message(from: publish)
                    await onMessage(message)
                case .failure(let error):
                    await onClose(error.localizedDescription)
                }
            }
        }

        _ = try await client.subscribe(to: [
            MQTTSubscribeInfo(topicFilter: "#", qos: .atLeastOnce)
        ])
    }

    func disconnect() async throws {
        listenerTask?.cancel()
        listenerTask = nil

        guard let client else {
            return
        }

        do {
            try await client.disconnect()
        } catch {
            // Shutdown is still required; MQTTClient traps if deinitialized before shutdown.
        }

        try await client.shutdown()
        self.client = nil
    }

    func publish(topic: String, payload: String, retain: Bool, qos: Int) async throws {
        guard let client else {
            throw MQTTServiceError.notConnected
        }

        try await client.publish(
            to: topic,
            payload: ByteBuffer(string: payload),
            qos: MQTTQoS(value: qos),
            retain: retain
        )
    }

    private static func message(from publish: MQTTPublishInfo) -> MQTTMessage {
        var payload = publish.payload
        let payloadString = payload.readString(length: payload.readableBytes) ?? ""

        return MQTTMessage(
            topic: publish.topicName,
            payload: payloadString,
            qos: Int(publish.qos.rawValue),
            retain: publish.retain,
            receivedAt: Date()
        )
    }
}

private struct MQTTEndpoint {
    let host: String
    let port: Int
    let username: String?
    let password: String?
    let useSSL: Bool

    init(connection: BrokerConnection) throws {
        guard let components = URLComponents(string: connection.normalizedURL), let host = components.host else {
            throw MQTTServiceError.invalidBrokerURL
        }

        guard components.scheme == "mqtt" || components.scheme == "mqtts" else {
            throw MQTTServiceError.unsupportedScheme
        }

        self.host = host
        self.useSSL = components.scheme == "mqtts"
        self.port = components.port ?? (useSSL ? 8883 : 1883)
        self.username = connection.username.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.password = connection.password.nilIfEmpty
    }
}

enum MQTTServiceError: LocalizedError {
    case invalidBrokerURL
    case unsupportedScheme
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidBrokerURL:
            return "Broker URL is invalid."
        case .unsupportedScheme:
            return "Use mqtt:// or mqtts://."
        case .notConnected:
            return "Connect to a broker first."
        }
    }
}

private extension MQTTQoS {
    init(value: Int) {
        switch value {
        case 0:
            self = .atMostOnce
        case 2:
            self = .exactlyOnce
        default:
            self = .atLeastOnce
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
