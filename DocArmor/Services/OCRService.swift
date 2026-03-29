import Vision
import UIKit

enum OCRService {

    struct Suggestions: Sendable {
        var name: String?
        var documentNumber: String?
        var expirationDate: Date?

        nonisolated init(
            name: String? = nil,
            documentNumber: String? = nil,
            expirationDate: Date? = nil
        ) {
            self.name = name
            self.documentNumber = documentNumber
            self.expirationDate = expirationDate
        }
    }

    /// Runs Vision text recognition on `image` and returns extracted field suggestions.
    /// Executes off the calling actor so it does not block the main thread.
    nonisolated static func extractSuggestions(from image: UIImage) async -> Suggestions {
        guard let cgImage = image.cgImage else { return Suggestions() }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: parse(lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Parsing

    private nonisolated static func parse(_ lines: [String]) -> Suggestions {
        var suggestions = Suggestions()
        let letterSpaceSet = CharacterSet.letters.union(.whitespaces)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Name: purely alphabetic (plus spaces), 4–50 characters
            if suggestions.name == nil,
               (4...50).contains(trimmed.count),
               trimmed.unicodeScalars.allSatisfy({ letterSpaceSet.contains($0) }) {
                suggestions.name = trimmed.capitalized
            }

            // Document number: 6–20 uppercase alphanumeric characters
            if suggestions.documentNumber == nil,
               let range = trimmed.range(of: #"[A-Z0-9]{6,20}"#, options: .regularExpression) {
                let candidate = String(trimmed[range])
                if candidate.count >= 6 {
                    suggestions.documentNumber = candidate
                }
            }

            // Expiration date
            if suggestions.expirationDate == nil {
                suggestions.expirationDate = extractDate(from: trimmed)
            }
        }

        return suggestions
    }

    private nonisolated static func extractDate(from text: String) -> Date? {
        let candidates: [(pattern: String, formats: [String])] = [
            (#"\d{1,2}/\d{1,2}/\d{2,4}"#,    ["MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy"]),
            (#"\d{4}-\d{2}-\d{2}"#,           ["yyyy-MM-dd"]),
            (#"\d{1,2}\s+[A-Za-z]{3}\s+\d{2,4}"#, ["dd MMM yyyy", "d MMM yyyy"])
        ]

        for (pattern, formats) in candidates {
            guard let range = text.range(of: pattern, options: .regularExpression) else { continue }
            let match = String(text[range])
            for format in formats {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = formatter.date(from: match), date > Date.now {
                    return date
                }
            }
        }
        return nil
    }
}
