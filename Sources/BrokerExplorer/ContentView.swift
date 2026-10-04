import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearance: AppearanceSettings
    @EnvironmentObject private var store: ExplorerStore
    @State private var searchText = ""
    @State private var publishTopic = ""
    @State private var publishPayload = ""
    @State private var publishRetain = true
    @State private var publishQoS = 1
    @State private var editorResetID = UUID()
    @State private var topicPanelWidth = SettingsStore.loadTopicPanelWidth()

    var body: some View {
        VStack(spacing: 0) {
            if store.openConnection == nil {
                noConnectionState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ExplorerSplitView(
                    hasBrokerConfiguration: true,
                    connectionFailure: store.connectionFailure,
                    onConfigureBroker: store.newConnection,
                    root: store.tree,
                    selectedTopic: store.selectedTopic,
                    selectedMessage: store.selectedMessage,
                    expandedTopics: store.expandedTopics,
                    searchText: $searchText,
                    topicPanelWidth: $topicPanelWidth,
                    publishTopic: $publishTopic,
                    publishPayload: $publishPayload,
                    publishRetain: $publishRetain,
                    publishQoS: $publishQoS,
                    editorResetID: editorResetID,
                    onSelect: store.selectTopic,
                    onToggle: store.toggleTopic,
                    onPublish: store.publish,
                    onDeleteTree: store.deleteTree
                )
            }

            Divider()
            StatusBar(status: store.status, topicCount: store.topicCount)
        }
        .id("\(appearance.mode.rawValue)-\(appearance.surface.rawValue)")
        .frame(minWidth: 1100, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter topics")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.newConnection()
                } label: {
                    Label("New Connection…", systemImage: "slider.horizontal.3")
                }

                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!store.isConnected || store.isScanning)

                if store.isConnected {
                    Button {
                        store.disconnect()
                    } label: {
                        Label("Close Connection", systemImage: "bolt.slash")
                    }
                } else {
                    Button {
                        store.openConnection == nil ? store.newConnection() : store.connect()
                    } label: {
                        Label("Connect", systemImage: "bolt.horizontal")
                    }
                }
            }
        }
        .navigationTitle(store.openConnection?.displayName ?? "Broker Explorer")
        .sheet(isPresented: $store.connectionSheetOpen) {
            ConnectionSheet(
                connection: $store.connectionDraft,
                isScanning: store.isScanning,
                status: store.status,
                onConnect: store.connectDraft,
                onClose: { store.connectionSheetOpen = false }
            )
        }
        .onAppear {
            hydratePublishPanel(from: store.selectedMessage, topic: store.selectedTopic)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.reconnectWhenActivated()
        }
        .onChange(of: store.selectedTopic) { _ in
            hydratePublishPanel(from: store.selectedMessage, topic: store.selectedTopic)
        }
        .onChange(of: store.selectedMessage) { message in
            hydratePublishPanel(from: message, topic: store.selectedTopic)
        }
        .onChange(of: store.openConnection) { connection in
            if connection == nil { clearPublishPanel() }
        }
        .onChange(of: topicPanelWidth) { width in
            SettingsStore.save(topicPanelWidth: width)
        }
        .modifier(FunctionKeyShortcut(keyCode: 97, functionKey: NSF6FunctionKey) {
            appearance.toggle(over: colorScheme)
        })
        .modifier(FunctionKeyShortcut(keyCode: 99, functionKey: NSF3FunctionKey) {
            appearance.cycleSurface()
        })
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

        editorResetID = UUID()
    }

    private func clearPublishPanel() {
        publishTopic = ""
        publishPayload = ""
        publishRetain = true
        publishQoS = 1
        editorResetID = UUID()
    }

    @ViewBuilder
    private var noConnectionState: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView {
                Label("No Connection Open", systemImage: "network")
            } description: {
                Text("Create a new connection or choose Connection → Open Recent.")
            } actions: {
                Button("New Connection…", action: store.newConnection)
            }
        } else {
            VStack {
                Label("No Connection Open", systemImage: "network").font(.headline)
                Text("Create a new connection or choose Connection → Open Recent.").foregroundStyle(.secondary)
                Button("New Connection…", action: store.newConnection)
            }
        }
    }

}

struct ConnectionSheet: View {
    @Binding var connection: BrokerConnection
    let isScanning: Bool
    let status: ExplorerStatus
    let onConnect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connection")
                .font(.headline)

            Form {
                TextField("Broker URL", text: $connection.url, prompt: Text("mqtt://broker.example.com"))
                TextField("Username", text: $connection.username)
                SecureField("Password", text: $connection.password)
                TextField("Port", text: $connection.port, prompt: Text("1883"))
            }
            .textFieldStyle(.roundedBorder)
            .onSubmit(connectIfPossible)

            if status != .idle {
                Label(status.text, systemImage: status.symbolName)
                    .font(.callout)
                    .foregroundStyle(status.tint)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Connect", action: connectIfPossible)
                    .disabled(connection.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func connectIfPossible() {
        guard !connection.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        onConnect()
    }
}

struct ExplorerSplitView: View {
    let hasBrokerConfiguration: Bool
    let connectionFailure: String?
    let onConfigureBroker: () -> Void
    let root: TopicNode
    let selectedTopic: String
    let selectedMessage: MQTTMessage?
    let expandedTopics: Set<String>
    @Binding var searchText: String
    @Binding var topicPanelWidth: CGFloat?
    @Binding var publishTopic: String
    @Binding var publishPayload: String
    @Binding var publishRetain: Bool
    @Binding var publishQoS: Int
    let editorResetID: UUID
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void
    let onPublish: (String, String, Bool, Int) -> Void
    let onDeleteTree: (String) -> Void

    private let dividerWidth: CGFloat = 10
    private let minTopicWidth: CGFloat = 420
    private let minPublishWidth: CGFloat = 320
    private let defaultPublishWidth: CGFloat = 360

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let topicWidth = clampedTopicWidth(for: availableWidth)

            HStack(spacing: 0) {
                TopicTreePanel(
                    hasBrokerConfiguration: hasBrokerConfiguration,
                    connectionFailure: connectionFailure,
                    onConfigureBroker: onConfigureBroker,
                    root: root,
                    selectedTopic: selectedTopic,
                    expandedTopics: expandedTopics,
                    searchText: $searchText,
                    onSelect: onSelect,
                    onToggle: onToggle
                )
                .frame(width: topicWidth)

                SplitDivider()
                    .frame(width: dividerWidth)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("ExplorerSplitView"))
                            .onChanged { value in
                                topicPanelWidth = clampedTopicWidth(
                                    value.location.x - (dividerWidth / 2),
                                    availableWidth: availableWidth
                                )
                            }
                    )

                PublishPanel(
                    selectedTopic: selectedTopic,
                    selectedMessage: selectedMessage,
                    topic: $publishTopic,
                    payload: $publishPayload,
                    retain: $publishRetain,
                    qos: $publishQoS,
                    editorResetID: editorResetID,
                    onPublish: onPublish,
                    onDeleteTree: onDeleteTree
                )
                .frame(width: max(minPublishWidth, availableWidth - topicWidth - dividerWidth))
            }
            .coordinateSpace(name: "ExplorerSplitView")
        }
    }

    private func clampedTopicWidth(for availableWidth: CGFloat) -> CGFloat {
        let preferredWidth = topicPanelWidth ?? max(minTopicWidth, availableWidth - dividerWidth - defaultPublishWidth)
        return clampedTopicWidth(preferredWidth, availableWidth: availableWidth)
    }

    private func clampedTopicWidth(_ width: CGFloat, availableWidth: CGFloat) -> CGFloat {
        let maxTopicWidth = max(minTopicWidth, availableWidth - dividerWidth - minPublishWidth)
        return min(max(width, minTopicWidth), maxTopicWidth)
    }
}

struct SplitDivider: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            HStack(spacing: 0) {
                Divider()
            }
            .frame(maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

struct TopicTreePanel: View {
    let hasBrokerConfiguration: Bool
    let connectionFailure: String?
    let onConfigureBroker: () -> Void
    let root: TopicNode
    let selectedTopic: String
    let expandedTopics: Set<String>
    @Binding var searchText: String
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Topics")

                Spacer()

                Text(root.children.isEmpty ? "0 topics" : "\(leafCount(in: root)) topics")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 10)

            if !hasBrokerConfiguration || connectionFailure != nil {
                brokerConfigurationEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        }
        .background(AppColors.panelBackground)
    }

    private var emptyStateTitle: String {
        connectionFailure == nil ? "No Broker Configured" : "Connection Failed"
    }

    private var emptyStateDescription: String {
        connectionFailure ?? "Enter your MQTT broker details to get started."
    }

    @ViewBuilder
    private var brokerConfigurationEmptyState: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView {
                Label(emptyStateTitle, systemImage: "network")
            } description: {
                Text(emptyStateDescription)
            } actions: {
                Button("Configure Broker…", action: onConfigureBroker)
            }
        } else {
            VStack {
                Label(emptyStateTitle, systemImage: "network")
                    .font(.headline)
                Text(emptyStateDescription)
                    .foregroundStyle(.secondary)
                Button("Configure Broker…", action: onConfigureBroker)
            }
        }
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
            HStack(alignment: node.children.isEmpty ? .firstTextBaseline : .center, spacing: 6) {
                Button {
                    onSelect(node.path)
                    if !node.children.isEmpty {
                        onToggle(node.path)
                    }
                } label: {
                    Image(systemName: node.children.isEmpty ? "circle.fill" : (isExpanded ? "chevron.down" : "chevron.right"))
                        .font(.system(size: node.children.isEmpty ? 5 : 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(node.children.isEmpty ? AppColors.treeMuted : AppColors.treeDisclosure)
                }
                .buttonStyle(.plain)

                Text(node.name)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColors.heading : AppColors.topicName)
                    .lineLimit(1)

                if let preview = node.message?.payloadPreview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(AppColors.previewText)
                        .lineLimit(1)
                }

                if let count = node.childCountLabel {
                    Text(count)
                        .font(.callout)
                        .foregroundStyle(AppColors.badgeText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.leading, CGFloat(level * 18))
            .padding(.horizontal, 6)
            .frame(height: 28)
            .background(isSelected ? AppColors.selectionBackground : Color.clear)
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
    let editorResetID: UUID
    let onPublish: (String, String, Bool, Int) -> Void
    let onDeleteTree: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Topic")

                Spacer()

                Button {
                    onPublish(topic, payload, retain, qos)
                } label: {
                    Label("Publish", systemImage: "paperplane")
                }
                .disabled(normalizeTopic(topic).isEmpty)

                Button(role: .destructive) {
                    confirmDeleteTree()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(normalizeTopic(topic).isEmpty)
            }

            TopicTextField(text: $topic)
                .frame(maxWidth: .infinity)
                .frame(height: 36)

            Group {
                if let message = selectedMessage {
                    Text(message.receivedAt, format: .dateTime.locale(.autoupdatingCurrent))
                } else {
                    Text("-")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)

            HStack {
                Text("Message")

                Spacer()

                Button {
                    if canFormatJSON {
                        formatJSON()
                    }
                } label: {
                    Label(canFormatJSON ? "JSON" : "Text", systemImage: canFormatJSON ? "curlybraces" : "text.alignleft")
                }

                Button {
                    qos = (qos + 1) % 3
                } label: {
                    Label("QoS \(qos)", systemImage: "slider.horizontal.3")
                }

                Toggle(isOn: $retain) {
                    Label("Retain", systemImage: "pin")
                }
                .toggleStyle(.button)
            }

            JSONTextEditor(text: $payload)
                .id(editorResetID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.editorBackground, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(nsColor: .separatorColor))
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("Message payload")
        }
        .padding()
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

    private func confirmDeleteTree() {
        let normalized = normalizeTopic(topic)
        guard !normalized.isEmpty else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete retained topics?"
        alert.informativeText = "Delete all retained topics under \"\(normalized)/#\"?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        onDeleteTree(normalized)
    }
}

struct StatusBar: View {
    let status: ExplorerStatus
    let topicCount: Int

    var body: some View {
        HStack(spacing: 8) {
            if status != .idle {
                Image(systemName: status.symbolName)
                    .foregroundStyle(statusTint)
                Text(status.text)
                    .foregroundStyle(statusTint)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(AppColors.treeMuted)
                Text("Ready")
                    .foregroundStyle(AppColors.badgeText)
            }

            Spacer()

            Text(topicCount == 1 ? "1 topic" : "\(topicCount) topics")
                .foregroundStyle(AppColors.badgeText)
        }
        .font(.callout)
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(AppColors.panelBackground)
    }

    private var statusTint: Color {
        switch status {
        case .idle, .pending:
            return AppColors.badgeText
        case .success:
            return AppColors.primaryStrong
        case .error:
            return AppColors.danger
        }
    }
}

struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

// Semantic colors for the existing custom tree. Selection remains custom until
// the separately scoped outline migration; no tennis palette is used here.
enum AppColors {
    static let panelBackground = Color(nsColor: .windowBackgroundColor)
    static let editorBackground = Color(nsColor: .textBackgroundColor)
    static let heading = Color.primary
    static let topicName = Color.primary
    static let treeDisclosure = Color.secondary
    static let treeMuted = Color.secondary
    static let badgeText = Color.secondary
    static let previewText = Color.secondary
    static let selectionBackground = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    static let primaryStrong = Color.secondary
    static let danger = Color.red
}

extension DateFormatter {
    static let explorer: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
