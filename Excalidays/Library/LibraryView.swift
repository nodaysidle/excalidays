import SwiftUI

struct LibraryView: View {
    let createNewDrawing: () -> Void
    let openDrawing: () -> Void

    @State private var selectedSection: String? = "Recents"

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            detailContent
        }
        .frame(minWidth: 800, minHeight: 520)
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        ZStack {
            sidebarBackground

            List(selection: $selectedSection) {
                Section("Library") {
                    sidebarRow(title: "Recents", icon: "clock.fill", id: "Recents")
                    sidebarRow(title: "Favorites", icon: "star.fill", id: "Favorites")
                    sidebarRow(title: "Tags", icon: "tag.fill", id: "Tags")
                    sidebarRow(title: "Workspaces", icon: "folder.fill", id: "Workspaces")
                    sidebarRow(title: "Missing Files", icon: "questionmark.folder.fill", id: "Missing Files")
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Excalidays")
        .accessibilityLabel("Drawing library sections")
    }

    private func sidebarRow(title: String, icon: String, id: String) -> some View {
        Label {
            Text(title)
                .font(.system(.body, design: .rounded))
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .tag(id)
    }

    private var sidebarBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }

    // MARK: - Detail

    private var detailContent: some View {
        ZStack {
            liquidBackground

            ScrollView {
                VStack(spacing: 32) {
                    heroHeader

                    actionsSection

                    featuresPillRow
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 40)
                .frame(maxWidth: 680)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.4), Color.cyan.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)

                if let image = NSImage(named: "AppLogo") {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
                } else {
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                }
            }

            VStack(spacing: 8) {
                Text("Excalidays")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Create, edit, and organize Excalidraw drawings natively on your Mac.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cyan)
                Text("Local-first • Zero tracking • Native macOS")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        HStack(spacing: 16) {
            Button(action: createNewDrawing) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Drawing")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("⌘N")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .opacity(0.8)
                    }
                }
                .frame(minWidth: 160, minHeight: 44)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.85), Color.purple.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .foregroundStyle(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Color.cyan.opacity(0.35), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityHint("Creates a new editable Excalidraw document")

            Button(action: openDrawing) {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Drawing…")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("⌘O")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 160, minHeight: 44)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
            .accessibilityHint("Opens a native file panel")
        }
    }

    // MARK: - Features / Tips Cards

    private var featuresPillRow: some View {
        HStack(spacing: 12) {
            glassCard(icon: "pencil.and.outline", title: "Hand-drawn feel", subtitle: "Excalidraw canvas engine")
            glassCard(icon: "macwindow", title: "Pure Apple App", subtitle: "Tabs, windows, autosave")
            glassCard(icon: "shield.lefthalf.filled", title: "100% Offline", subtitle: "Your files stay on Mac")
        }
    }

    private func glassCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Ambient Liquid Background

    private var liquidBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            GeometryReader { proxy in
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: proxy.size.width * 0.55)
                    .blur(radius: 80)
                    .offset(x: -proxy.size.width * 0.15, y: -proxy.size.height * 0.15)

                Circle()
                    .fill(Color.cyan.opacity(0.16))
                    .frame(width: proxy.size.width * 0.6)
                    .blur(radius: 90)
                    .offset(x: proxy.size.width * 0.45, y: proxy.size.height * 0.35)

                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: proxy.size.width * 0.45)
                    .blur(radius: 75)
                    .offset(x: proxy.size.width * 0.2, y: -proxy.size.height * 0.1)
            }
            .ignoresSafeArea()
        }
    }
}
