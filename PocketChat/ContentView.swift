//
//  ContentView.swift
//  PocketChat
//
//  Created by Divya on 11/10/26.
//

import SwiftUI
import FoundationModels

struct ContentView: View {
    @State private var vm = ChatViewModel()
    @State private var input = ""

    var body: some View {
        NavigationStack {
            Group {
                if let msg = vm.availabilityMessage {
                    ContentUnavailableView("Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(msg))
                } else {
                    chat
                }
            }
            .navigationTitle("PocketChat")
            .toolbar {
                Button("New Chat", systemImage: "square.and.pencil") { vm.reset() }
                    .disabled(vm.messages.isEmpty)
            }
        }
    }

    private var chat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.messages) { m in
                            Bubble(message: m).id(m.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.last?.text) {
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            if let e = vm.errorText {
                Text(e).font(.footnote).foregroundStyle(.red).padding(.horizontal)
            }
            HStack {
                TextField("Message", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button {
                    let text = input
                    input = ""
                    Task { await vm.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(input.isEmpty || vm.isResponding)
            }
            .padding()
        }
    }
}

struct Bubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text.isEmpty ? "…" : message.text)
                .padding(12)
                .background(message.role == .user ? Color.accentColor : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(message.role == .user ? .white : .primary)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

//#Preview {
//    ContentView()
//}

#Preview{
    Button("Test model") {
        Task {
            do {
                let session = LanguageModelSession()
                let r = try await session.respond(to: "Say hello in five words.")
                print("OK:", r.content)
            } catch {
                print("FAILED:", String(reflecting: error))
            }
        }
    }
}
