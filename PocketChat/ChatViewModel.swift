//
//  ChatViewModel.swift
//  PocketChat
//
//  Created by Divya on 11/10/26.
//


import Foundation
import FoundationModels
import Observation

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isResponding = false
    var errorText: String?

    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession

    private static let instructions = """
    You are Pocket, a friendly, concise assistant. \
    Keep answers under 120 words unless asked for more. \
    If you are unsure, say so instead of guessing.
    """

    init() {
        session = LanguageModelSession(instructions: Self.instructions)
        session.prewarm() // loads model into memory for faster first reply
    }

    var availabilityMessage: String? {
        switch model.availability {
        case .available: return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to chat."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again soon."
        case .unavailable:
            return "The on-device model is unavailable."
        }
    }

    func send(_ prompt: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }

        errorText = nil
        isResponding = true
        messages.append(.init(role: .user, text: trimmed))
        messages.append(.init(role: .assistant, text: ""))
        let index = messages.count - 1

        do {
            // Streaming: each snapshot holds the text generated so far
            let stream = session.streamResponse(to: trimmed)
            for try await snapshot in stream {
                messages[index].text = snapshot.content
            }
        } catch let error as LanguageModelError {
            handle(error, retryPrompt: trimmed, at: index)
        } catch {
            errorText = error.localizedDescription
            messages.removeLast()
        }
        isResponding = false
    }

    private func handle(_ error: LanguageModelError,
                        retryPrompt: String, at index: Int) {
        switch error {
        case .contextSizeExceeded:
            // Conversation too long: start a fresh session
            session = LanguageModelSession(instructions: Self.instructions)
            errorText = "Conversation got long, so I started fresh. Please resend."
        case .guardrailViolation:
            errorText = "I can't help with that request."
        default:
            errorText = "Something went wrong. Please try again."
        }
        messages.removeLast() // drop the empty assistant bubble
    }

    func reset() {
        messages.removeAll()
        session = LanguageModelSession(instructions: Self.instructions)
    }
}
