import SwiftUI

struct ContentView: View {
    @State private var selectedTopicID: Topic.ID?
    @State private var searchText = ""

    private let topics = Topic.sampleData

    var selectedTopic: Topic? {
        topics.first { $0.id == selectedTopicID } ?? topics.first
    }

    var body: some View {
        NavigationSplitView {
            BrokerSidebar()
        } content: {
            TopicList(
                topics: topics,
                selectedTopicID: $selectedTopicID,
                searchText: searchText
            )
            .navigationTitle("Topics")
            .searchable(text: $searchText, prompt: "Filter topics")
        } detail: {
            TopicDetail(topic: selectedTopic)
        }
        .frame(minWidth: 980, minHeight: 620)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    // MQTT connection will be wired here.
                } label: {
                    Label("Connect", systemImage: "bolt.horizontal")
                }

                Button {
                    // Publish action will be wired here.
                } label: {
                    Label("Publish", systemImage: "paperplane")
                }
            }
        }
    }
}

struct BrokerSidebar: View {
    var body: some View {
        List {
            Section("Connections") {
                Label("Local Broker", systemImage: "server.rack")
            }
        }
        .navigationTitle("MQTT Desktop")
        .safeAreaInset(edge: .bottom) {
            Button {
                // Broker profile editor will be wired here.
            } label: {
                Label("Add Broker", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
}

struct TopicList: View {
    let topics: [Topic]
    @Binding var selectedTopicID: Topic.ID?
    let searchText: String

    var filteredTopics: [Topic] {
        guard !searchText.isEmpty else {
            return topics
        }

        return topics.filter {
            $0.path.localizedCaseInsensitiveContains(searchText)
                || $0.payload.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(selection: $selectedTopicID) {
            ForEach(filteredTopics) { topic in
                TopicRow(topic: topic)
                    .tag(topic.id)
            }
        }
    }
}

struct TopicRow: View {
    let topic: Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(topic.path)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Text(topic.payload)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(topic.updatedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TopicDetail: View {
    let topic: Topic?

    var body: some View {
        Group {
            if let topic {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.path)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("QoS \(topic.qos) - \(topic.isRetained ? "Retained" : "Not retained")")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(topic.updatedAt, style: .time)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Text("Payload")
                        .font(.headline)

                    ScrollView {
                        Text(topic.payload)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()
                }
                .padding(24)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("No Topic Selected")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Connect to a broker and select a topic.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct Topic: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let payload: String
    let qos: Int
    let isRetained: Bool
    let updatedAt: Date

    static let sampleData = [
        Topic(
            path: "home/livingroom/temperature",
            payload: "21.4",
            qos: 0,
            isRetained: true,
            updatedAt: Date()
        ),
        Topic(
            path: "home/livingroom/humidity",
            payload: "45",
            qos: 0,
            isRetained: true,
            updatedAt: Date().addingTimeInterval(-42)
        ),
        Topic(
            path: "home/office/light/state",
            payload: #"{"on":true,"brightness":82}"#,
            qos: 1,
            isRetained: false,
            updatedAt: Date().addingTimeInterval(-120)
        )
    ]
}
