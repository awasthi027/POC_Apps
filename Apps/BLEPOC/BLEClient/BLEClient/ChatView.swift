import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isIncoming: Bool
}

import BLEDevice

struct ChatView: View {

    @State private var messages: [ChatMessage] = []
    
    @State private var chatText: String = ""
    @ObservedObject var service = CentralClientService()

    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(messages) { message in
                            HStack {
                                if message.isIncoming {
                                    ChatBubble(text: message.text, isIncoming: true)
                                    Spacer()
                                } else {
                                    Spacer()
                                    ChatBubble(text: message.text, isIncoming: false)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: self.messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            scrollViewProxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            Divider()
            chatActionView()
        }
        .onAppear() {
            self.service.onChatCommunication = { receivedText in
                messages.append(ChatMessage(text: receivedText, isIncoming: true))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.service.startScanning()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavTitleWithStatus(title: "Chat", isOnline:  self.service.isBLEConnected)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.service.isBLEConnected.toggle() }) {
                    Image(systemName: self.service.isBLEConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(self.service.isBLEConnected ? .green : .red)
                }
                .help("Toggle Online/Offline (for demo)")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear() {
            self.service.disconnect()
        }
    }
    
    private func sendMessage() {
        guard !chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        messages.append(ChatMessage(text: chatText, isIncoming: false))
        self.service.sendMessage( characteristic: .oneToOneChat,
                                  data: chatText.data)
        chatText = ""
    }
    
    private func clearText() {
        chatText = ""
    }
}

extension ChatView {

    func chatActionView() -> some View {
        HStack {
            TextField("Type a message", text: $chatText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minHeight: 36)
            Button(action: clearText) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 24))
                    .foregroundColor(chatText.isEmpty ? .gray : .blue)
            }
            .disabled(chatText.isEmpty)
        }
        .padding()
    }
}

struct ChatBubble: View {
    let text: String
    let isIncoming: Bool
    
    var body: some View {
        Text(text)
            .padding(12)
            .background(isIncoming ? Color(.systemGray5) : Color.blue)
            .foregroundColor(isIncoming ? .black : .white)
            .cornerRadius(16)
            .frame(maxWidth: 250, alignment: isIncoming ? .leading : .trailing)
            .shadow(radius: 1)
    }
}

struct NavTitleWithStatus: View {
    
    let title: String
    let isOnline: Bool
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text(isOnline ? "Online" : "Offline")
                .font(.subheadline)
                .padding(4)
                .background(isOnline ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .foregroundColor(isOnline ? .green : .red)
                .cornerRadius(6)
        }
    }
}

struct ChatView_Previews: PreviewProvider {

    static var previews: some View {
        ChatView()
    }
}
