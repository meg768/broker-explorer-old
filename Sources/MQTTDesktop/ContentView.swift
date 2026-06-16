import SwiftUI

struct ContentView: View {
    @StateObject private var store = ExplorerStore()
    @State private var searchText = ""
    @State private var settingsOpen = true
    @State private var publishTopic = ""
    @State private var publishPayload = ""
    @State private var publishRetain = true
    @State private var publishQoS = 1

    var body: some View {
        VStack(spacing: 0) {
            ConnectionPanel(
                connection: $store.connection,
                isConnected: store.isConnected,
                isScanning: store.isScanning,
                settingsOpen: $settingsOpen,
                onConnect: store.connect,
                onDisconnect: store.disconnect,
                onRefresh: store.refresh
            )

            Divider()

            HSplitView {
                TopicTreePanel(
                    root: store.tree,
                    selectedTopic: store.selectedTopic,
                    expandedTopics: store.expandedTopics,
                    searchText: searchText,
                    onSelect: store.selectTopic,
                    onToggle: store.toggleTopic
                )
                .frame(minWidth: 320, idealWidth: 460)

                PublishPanel(
                    selectedTopic: store.selectedTopic,
                    selectedMessage: store.selectedMessage,
                    topic: $publishTopic,
                    payload: $publishPayload,
                    retain: $publishRetain,
                    qos: $publishQoS,
                    canPublish: store.isConnected,
                    onPublish: store.publish,
                    onDeleteTree: store.deleteTree
                )
                .frame(minWidth: 420, idealWidth: 560)
            }

            Divider()

            StatusBar(status: store.status, topicCount: store.topicCount)
        }
        .frame(minWidth: 980, minHeight: 640)
        .background(AppColors.windowBackground)
        .searchable(text: $searchText, prompt: "Filter topics")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    settingsOpen.toggle()
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }

                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isScanning)

                Button {
                    store.isConnected ? store.disconnect() : store.connect()
                } label: {
                    Label(store.isConnected ? "Disconnect" : "Connect", systemImage: store.isConnected ? "bolt.slash" : "bolt.horizontal")
                }
            }
        }
        .onAppear {
            hydratePublishPanel(from: store.selectedMessage, topic: store.selectedTopic)
        }
        .onChange(of: store.selectedTopic) { _ in
            hydratePublishPanel(from: store.selectedMessage, topic: store.selectedTopic)
        }
        .onChange(of: store.selectedMessage) { message in
            hydratePublishPanel(from: message, topic: store.selectedTopic)
        }
    }

    private func hydratePublishPanel(from message: MQTTMessage?, topic: String) {
        if let message {
            publishTopic = message.topic
            publishPayload = message.prettyPayload
            publishRetain = message.retain
            publishQoS = message.qos
        } else {
            publishTopic = topic
            publishPayload = ""
            publishRetain = true
            publishQoS = 1
        }
    }
}

struct ConnectionPanel: View {
    @Binding var connection: BrokerConnection
    let isConnected: Bool
    let isScanning: Bool
    @Binding var settingsOpen: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.badgeBackground)
                        .frame(width: 40, height: 40)

                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Broker")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(connection.displayName)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()

                ConnectionBadge(text: isConnected ? "Connected" : "Offline", isActive: isConnected)

                Button {
                    settingsOpen.toggle()
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }

                Button {
                    onRefresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isScanning)

                Button {
                    isConnected ? onDisconnect() : onConnect()
                } label: {
                    Label(isConnected ? "Disconnect" : "Connect", systemImage: isConnected ? "bolt.slash" : "bolt.horizontal")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            if settingsOpen {
                Grid(alignment: .bottomLeading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        FieldLabel("Broker URL")
                        FieldLabel("Username")
                        FieldLabel("Password")
                        FieldLabel("Port")
                    }

                    GridRow {
                        TextField("mqtt://broker.example.com", text: $connection.url)
                            .textFieldStyle(.roundedBorder)

                        TextField("", text: $connection.username)
                            .textFieldStyle(.roundedBorder)

                        SecureField("", text: $connection.password)
                            .textFieldStyle(.roundedBorder)

                        TextField("1883", text: $connection.port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 84)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.panelBackground)
    }
}

struct TopicTreePanel: View {
    let root: TopicNode
    let selectedTopic: String
    let expandedTopics: Set<String>
    let searchText: String
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Topics")
                    .font(.headline)

                Spacer()

                Text(root.children.isEmpty ? "0" : "\(leafCount(in: root))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.badgeBackground)
                    .clipShape(Capsule())
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredChildren) { node in
                        TopicNodeRow(
                            node: node,
                            selectedTopic: selectedTopic,
                            expandedTopics: expandedTopics,
                            level: 0,
                            onSelect: onSelect,
                            onToggle: onToggle
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .background(AppColors.panelBackground)
    }

    private var filteredChildren: [TopicNode] {
        guard !searchText.isEmpty else {
            return root.children
        }

        return root.children.compactMap { filter(node: $0, text: searchText) }
    }

    private func filter(node: TopicNode, text: String) -> TopicNode? {
        let matchesSelf = node.path.localizedCaseInsensitiveContains(text)
            || node.message?.payload.localizedCaseInsensitiveContains(text) == true
        let children = node.children.compactMap { filter(node: $0, text: text) }

        guard matchesSelf || !children.isEmpty else {
            return nil
        }

        return TopicNode(name: node.name, path: node.path, children: children, message: node.message)
    }

    private func leafCount(in node: TopicNode) -> Int {
        let ownCount = node.message == nil ? 0 : 1
        return ownCount + node.children.reduce(0) { $0 + leafCount(in: $1) }
    }
}

struct TopicNodeRow: View {
    let node: TopicNode
    let selectedTopic: String
    let expandedTopics: Set<String>
    let level: Int
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void

    private var isExpanded: Bool {
        expandedTopics.contains(node.path)
    }

    private var isSelected: Bool {
        selectedTopic == node.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Button {
                    if node.children.isEmpty {
                        onSelect(node.path)
                    } else {
                        onToggle(node.path)
                    }
                } label: {
                    Image(systemName: node.children.isEmpty ? "circle.fill" : (isExpanded ? "chevron.down" : "chevron.right"))
                        .font(.system(size: node.children.isEmpty ? 5 : 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(node.children.isEmpty ? .tertiary : .secondary)
                }
                .buttonStyle(.plain)

                Text(node.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : AppColors.topicName)
                    .lineLimit(1)

                if let preview = node.message?.payloadPreview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppColors.previewText)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.previewBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                if let count = node.childCountLabel {
                    Text(count)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.neutralBadgeBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.leading, CGFloat(level * 18))
            .padding(.horizontal, 6)
            .frame(height: 28)
            .background(isSelected ? AppColors.selectionBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                onSelect(node.path)
                if !node.children.isEmpty {
                    onToggle(node.path)
                }
            }

            if isExpanded {
                ForEach(node.children) { child in
                    TopicNodeRow(
                        node: child,
                        selectedTopic: selectedTopic,
                        expandedTopics: expandedTopics,
                        level: level + 1,
                        onSelect: onSelect,
                        onToggle: onToggle
                    )
                }
            }
        }
    }
}

struct PublishPanel: View {
    let selectedTopic: String
    let selectedMessage: MQTTMessage?
    @Binding var topic: String
    @Binding var payload: String
    @Binding var retain: Bool
    @Binding var qos: Int
    let canPublish: Bool
    let onPublish: (String, String, Bool, Int) -> Void
    let onDeleteTree: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Topic")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("home/topic", text: $topic)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Button {
                            onPublish(topic, payload, retain, qos)
                        } label: {
                            Label("Publish", systemImage: "paperplane")
                        }
                        .disabled(!canPublish || normalizeTopic(topic).isEmpty)

                        Button(role: .destructive) {
                            onDeleteTree(topic)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(!canPublish || normalizeTopic(topic).isEmpty)
                    }

                    HStack(spacing: 8) {
                        Button {
                            qos = (qos + 1) % 3
                        } label: {
                            Text("QoS \(qos)")
                                .frame(width: 48)
                        }
                        .buttonStyle(.bordered)

                        Toggle("Retain", isOn: $retain)
                            .toggleStyle(.switch)
                            .fixedSize()
                    }
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Received Time")
                    ReadOnlyField(selectedMessage.map { DateFormatter.explorer.string(from: $0.receivedAt) } ?? "-")
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Payload Type")
                    ReadOnlyField(selectedMessage?.isJSON == true ? "JSON" : "Text")
                }
            }

            HStack {
                FieldLabel("Message")

                Spacer()

                Button {
                    formatJSON()
                } label: {
                    Label("JSON", systemImage: "curlybraces")
                }
                .disabled(!canFormatJSON)
            }

            TextEditor(text: $payload)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(AppColors.editorBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.fieldBorder)
                }
        }
        .padding(18)
        .background(AppColors.panelBackground)
    }

    private var canFormatJSON: Bool {
        guard let data = payload.data(using: .utf8) else {
            return false
        }

        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private func formatJSON() {
        guard
            let data = payload.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return
        }

        payload = pretty
    }
}

struct StatusBar: View {
    let status: ExplorerStatus
    let topicCount: Int

    var body: some View {
        HStack(spacing: 8) {
            if status != .idle {
                Image(systemName: status.symbolName)
                    .foregroundStyle(status.tint)
                Text(status.text)
                    .foregroundStyle(status.tint)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
                Text("Ready")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(topicCount == 1 ? "1 topic" : "\(topicCount) topics")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .frame(height: 34)
        .padding(.horizontal, 14)
        .background(AppColors.panelBackground)
    }
}

struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

struct ReadOnlyField: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(AppColors.readOnlyBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.readOnlyBorder)
            }
    }
}

struct ConnectionBadge: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isActive ? AppColors.primaryStrong : .secondary)
            .background(isActive ? AppColors.badgeBackground : AppColors.neutralBadgeBackground)
            .clipShape(Capsule())
    }
}

enum AppColors {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let editorBackground = Color(nsColor: .textBackgroundColor)
    static let fieldBorder = Color(nsColor: .separatorColor)
    static let topicName = Color(nsColor: .secondaryLabelColor)
    static let primary = Color(red: 0.18, green: 0.74, blue: 0.51)
    static let primaryStrong = Color(red: 0.08, green: 0.52, blue: 0.36)
    static let badgeBackground = Color(red: 0.91, green: 0.98, blue: 0.95)
    static let neutralBadgeBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.12)
    static let previewBackground = Color(red: 0.93, green: 0.99, blue: 0.96)
    static let previewText = Color(red: 0.02, green: 0.59, blue: 0.41)
    static let selectionBackground = Color.accentColor.opacity(0.16)
    static let readOnlyBackground = Color(red: 0.93, green: 0.99, blue: 0.96)
    static let readOnlyBorder = Color(red: 0.69, green: 0.93, blue: 0.84)
}

extension DateFormatter {
    static let explorer: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
