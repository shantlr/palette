import SwiftUI

struct SettingsView: View {
    let configPath: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.hover)

                Text("Settings")
                    .font(.headline)

                Spacer()
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Config file location
                VStack(alignment: .leading, spacing: 6) {
                    Text("Commands file")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(configPath)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button {
                            NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
                        } label: {
                            Image(systemName: "folder")
                                .font(.body)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.hover)
                        .help("Reveal in Finder")

                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
                        } label: {
                            Image(systemName: "pencil.and.outline")
                                .font(.body)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.hover)
                        .help("Open in editor")
                    }
                }

                // Hotkey info
                VStack(alignment: .leading, spacing: 6) {
                    Text("Global shortcut")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("⌘ ⇧ Space")
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Screen brush shortcut")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("⌘ ⇧ 6")
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)

            Spacer()
        }
    }
}
