import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearance: AppearanceSettings
    @StateObject private var store = ExplorerStore()
    @State private var searchText = ""
    @State private var settingsOpen = SettingsStore.loadConnection().url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    @State private var publishTopic = ""
    @State private var publishPayload = ""
    @State private var publishRetain = true
    @State private var publishQoS = 1
    @State private var editorResetID = UUID()
    @State private var didAutoConnect = false
    @State private var topicPanelWidth = SettingsStore.loadTopicPanelWidth()

    var body: some View {
        VStack(spacing: 8) {
            ConnectionPanel(
                connection: $store.connection,
                isScanning: store.isScanning,
                settingsOpen: $settingsOpen,
                onConnect: store.connect
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
                editorResetID: editorResetID,
                onSelect: store.selectTopic,
                onToggle: store.toggleTopic,
                onPublish: store.publish,
                onDeleteTree: store.deleteTree
            )

            StatusBar(status: store.status, topicCount: store.topicCount)
        }
        .id("\(appearance.mode.rawValue)-\(appearance.surface.rawValue)")
        .padding(8)
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
                settingsOpen = true
                clearPublishPanel()
            }
        }
        .onChange(of: store.connection) { connection in
            SettingsStore.save(connection: connection)
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
    let isScanning: Bool
    @Binding var settingsOpen: Bool
    let onConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        BrokerLabel()

                        Button {
                            settingsOpen.toggle()
                        } label: {
                            PillLabel("Settings")
                        }
                        .buttonStyle(.plain)

                        if settingsOpen {
                            Button {
                                onConnect()
                            } label: {
                                PillLabel(isScanning ? "Reconnect" : "Connect")
                            }
                            .buttonStyle(.plain)
                            .disabled(connection.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    Text(connection.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.heading)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    AppLogoIcon()
                        .frame(width: 34, height: 34)
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("Broker")
                            .font(.system(size: 23, weight: .bold))
                        Text("Explorer")
                            .font(.system(size: 23, weight: .bold))
                    }
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
                .onSubmit {
                    guard !connection.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }

                    onConnect()
                }
            }
        }
        .padding(18)
        .background(AppColors.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AppLogoIcon: View {
    private var icon: NSImage {
        let image = (NSImage(named: "BrokerExplorerIcon") ?? NSApplication.shared.applicationIconImage).copy() as? NSImage
        image?.isTemplate = true
        return image ?? NSApplication.shared.applicationIconImage
    }

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppColors.primaryStrong)
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
    let editorResetID: UUID
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
                    confirmDeleteTree()
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
                    if canFormatJSON {
                        formatJSON()
                    }
                } label: {
                    IconPillLabel(canFormatJSON ? "JSON" : "Text", systemImage: canFormatJSON ? "curlybraces" : "text.alignleft")
                }
                .buttonStyle(.plain)

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
                .id(editorResetID)
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
                    .stroke(border, lineWidth: 1)
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

        return isActive ? AppColors.primary.opacity(0.65) : AppColors.fieldBorder
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
                .stroke(border, lineWidth: 1)
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

        return isActive ? AppColors.primary.opacity(0.65) : AppColors.fieldBorder
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
        .font(.system(size: 13, weight: .semibold))
        .frame(height: 40)
        .padding(.horizontal, 14)
        .background(AppColors.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(AppColors.caption)
            .textCase(.uppercase)
    }
}

struct BrokerLabel: View {
    var body: some View {
        Text("Broker")
            .font(.system(size: 14, weight: .bold))
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
    private static var theme: AppTheme {
        AppTheme.surface(SettingsStore.loadSurfaceTheme())
    }

    static var pageBackground: Color { theme.pageBackground }
    static var windowBackground: Color { pageBackground }
    static var panelBackground: Color { theme.panelBackground }
    static var editorBackground: Color { theme.editorBackground }
    static var inputBackground: Color { theme.inputBackground }
    static var fieldBorder: Color { theme.softBorder }
    static let caption = adaptive(light: nsColor(0.44, 0.46, 0.49), dark: nsColor(0.66, 0.71, 0.69))
    static let heading = adaptive(light: nsColor(0.13, 0.16, 0.24), dark: nsColor(0.93, 0.96, 0.94))
    static let topicName = adaptive(light: nsColor(0.36, 0.38, 0.42), dark: nsColor(0.80, 0.84, 0.82))
    static let treeDisclosure = adaptive(light: nsColor(0.54, 0.58, 0.64), dark: nsColor(0.61, 0.68, 0.65))
    static let treeMuted = adaptive(light: nsColor(0.76, 0.80, 0.86), dark: nsColor(0.40, 0.46, 0.43))
    static let badgeText = adaptive(light: nsColor(0.35, 0.38, 0.46), dark: nsColor(0.72, 0.78, 0.75))
    static var primary: Color { theme.primary }
    static var primaryStrong: Color { theme.primaryStrong }
    static var badgeBackground: Color { theme.softBackground }
    static var neutralBadgeBackground: Color { theme.neutralBackground }
    static var previewBackground: Color { theme.previewBackground }
    static var previewText: Color { theme.previewText }
    static let danger = adaptive(light: nsColor(0.86, 0.20, 0.18), dark: nsColor(1.00, 0.38, 0.34))
    static let dangerBackground = danger.opacity(0.10)
    static var selectionBackground: Color { theme.softBackground }
    static var readOnlyBackground: Color { theme.previewBackground }
    static var readOnlyBorder: Color { theme.softBorder }

    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    static func nsColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}

struct AppTheme {
    let pageBackground: Color
    let panelBackground: Color
    let editorBackground: Color
    let inputBackground: Color
    let primary: Color
    let primaryStrong: Color
    let softBackground: Color
    let softBorder: Color
    let neutralBackground: Color
    let previewBackground: Color
    let previewText: Color

    static func surface(_ surface: AppSurfaceTheme) -> AppTheme {
        switch surface {
        case .hard:
            return AppTheme(
                pageBackground: AppColors.adaptive(light: AppColors.nsColor(0.42, 0.58, 0.72), dark: AppColors.nsColor(0.02, 0.07, 0.14)),
                panelBackground: AppColors.adaptive(light: AppColors.nsColor(0.98, 1.00, 1.00), dark: AppColors.nsColor(0.07, 0.11, 0.17)),
                editorBackground: AppColors.adaptive(light: AppColors.nsColor(0.99, 1.00, 1.00), dark: AppColors.nsColor(0.04, 0.08, 0.14)),
                inputBackground: AppColors.adaptive(light: AppColors.nsColor(0.99, 1.00, 1.00), dark: AppColors.nsColor(0.05, 0.10, 0.16)),
                primary: AppColors.adaptive(light: AppColors.nsColor(0.08, 0.36, 0.62), dark: AppColors.nsColor(0.35, 0.58, 0.86)),
                primaryStrong: AppColors.adaptive(light: AppColors.nsColor(0.02, 0.19, 0.36), dark: AppColors.nsColor(0.73, 0.86, 1.00)),
                softBackground: AppColors.adaptive(light: AppColors.nsColor(0.79, 0.88, 0.96), dark: AppColors.nsColor(0.05, 0.15, 0.25)),
                softBorder: AppColors.adaptive(light: AppColors.nsColor(0.42, 0.62, 0.82), dark: AppColors.nsColor(0.20, 0.42, 0.64)),
                neutralBackground: AppColors.adaptive(light: AppColors.nsColor(0.88, 0.93, 0.97), dark: AppColors.nsColor(0.10, 0.14, 0.20)),
                previewBackground: AppColors.adaptive(light: AppColors.nsColor(0.83, 0.91, 0.98), dark: AppColors.nsColor(0.04, 0.14, 0.24)),
                previewText: AppColors.adaptive(light: AppColors.nsColor(0.04, 0.27, 0.48), dark: AppColors.nsColor(0.54, 0.76, 1.00))
            )
        case .grass:
            return AppTheme(
                pageBackground: AppColors.adaptive(light: AppColors.nsColor(0.38, 0.66, 0.50), dark: AppColors.nsColor(0.01, 0.12, 0.08)),
                panelBackground: AppColors.adaptive(light: AppColors.nsColor(0.99, 1.00, 0.99), dark: AppColors.nsColor(0.07, 0.13, 0.10)),
                editorBackground: AppColors.adaptive(light: AppColors.nsColor(0.99, 1.00, 0.99), dark: AppColors.nsColor(0.04, 0.10, 0.07)),
                inputBackground: AppColors.adaptive(light: AppColors.nsColor(0.99, 1.00, 0.99), dark: AppColors.nsColor(0.05, 0.12, 0.09)),
                primary: AppColors.adaptive(light: AppColors.nsColor(0.02, 0.54, 0.32), dark: AppColors.nsColor(0.24, 0.78, 0.52)),
                primaryStrong: AppColors.adaptive(light: AppColors.nsColor(0.01, 0.36, 0.22), dark: AppColors.nsColor(0.50, 0.92, 0.70)),
                softBackground: AppColors.adaptive(light: AppColors.nsColor(0.78, 0.92, 0.84), dark: AppColors.nsColor(0.04, 0.20, 0.13)),
                softBorder: AppColors.adaptive(light: AppColors.nsColor(0.32, 0.70, 0.52), dark: AppColors.nsColor(0.14, 0.50, 0.32)),
                neutralBackground: AppColors.adaptive(light: AppColors.nsColor(0.89, 0.95, 0.91), dark: AppColors.nsColor(0.10, 0.17, 0.13)),
                previewBackground: AppColors.adaptive(light: AppColors.nsColor(0.80, 0.94, 0.86), dark: AppColors.nsColor(0.03, 0.20, 0.13)),
                previewText: AppColors.adaptive(light: AppColors.nsColor(0.01, 0.40, 0.25), dark: AppColors.nsColor(0.38, 0.90, 0.62))
            )
        case .clay:
            return AppTheme(
                pageBackground: AppColors.adaptive(light: AppColors.nsColor(0.76, 0.50, 0.40), dark: AppColors.nsColor(0.14, 0.06, 0.04)),
                panelBackground: AppColors.adaptive(light: AppColors.nsColor(1.00, 0.99, 0.98), dark: AppColors.nsColor(0.16, 0.09, 0.07)),
                editorBackground: AppColors.adaptive(light: AppColors.nsColor(1.00, 0.99, 0.98), dark: AppColors.nsColor(0.12, 0.07, 0.05)),
                inputBackground: AppColors.adaptive(light: AppColors.nsColor(1.00, 0.99, 0.98), dark: AppColors.nsColor(0.14, 0.08, 0.06)),
                primary: AppColors.adaptive(light: AppColors.nsColor(0.72, 0.28, 0.16), dark: AppColors.nsColor(0.90, 0.48, 0.32)),
                primaryStrong: AppColors.adaptive(light: AppColors.nsColor(0.42, 0.16, 0.09), dark: AppColors.nsColor(1.00, 0.74, 0.62)),
                softBackground: AppColors.adaptive(light: AppColors.nsColor(0.96, 0.82, 0.74), dark: AppColors.nsColor(0.22, 0.11, 0.08)),
                softBorder: AppColors.adaptive(light: AppColors.nsColor(0.78, 0.46, 0.35), dark: AppColors.nsColor(0.60, 0.27, 0.19)),
                neutralBackground: AppColors.adaptive(light: AppColors.nsColor(0.96, 0.89, 0.85), dark: AppColors.nsColor(0.21, 0.14, 0.12)),
                previewBackground: AppColors.adaptive(light: AppColors.nsColor(0.98, 0.86, 0.80), dark: AppColors.nsColor(0.23, 0.12, 0.09)),
                previewText: AppColors.adaptive(light: AppColors.nsColor(0.52, 0.19, 0.10), dark: AppColors.nsColor(0.96, 0.56, 0.40))
            )
        }
    }
}

extension DateFormatter {
    static let explorer: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
