import SwiftUI

struct CommandCard: View {
    let command: Command
    let isSelected: Bool
    var showsDropIndicator: Bool = false
    let onEdit: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Image(systemName: command.icon ?? "terminal")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.accentColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(spacing: 2) {
                    Text(command.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(command.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.center)
                }

                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)

            // Edit button on hover
            if isHovered {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.hover)
                .padding(6)
            }
        }
        .background(isSelected ? Color.accentColor.opacity(0.15) : isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            DropIndicatorBar(isVisible: showsDropIndicator)
                .padding(.vertical, 8)
                .padding(.leading, 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : isHovered ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct AddCommandCard: View {
    var isSelected: Bool = false
    var showsDropIndicator: Bool = false

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 36, height: 36)

            Text("Add Command")
                .font(.caption.weight(.medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : isHovered ? Color.primary.opacity(0.06) : Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            DropIndicatorBar(isVisible: showsDropIndicator)
                .padding(.vertical, 8)
                .padding(.leading, 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.5)) : isHovered ? AnyShapeStyle(Color.primary.opacity(0.15)) : AnyShapeStyle(.quaternary),
                    style: StrokeStyle(lineWidth: 1.5, dash: isSelected || isHovered ? [] : [6])
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct DropIndicatorBar: View {
    let isVisible: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(0.9))
            .frame(width: 4)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.12), value: isVisible)
    }
}
