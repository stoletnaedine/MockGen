import SwiftUI

// MARK: - NSTextView Wrapper для правильного скролла и выделения
struct TextViewRepresentable: NSViewRepresentable {
    var text: String

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.string = text
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        textView.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)

        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.string = text
    }
}

struct ContentView: View {
    @StateObject var viewModel = MockGenViewModel()
    @FocusState private var focusedField: FocusField?

    enum FocusField {
        case `protocol`
        case moduleName
        case authorName
        case appName
    }

    let placeholderProtocol = """
protocol MyRouterProtocol: AnyObject {
    var someProperty: String { get }

    func openURL(url: URL)
    func openPDF(_ url: String)
    func dismissBottomSheet(completion: @escaping () -> Void)
    func openBottomSheet(
        model: BottomSheetTableViewModel,
        onSelected: ((IndexPath) -> Void)?,
        onClose: (() -> Void)?
    )
}
"""

    var body: some View {
        HStack(spacing: 16) {
            // Left Panel - Input
            VStack(spacing: 12) {
                Text("Protocol Input")
                    .font(.system(.title3, design: .default).weight(.semibold))

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.protocolInput)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .onChange(of: viewModel.protocolInput) { _ in
                            viewModel.generateMock()
                        }
                        .focused($focusedField, equals: .protocol)

                    if viewModel.protocolInput.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(placeholderProtocol)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(8)
                        .allowsHitTesting(false)
                    }
                }
                .border(Color.gray.opacity(0.3))
                .cornerRadius(4)

                // Settings
                VStack(spacing: 10) {
                    HStack {
                        Text("Module Name:")
                            .font(.system(size: 12, weight: .regular))
                            .frame(width: 100, alignment: .leading)
                        TextField("Module", text: $viewModel.moduleName)
                            .font(.system(size: 12, weight: .regular))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.moduleName) { newValue in
                                viewModel.saveSettings()
                                viewModel.generateMock()
                            }
                            .focused($focusedField, equals: .moduleName)
                    }

                    HStack {
                        Text("Author Name:")
                            .font(.system(size: 12, weight: .regular))
                            .frame(width: 100, alignment: .leading)
                        TextField("Author", text: $viewModel.authorName)
                            .font(.system(size: 12, weight: .regular))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.authorName) { newValue in
                                viewModel.saveSettings()
                                viewModel.generateMock()
                            }
                            .focused($focusedField, equals: .authorName)
                    }

                    HStack {
                        Text("App Name:")
                            .font(.system(size: 12, weight: .regular))
                            .frame(width: 100, alignment: .leading)
                        TextField("App", text: $viewModel.appName)
                            .font(.system(size: 12, weight: .regular))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.appName) { newValue in
                                viewModel.saveSettings()
                                viewModel.generateMock()
                            }
                            .focused($focusedField, equals: .appName)
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // Right Panel - Output
            VStack(spacing: 12) {
                Text("Generated Mock")
                    .font(.system(.title3, design: .default).weight(.semibold))

                if viewModel.generatedMock.isEmpty {
                    Text("Generated mock will appear here...")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(8)
                        .opacity(0.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(.controlBackgroundColor))
                        .border(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                } else {
                    TextViewRepresentable(text: viewModel.generatedMock)
                        .border(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }

                // Copy Button
                Button(action: {
                    copyToClipboard()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy to Clipboard")
                        Text("⌘C")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.generatedMock.isEmpty)
                .keyboardShortcut("c", modifiers: .command)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding()
        .onAppear {
            viewModel.loadSettings()
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(viewModel.generatedMock, forType: .string)
    }
}

#Preview {
    ContentView()
}
