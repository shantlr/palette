import SwiftUI

struct CommandCard: View {
    let command: Command
    let isSelected: Bool
    var isDropTarget: Bool = false
    var isDragging: Bool = false
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
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                Text(command.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

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
            .frame(minHeight: 82, alignment: .top)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)

            // Edit button on hover
            if isHovered {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.hover)
            .padding(5)
            }
        }
        .background(isSelected ? Color.accentColor.opacity(0.15) : isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    isDropTarget ? Color.accentColor.opacity(0.9) : isSelected ? Color.accentColor.opacity(0.5) : isHovered ? Color.primary.opacity(0.1) : Color.clear,
                    lineWidth: isDropTarget ? 2 : 1.5
                )
        )
        .contentShape(Rectangle())
        .opacity(isDragging ? 0.35 : 1)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct AddCommandCard: View {
    var isSelected: Bool = false

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 36, height: 36)

            Text("Add Command")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 82, alignment: .top)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : isHovered ? Color.primary.opacity(0.06) : Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
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

struct EmptyCommandCell: View {
    var isDropTarget: Bool = false
    var isVisible: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isVisible ? Color.primary.opacity(0.025) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(
                        isDropTarget ? AnyShapeStyle(Color.accentColor.opacity(0.9)) : AnyShapeStyle(.quaternary),
                        style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: isDropTarget ? [] : [6])
                    )
                    .opacity(isVisible ? 1 : 0)
            )
            .frame(minHeight: 98)
            .animation(.easeInOut(duration: 0.12), value: isDropTarget)
            .animation(.easeInOut(duration: 0.12), value: isVisible)
    }
}
