import SwiftUI

struct CommandFormView: View {
    let existing: Command?
    let onSave: (Command) -> Void
    let onCancel: () -> Void
    let onDelete: (() -> Void)?

    @State private var name: String
    @State private var desc: String
    @State private var script: String
    @State private var icon: String
    @State private var showIconPicker = false

    init(existing: Command? = nil, onSave: @escaping (Command) -> Void, onCancel: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        _name = State(initialValue: existing?.name ?? "")
        _desc = State(initialValue: existing?.description ?? "")
        _script = State(initialValue: existing?.script ?? "")
        _icon = State(initialValue: existing?.icon ?? "terminal")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !script.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(existing == nil ? "New Command" : "Edit Command")
                    .font(.headline)
                Spacer()
                Button { onCancel() } label: {
                    Text("Cancel")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.hover)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("My Command", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("What this command does", text: $desc)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Icon").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button {
                                showIconPicker.toggle()
                            } label: {
                                Image(systemName: icon.isEmpty ? "terminal" : icon)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.hover)
                            .popover(isPresented: $showIconPicker) {
                                IconPickerView(selectedIcon: $icon)
                            }

                            Text(icon.isEmpty ? "terminal" : icon)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Script
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Script").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextEditor(text: $script)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(minHeight: 120)
                    }
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.hover)
                }

                Spacer()

                Button("Save") {
                    let command = Command(
                        name: name.trimmingCharacters(in: .whitespaces),
                        description: desc.trimmingCharacters(in: .whitespaces),
                        script: script,
                        icon: icon.isEmpty ? nil : icon,
                        shortcut: existing?.shortcut
                    )
                    onSave(command)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
        }
    }
}
