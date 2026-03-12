import SwiftUI

struct DependencyOverlay: View {
    let status: DependencyStatus?
    @Binding var isVisible: Bool
    @State private var showRow = false
    @State private var dismissing = false

    var body: some View {
        if isVisible, let status {
            ZStack(alignment: .top) {
                Color(nsColor: .shadowColor).opacity(0.4)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    Text("System Check")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)

                    HStack(spacing: 8) {
                        Image(systemName: status.xcodeTools ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(status.xcodeTools ? .green : .red)
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Xcode Command Line Tools")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                            if !status.xcodeTools {
                                Text("Required for compiling Swift agent scripts")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .opacity(showRow ? 1 : 0)
                    .offset(y: showRow ? 0 : 8)

                    if !status.allGood {
                        HStack {
                            Button("Install") {
                                DependencyChecker.installCommandLineTools()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .font(.system(.caption, design: .monospaced))

                            Spacer()

                            Button("Dismiss") {
                                dismiss()
                            }
                            .buttonStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                        .shadow(radius: 20)
                )
                .frame(width: 320)
                .padding(.top, 80)
                .scaleEffect(dismissing ? 0.8 : 1.0)
                .opacity(dismissing ? 0 : 1)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(0.2)) { showRow = true }

                if status.allGood {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.3)) {
            dismissing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
        }
    }
}
