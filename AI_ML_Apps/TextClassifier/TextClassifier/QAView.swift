//
//  QAView.swift
//  TextClassifier
//
//  Simple SwiftUI screen: user types a question, model predicts intent,
//  and we show the mapped answer.
//

import SwiftUI

struct QAView: View {

    @State private var question: String = ""
    @State private var answer: String = "Try: \"How to create OG\" or \"Create a OG\""
    @State private var confidence: Double = 0
    @State private var hasAnswered: Bool = false

    private let engine = QAEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your question")
                            .font(.headline)
                        TextField("e.g. How can I create OG?", text: $question, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...3)
                            .submitLabel(.send)
                            .onSubmit(ask)
                    }

                    Button(action: ask) {
                        Label("Ask", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty)

                    // Answer card
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Answer", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundColor(.blue)

                        Text(answer)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        if hasAnswered {
                            Divider()
                            HStack {
                                Spacer()
                                Text("Confidence: \(String(format: "%.0f%%", confidence * 100))")
                                    .foregroundColor(.green)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

//                    // Sample prompts
//                    VStack(alignment: .leading, spacing: 8) {
//                        Text("Try these:")
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)
//                        FlowLayout(spacing: 8) {
//                            ForEach(samplePrompts, id: \.self) { prompt in
//                                Button(prompt) {
//                                    question = prompt
//                                    ask()
//                                }
//                                .font(.footnote)
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 6)
//                                .background(Color.blue.opacity(0.1))
//                                .foregroundColor(.blue)
//                                .clipShape(Capsule())
//                            }
//                        }
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)

                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("FAQ Bot")
        }
    }

    private let samplePrompts = [
        "How to do token authentication",
        "How to test third party apps",
        "How many types of enrolment UEM support",
        "How to configure tunnel",
        "How to create MDM or Device Profile",
        "How to do Integrated Authentication",
        "Environment information",
        "How to collect app logs from UEM",
        "How to revoke SDK HMAC token",
        "Boxer configuration"
    ]

    private func ask() {
        guard let engine else {
            answer = "Model not loaded. Add FAQIntentClassifier.mlmodel to the app target."
            return
        }
        let result = engine.answer(for: question)
        answer = result.answer
        confidence = result.confidence
        hasAnswered = true
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

#Preview {
    QAView()
}
