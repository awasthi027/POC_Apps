
//  QAEngine.swift
//  TextClassifier
//
//  Loads FAQAnswerClassifier — predicts answer_key from question,
//  then maps to full answer using qa_answers.csv.
//

import Foundation
import CoreML
import NaturalLanguage

final class QAEngine {

    private let nlModel: NLModel
    private let answerMap: [String: String]
    private let confidenceThreshold: Double = 0.15

    init?() {
        // Load ML model (trained on qa_training.csv with label = answer_key)
        do {
            let wrapper = try FAQAnswerClassifier(configuration: MLModelConfiguration())
            self.nlModel = try NLModel(mlModel: wrapper.model)
        } catch {
            print("❌ Failed to load FAQAnswerClassifier:", error)
            return nil
        }

        // Load answer mapping from bundled qa_answers.csv (answer_key,answer)
        guard let mapURL = Bundle.main.url(forResource: "qa_answers", withExtension: "csv"),
              let content = try? String(contentsOf: mapURL, encoding: .utf8) else {
            print("❌ Failed to load qa_answers.csv from bundle")
            return nil
        }

        var map: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        for line in lines.dropFirst() where !line.isEmpty {
            if let commaRange = line.range(of: ",") {
                let key = String(line[line.startIndex..<commaRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                var value = String(line[commaRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                        .replacingOccurrences(of: "\"\"", with: "\"")
                }
                map[key] = value
            }
        }
        self.answerMap = map
        print("📚 Loaded \(map.count) answers from qa_answers.csv")
    }

    /// Predicts answer_key, then looks up full answer from the map.
    func answer(for question: String) -> (answer: String, confidence: Double) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("Please type a question.", 0)
        }

        let hypotheses = nlModel.predictedLabelHypotheses(for: trimmed, maximumCount: 1)
        guard let top = hypotheses.max(by: { $0.value < $1.value }) else {
            return ("Sorry, I didn't understand. Please rephrase your question.", 0)
        }

        let key = top.key
        let conf = top.value
        print("🔎 Q: \"\(trimmed)\" -> key: \(key), conf: \(conf)")

        if conf < confidenceThreshold {
            return ("Sorry, I didn't understand. Please rephrase your question.", conf)
        }

        let fullAnswer = answerMap[key] ?? "Answer not found for key: \(key)"
        return (fullAnswer, conf)
    }
}


