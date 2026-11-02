import CoreGraphics
import Foundation
import Vision

/// A recognized word with per-character boxes in page coordinates.
struct RecognizedWord {
    struct Glyph {
        var character: Character
        var bounds: InkBounds
    }
    var text: String
    var confidence: Double
    var bounds: InkBounds
    var glyphs: [Glyph]
}

/// On-device handwriting recognition. Vision reads the ink; Apple Intelligence
/// (when available) disambiguates between Vision's own candidates. It never
/// invents replacement prose, so names, numbers and intent stay under control.
final class HandwritingRecognition {
    enum Failure: Error { case noText }

    private struct Candidate: Sendable {
        struct Glyph: Sendable {
            var character: Character
            var bounds: InkBounds
        }
        var text: String
        var confidence: Double
        var bounds: InkBounds
        var glyphs: [Glyph]
    }

    func recognize(image: CGImage, crop: CGRect) async throws -> [RecognizedWord] {
        try Task.checkCancellation()
        let candidates = try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.revision = VNRecognizeTextRequestRevision3
            request.usesLanguageCorrection = true
            let preferred = ["de-DE", "en-US"]
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            request.recognitionLanguages = preferred.filter { supported.contains($0) }
            if request.recognitionLanguages.isEmpty {
                request.recognitionLanguages = Array(supported.prefix(2))
            }
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            return (request.results ?? []).map { observation -> [Candidate] in
                observation.topCandidates(3).compactMap { recognized in
                    guard recognized.confidence >= 0.55 else { return nil }
                    var glyphs: [Candidate.Glyph] = []
                    let text = recognized.string
                    for index in text.indices {
                        let next = text.index(after: index)
                        let range = NSRange(index..<next, in: text)
                        if let box = try? recognized.boundingBox(for: range) {
                            glyphs.append(
                                Candidate.Glyph(
                                    character: text[index],
                                    bounds: Self.pageBounds(box.boundingBox, crop: crop)
                                )
                            )
                        }
                    }
                    return Candidate(
                        text: text, confidence: Double(recognized.confidence),
                        bounds: Self.pageBounds(recognized.boundingBox, crop: crop),
                        glyphs: glyphs
                    )
                }
            }
        }.value
        try Task.checkCancellation()
        let groups = candidates.filter { !$0.isEmpty }
        guard !groups.isEmpty else { throw Failure.noText }
        let choices = await AppleIntelligenceAdapter.choose(
            in: groups.map { group in group.map { $0.text } })
        var words: [RecognizedWord] = []
        for (index, group) in groups.enumerated() {
            let choice = choices.indices.contains(index) ? choices[index] : 0
            guard let selected = group.indices.contains(choice) ? group[choice] : group.first else {
                continue
            }
            words.append(
                RecognizedWord(
                    text: selected.text, confidence: selected.confidence,
                    bounds: selected.bounds,
                    glyphs: selected.glyphs.map {
                        RecognizedWord.Glyph(character: $0.character, bounds: $0.bounds)
                    }
                )
            )
        }
        return words.sorted { $0.bounds.minX < $1.bounds.minX }
    }

    /// Vision uses a bottom-left origin; the canvas uses top-left page coordinates.
    private static func pageBounds(_ box: CGRect, crop: CGRect) -> InkBounds {
        InkBounds(
            minX: Double(crop.minX + box.minX * crop.width),
            minY: Double(crop.minY + (1 - box.maxY) * crop.height),
            maxX: Double(crop.minX + box.maxX * crop.width),
            maxY: Double(crop.minY + (1 - box.minY) * crop.height)
        )
    }
}

#if canImport(FoundationModels)
    import FoundationModels

    @available(iOS 26.0, *)
    private enum AppleIntelligenceSession {
        static var isAvailable: Bool {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else { return false }
            return model.supportedLanguages.contains {
                $0.languageCode == .german || $0.languageCode == .english
            }
        }

        static func choose(candidates: [[String]]) async -> [Int] {
            guard isAvailable else { return candidates.map { _ in 0 } }
            let session = LanguageModelSession(
                instructions: """
                    You disambiguate on-device handwriting OCR. For each word you receive \
                    numbered candidate readings. Choose the candidate most likely intended \
                    from the sentence context. Never invent a new reading. Preserve names, \
                    numbers, casing and language. Reply with one zero-based candidate index \
                    per word, separated by commas, and nothing else. If unsure, choose 0.
                    """
            )
            let payload = candidates.enumerated().map { index, texts in
                "Word \(index + 1): "
                    + texts.enumerated().map { "[\($0.offset)] \($0.element)" }
                    .joined(separator: " | ")
            }.joined(separator: "\n")
            do {
                let response = try await session.respond(
                    to: payload,
                    options: GenerationOptions(temperature: 0, maximumResponseTokens: 128)
                )
                let parts = response.content.split(separator: ",", omittingEmptySubsequences: false)
                guard parts.count == candidates.count else { return candidates.map { _ in 0 } }
                var result: [Int] = []
                for (index, part) in parts.enumerated() {
                    guard let value = Int(part.trimmingCharacters(in: .whitespacesAndNewlines)),
                        candidates[index].indices.contains(value)
                    else { return candidates.map { _ in 0 } }
                    result.append(value)
                }
                return result
            } catch {
                return candidates.map { _ in 0 }
            }
        }
    }
#endif

/// Availability-safe facade: iOS 17 and unsupported devices keep the Vision path.
private enum AppleIntelligenceAdapter {
    static func choose(in candidates: [[String]]) async -> [Int] {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                return await AppleIntelligenceSession.choose(candidates: candidates)
            }
        #endif
        return candidates.map { _ in 0 }
    }

    static var statusText: String {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                return AppleIntelligenceSession.isAvailable
                    ? "Apple Intelligence bereit" : "Lokale Erkennung (ohne Apple Intelligence)"
            }
        #endif
        return "Lokale Erkennung (iOS 17+)"
    }
}
