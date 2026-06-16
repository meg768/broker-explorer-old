import Foundation

struct BrokerConnection: Equatable {
    var url: String = "mqtt://localhost"
    var username: String = ""
    var password: String = ""
    var port: String = "1883"

    var displayName: String {
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Specify a broker"
        }

        guard let parsedURL = URL(string: normalizedURL), let host = parsedURL.host else {
            return url
        }

        return host
    }

    var normalizedURL: String {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = trimmedURL.contains("://") ? trimmedURL : "mqtt://\(trimmedURL)"

        guard var components = URLComponents(string: baseURL) else {
            return baseURL
        }

        if let portValue = Int(port.trimmingCharacters(in: .whitespacesAndNewlines)) {
            components.port = portValue
        }

        return components.string ?? baseURL
    }
}

struct MQTTMessage: Identifiable, Equatable {
    var id: String { topic }
    let topic: String
    var payload: String
    var qos: Int
    var retain: Bool
    var receivedAt: Date

    var payloadPreview: String {
        let normalized = payload
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard normalized.count > 180 else {
            return normalized
        }

        return String(normalized.prefix(180)) + "..."
    }

    var prettyPayload: String {
        guard
            let data = payload.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return payload
        }

        return pretty
    }

    var isJSON: Bool {
        guard let data = payload.data(using: .utf8) else {
            return false
        }

        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}

struct TopicNode: Identifiable, Equatable {
    var id: String { path.isEmpty ? "/" : path }
    let name: String
    let path: String
    var children: [TopicNode]
    var message: MQTTMessage?

    var childCountLabel: String? {
        guard !children.isEmpty else {
            return nil
        }

        return children.count == 1 ? "1 topic" : "\(children.count) topics"
    }
}

enum TopicTreeBuilder {
    static func build(messages: [MQTTMessage]) -> TopicNode {
        let root = MutableTopicNode(name: "", path: "")

        for message in messages {
            let parts = message.topic
                .split(separator: "/")
                .map(String.init)

            guard !parts.isEmpty else {
                continue
            }

            var node = root
            var path = ""

            for part in parts {
                path = path.isEmpty ? part : "\(path)/\(part)"
                node = node.child(named: part, path: path)
            }

            node.message = message
        }

        return root.frozen()
    }
}

private final class MutableTopicNode {
    let name: String
    let path: String
    var children: [String: MutableTopicNode] = [:]
    var message: MQTTMessage?

    init(name: String, path: String) {
        self.name = name
        self.path = path
    }

    func child(named name: String, path: String) -> MutableTopicNode {
        if let existing = children[name] {
            return existing
        }

        let next = MutableTopicNode(name: name, path: path)
        children[name] = next
        return next
    }

    func frozen() -> TopicNode {
        TopicNode(
            name: name,
            path: path,
            children: children.values
                .map { $0.frozen() }
                .sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                },
            message: message
        )
    }
}

func normalizeTopic(_ topic: String) -> String {
    topic
        .trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        .split(separator: "/")
        .filter { !$0.isEmpty }
        .joined(separator: "/")
}

func ancestorTopics(for topic: String) -> Set<String> {
    let parts = normalizeTopic(topic).split(separator: "/").map(String.init)
    guard parts.count > 1 else {
        return []
    }

    return Set(parts.indices.dropLast().map { index in
        parts[0...index].joined(separator: "/")
    })
}
