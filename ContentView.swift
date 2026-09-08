import SwiftUI

// MARK: - NSTextView Wrapper для правильного скролла, выделения и Cmd+C
struct TextViewRepresentable: NSViewRepresentable {
    var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)

        let textView = NSTextView()

        textView.string = text
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false

        textView.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        textView.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        textView.insertionPointColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)

        textView.textContainerInset = NSSize(width: 8, height: 8)

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.autoresizingMask = [.width]

        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        guard textView.string != text else {
            return
        }

        let selectedRange = textView.selectedRange()
        let visibleRect = scrollView.contentView.bounds

        textView.string = text

        if selectedRange.location <= textView.string.count {
            textView.setSelectedRange(selectedRange)
        }

        scrollView.contentView.scroll(to: visibleRect.origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
