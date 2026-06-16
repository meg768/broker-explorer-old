import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store = ExplorerStore()
    @State private var searchText = SettingsStore.loadSearchText()
    @State private var settingsOpen = SettingsStore.loadSettingsOpen()
    @State private var publishTopic = ""
    @State private var publishPayload = ""
    @State private var publishRetain = true
    @State private var publishQoS = 1
    @State private var didAutoConnect = false
    @State private var topicPanelWidth: CGFloat?

    var body: some View {
        VStack(spacing: 12) {
            ConnectionPanel(
                connection: $store.connection,
                isConnected: store.isConnected,
                isScanning: store.isScanning,
                settingsOpen: $settingsOpen,
                onConnect: store.connect,
                onDisconnect: store.disconnect,
                onRefresh: store.refresh
            )

            ExplorerSplitView(
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
                onSelect: store.selectTopic,
                onToggle: store.toggleTopic,
                onPublish: store.publish,
                onDeleteTree: store.deleteTree
            )

            StatusBar(status: store.status, topicCount: store.topicCount)
        }
        .padding(12)
        .frame(minWidth: 1100, minHeight: 660)
        .background(AppColors.pageBackground)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter topics")
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
                .disabled(!store.isConnected || store.isScanning)

                if store.isConnected {
                    Button {
                        store.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "bolt.slash")
                    }
                } else {
                    Button {
                        store.connect()
                    } label: {
                        Label("Connect", systemImage: "bolt.horizontal")
                    }
                    .disabled(store.isScanning)
                }
            }
        }
        .onAppear {
            hydratePublishPanel(from: store.selectedMessage, topic: store.selectedTopic)
            autoConnectIfPossible()
        }
        .onChange(of: store.selectedTopic) { _ in
            hydratePublishPanel(from: store.selectedMessage, topic: store.selectedTopic)
        }
        .onChange(of: store.selectedMessage) { message in
            hydratePublishPanel(from: message, topic: store.selectedTopic)
        }
        .onChange(of: store.isConnected) { isConnected in
            if isConnected {
                settingsOpen = false
            } else if store.topicCount == 0, store.selectedTopic.isEmpty {
                clearPublishPanel()
            }
        }
        .onChange(of: store.connection) { connection in
            SettingsStore.save(connection: connection)
        }
        .onChange(of: settingsOpen) { isOpen in
            SettingsStore.save(settingsOpen: isOpen)
        }
        .onChange(of: searchText) { text in
            SettingsStore.save(searchText: text)
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

    private func clearPublishPanel() {
        publishTopic = ""
        publishPayload = ""
        publishRetain = true
        publishQoS = 1
    }

    private func autoConnectIfPossible() {
        guard !didAutoConnect, store.connection.canAutoConnect else {
            return
        }

        didAutoConnect = true
        settingsOpen = false
        store.connect()
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
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        FieldLabel("Broker")

                        if isConnected {
                            Button {
                                onDisconnect()
                            } label: {
                                PillLabel("Disconnect")
                            }
                            .buttonStyle(.plain)
                        } else if isScanning {
                            PillLabel("Connecting", isActive: false)
                        } else {
                            Button {
                                onConnect()
                            } label: {
                                PillLabel("Connect")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(connection.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.heading)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 30, weight: .bold))
                    Text("MQTT")
                        .font(.system(size: 28, weight: .bold))
                    Text("Desktop")
                        .font(.system(size: 17, weight: .semibold, design: .serif).italic())
                        .baselineOffset(-1)
                }
                .foregroundStyle(AppColors.primaryStrong)
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
                            .settingsTextField()

                        TextField("", text: $connection.username)
                            .settingsTextField()

                        SecureField("", text: $connection.password)
                            .settingsTextField()

                        TextField("1883", text: $connection.port)
                            .settingsTextField()
                            .frame(width: 84)
                    }
                }
            }
        }
        .padding(18)
        .background(AppColors.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension View {
    func settingsTextField() -> some View {
        self
            .textFieldStyle(.plain)
            .foregroundStyle(AppColors.heading)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(AppColors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.fieldBorder)
            }
    }
}

struct ExplorerSplitView: View {
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
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void
    let onPublish: (String, String, Bool, Int) -> Void
    let onDeleteTree: (String) -> Void
    @State private var dragStartWidth: CGFloat?
    @State private var dragGrabOffset: CGFloat = 0

    private let dividerWidth: CGFloat = 14
    private let minTopicWidth: CGFloat = 420
    private let minPublishWidth: CGFloat = 320
    private let defaultPublishWidth: CGFloat = 360

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let topicWidth = clampedTopicWidth(for: availableWidth)

            HStack(spacing: 0) {
                TopicTreePanel(
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
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStartWidth == nil {
                                    dragStartWidth = topicWidth
                                    dragGrabOffset = value.startLocation.x - (dividerWidth / 2)
                                }

                                topicPanelWidth = clampedTopicWidth(
                                    (dragStartWidth ?? topicWidth) + value.translation.width + dragGrabOffset,
                                    availableWidth: availableWidth
                                )
                            }
                            .onEnded { _ in
                                dragStartWidth = nil
                                dragGrabOffset = 0
                            }
                    )

                PublishPanel(
                    selectedTopic: selectedTopic,
                    selectedMessage: selectedMessage,
                    topic: $publishTopic,
                    payload: $publishPayload,
                    retain: $publishRetain,
                    qos: $publishQoS,
                    onPublish: onPublish,
                    onDeleteTree: onDeleteTree
                )
                .frame(width: max(minPublishWidth, availableWidth - topicWidth - dividerWidth))
            }
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

            Capsule()
                .fill(AppColors.fieldBorder)
                .frame(width: 4)
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
    let root: TopicNode
    let selectedTopic: String
    let expandedTopics: Set<String>
    @Binding var searchText: String
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                FieldLabel("Topics")

                Spacer()

                PillLabel(root.children.isEmpty ? "0 topics" : "\(leafCount(in: root)) topics", isActive: false)
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        node.descendantMessageCount
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
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppColors.heading : AppColors.topicName)
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
                        .foregroundStyle(AppColors.badgeText)
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
    let onPublish: (String, String, Bool, Int) -> Void
    let onDeleteTree: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                FieldLabel("Topic")

                Spacer()

                Button {
                    onPublish(topic, payload, retain, qos)
                } label: {
                    IconPillLabel("Publish", systemImage: "paperplane")
                }
                .buttonStyle(.plain)
                .disabled(normalizeTopic(topic).isEmpty)

                Button {
                    onDeleteTree(topic)
                } label: {
                    IconPillLabel("Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .disabled(normalizeTopic(topic).isEmpty)
            }

            TextField("home/topic", text: $topic)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppColors.heading)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(AppColors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.fieldBorder)
                }

            FieldLabel("Received Time")
            ReadOnlyField(selectedMessage.map { DateFormatter.explorer.string(from: $0.receivedAt) } ?? "-")

            HStack {
                FieldLabel("Message")

                Spacer()

                Button {
                    formatJSON()
                } label: {
                    IconPillLabel(canFormatJSON ? "JSON" : "Text", systemImage: canFormatJSON ? "curlybraces" : "text.alignleft", isActive: canFormatJSON)
                }
                .buttonStyle(.plain)
                .disabled(!canFormatJSON)

                Button {
                    qos = (qos + 1) % 3
                } label: {
                    IconPillLabel("QoS \(qos)", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)

                Button {
                    retain.toggle()
                } label: {
                    IconPillLabel("Retain", systemImage: "pin", isActive: retain)
                }
                .buttonStyle(.plain)
            }

            JSONTextEditor(text: $payload)
                .background(AppColors.editorBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.fieldBorder)
                }
        }
        .padding(18)
        .background(AppColors.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

struct PillLabel: View {
    let text: String
    var isActive = true
    var isDanger = false

    init(_ text: String, isActive: Bool = true, isDanger: Bool = false) {
        self.text = text
        self.isActive = isActive
        self.isDanger = isDanger
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 24)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(border, lineWidth: 1.5)
            }
            .contentShape(Capsule())
    }

    private var foreground: Color {
        if isDanger {
            return AppColors.danger
        }

        return isActive ? AppColors.primaryStrong : AppColors.badgeText
    }

    private var background: Color {
        if isDanger {
            return AppColors.dangerBackground
        }

        return isActive ? AppColors.badgeBackground : AppColors.neutralBadgeBackground
    }

    private var border: Color {
        if isDanger {
            return AppColors.danger.opacity(0.75)
        }

        return isActive ? AppColors.primary : AppColors.fieldBorder
    }
}

struct IconPillLabel: View {
    let text: String
    let systemImage: String
    var isActive = true
    var isDanger = false

    init(_ text: String, systemImage: String, isActive: Bool = true, isDanger: Bool = false) {
        self.text = text
        self.systemImage = systemImage
        self.isActive = isActive
        self.isDanger = isDanger
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))

            Text(text)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .foregroundStyle(foreground)
        .background(background)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(border, lineWidth: 1.5)
        }
        .contentShape(Capsule())
    }

    private var foreground: Color {
        if isDanger {
            return AppColors.danger
        }

        return isActive ? AppColors.primaryStrong : AppColors.badgeText
    }

    private var background: Color {
        if isDanger {
            return AppColors.dangerBackground
        }

        return isActive ? AppColors.badgeBackground : AppColors.neutralBadgeBackground
    }

    private var border: Color {
        if isDanger {
            return AppColors.danger.opacity(0.75)
        }

        return isActive ? AppColors.primary : AppColors.fieldBorder
    }
}

struct FilterField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.badgeText)

            TextField("Filter topics", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.heading)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.badgeText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(AppColors.inputBackground)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(AppColors.fieldBorder)
        }
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
                    .foregroundStyle(AppColors.treeMuted)
                Text("Ready")
                    .foregroundStyle(AppColors.badgeText)
            }

            Spacer()

            Text(topicCount == 1 ? "1 topic" : "\(topicCount) topics")
                .foregroundStyle(AppColors.badgeText)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .frame(height: 34)
        .padding(.horizontal, 14)
        .background(AppColors.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .foregroundStyle(AppColors.caption)
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
            .foregroundStyle(AppColors.heading)
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
            .foregroundStyle(isActive ? AppColors.primaryStrong : AppColors.badgeText)
            .background(isActive ? AppColors.badgeBackground : AppColors.neutralBadgeBackground)
            .clipShape(Capsule())
    }
}

enum AppColors {
    static let pageBackground = Color(red: 0.84, green: 0.91, blue: 0.90)
    static let windowBackground = pageBackground
    static let panelBackground = Color.white
    static let editorBackground = Color.white
    static let inputBackground = Color.white
    static let fieldBorder = Color(red: 0.82, green: 0.86, blue: 0.92)
    static let caption = Color(red: 0.44, green: 0.46, blue: 0.49)
    static let heading = Color(red: 0.13, green: 0.16, blue: 0.24)
    static let topicName = Color(red: 0.36, green: 0.38, blue: 0.42)
    static let treeDisclosure = Color(red: 0.54, green: 0.58, blue: 0.64)
    static let treeMuted = Color(red: 0.76, green: 0.80, blue: 0.86)
    static let badgeText = Color(red: 0.35, green: 0.38, blue: 0.46)
    static let primary = Color(red: 0.18, green: 0.74, blue: 0.51)
    static let primaryStrong = Color(red: 0.08, green: 0.52, blue: 0.36)
    static let badgeBackground = Color(red: 0.91, green: 0.98, blue: 0.95)
    static let neutralBadgeBackground = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let previewBackground = Color(red: 0.93, green: 0.99, blue: 0.96)
    static let previewText = Color(red: 0.02, green: 0.59, blue: 0.41)
    static let danger = Color(red: 0.86, green: 0.20, blue: 0.18)
    static let dangerBackground = Color(red: 0.86, green: 0.20, blue: 0.18).opacity(0.10)
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
