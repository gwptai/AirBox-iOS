import SwiftUI

// MARK: - ViewModel

@MainActor
final class AIViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false

    private let service: AIService = LocalAIService()
    private let storageKey = "airbox.ai.history"

    init() {
        loadHistory()
    }

    // MARK: - Send

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isLoading = true
        saveHistory()

        do {
            let reply = try await service.send(messages: messages)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            messages.append(
                ChatMessage(
                    role: .assistant,
                    content: "Ошибка: \(error.localizedDescription)"
                )
            )
        }

        isLoading = false
        saveHistory()
    }

    func clearHistory() {
        messages = []
        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadHistory() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([ChatMessage].self, from: data)
        else { return }
        messages = saved
    }
}

// MARK: - View

struct AIView: View {

    @StateObject private var viewModel = AIViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                Divider()
                    .background(Color.white.opacity(0.08))
                inputBar
            }
        }
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.clearHistory()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        typingIndicatorView
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if viewModel.isLoading {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "cpu")
                .font(.system(size: 52))
                .foregroundColor(.gray.opacity(0.6))

            Text("AirBox AI")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.gray)

            Text("Локальный AI без интернета.\nПока работает в режиме заглушки.")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.bottom, 20)
    }

    // MARK: - Typing indicator

    private var typingIndicatorView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer()
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Напиши сообщение...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .foregroundColor(.white)
                .tint(.white)

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(sendButtonColor)
            }
            .disabled(isSendDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    private var isSendDisabled: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || viewModel.isLoading
    }

    private var sendButtonColor: Color {
        isSendDisabled ? .gray.opacity(0.4) : .white
    }
}

// MARK: - Bubble

struct MessageBubbleView: View {

    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser {
                Spacer(minLength: 60)
            }

            Text(message.content)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleBackground: Color {
        isUser
            ? Color.white.opacity(0.15)
            : Color.white.opacity(0.07)
    }
}