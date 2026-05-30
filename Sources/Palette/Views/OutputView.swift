import SwiftUI

struct OutputView: View {
    let result: CommandResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(result.exitCode == 0 ? .green : .red)
                    .frame(width: 8, height: 8)
                Text("exit \(result.exitCode)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(result.output.isEmpty ? result.error : result.output)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 150)
            .padding(8)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
    }
}
