import Foundation
import CreateML

// Trains a Create ML text classifier using qa_training.csv (text,answer_key).
// The model predicts answer_key. At runtime, QAEngine maps answer_key -> full answer
// using qa_answers.csv.
//
// Usage:
//   swift train_answer_model.swift qa_training.csv FAQAnswerClassifier.mlmodel

guard CommandLine.arguments.count >= 3 else {
    print("Usage: swift train_answer_model.swift <trainingCSV> <outputMlmodel>")
    exit(1)
}

let csvPath = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]

let dataURL = URL(fileURLWithPath: csvPath)
let outputURL = URL(fileURLWithPath: outPath)

do {
    let data = try MLDataTable(contentsOf: dataURL)
    print("Loaded rows:", data.rows.count)

    let classifier = try MLTextClassifier(
        trainingData: data,
        textColumn: "text",
        labelColumn: "answer_key"
    )

    let trainAcc = 1.0 - classifier.trainingMetrics.classificationError
    print(String(format: "Training accuracy: %.2f%%", trainAcc * 100))

    let metadata = MLModelMetadata(
        author: "Ashish Awasthi",
        shortDescription: "FAQ classifier - predicts answer_key from question text.",
        version: "1.0"
    )
    try classifier.write(to: outputURL, metadata: metadata)
    print("✅ Saved model to:", outputURL.path)
} catch {
    print("❌ Training failed:", error)
    exit(1)
}
