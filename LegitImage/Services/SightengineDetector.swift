//
//  SightengineDetector.swift
//  LegitImage
//
//  Posts the image to Sightengine's check.json endpoint with the genai
//  + properties models and parses the AI score and age estimate back
//  into a CheckResult.
//
//  Endpoint shape (multipart/form-data):
//    POST https://api.sightengine.com/1.0/check.json
//      media:    <image bytes>
//      models:   genai,properties
//      api_user: <user>
//      api_secret: <secret>
//
//  Response of interest:
//    {
//      "type": { "ai_generated": 0.97 },
//      "faces": [ { "attributes": { "age": { "value": 28 } } } ]
//    }
//

import Foundation

struct SightengineDetector: Detector {
    let kind: CheckKind = .sightengine
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func run(on input: ImageInput) async -> CheckResult {
        guard APIConfig.Features.sightengineEnabled else {
            return .skipped(kind, reason: "Sightengine check is disabled in configuration.")
        }
        guard APIConfig.isSightengineConfigured else {
            return .skipped(kind, reason: "Sightengine is not configured. Add API user + secret to APIConfig.")
        }

        do {
            let response = try await callSightengine(data: input.data, mime: input.mimeType ?? "image/jpeg")
            return interpret(response)
        } catch {
            return .failed(kind, message: error.localizedDescription)
        }
    }

    // MARK: - Network

    private struct SightengineResponse: Decodable {
        struct AIType: Decodable { let ai_generated: Double? }
        struct Face: Decodable {
            struct Attributes: Decodable {
                struct Age: Decodable { let value: Double? }
                let age: Age?
            }
            let attributes: Attributes?
        }
        struct ErrorPayload: Decodable {
            let type: String?
            let code: Int?
            let message: String?
        }

        let status: String?
        let type: AIType?
        let faces: [Face]?
        let error: ErrorPayload?
    }

    private func callSightengine(data: Data, mime: String) async throws -> SightengineResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: APIConfig.Sightengine.endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("models", APIConfig.Sightengine.models)
        appendField("api_user", APIConfig.Sightengine.user)
        appendField("api_secret", APIConfig.Sightengine.secret)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"image\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: responseData, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SightengineError.requestFailed(status: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(SightengineResponse.self, from: responseData)
        if let apiError = decoded.error {
            throw SightengineError.apiError(apiError.message ?? "Unknown Sightengine error.")
        }
        return decoded
    }

    // MARK: - Interpretation

    private func interpret(_ response: SightengineResponse) -> CheckResult {
        guard let aiScore = response.type?.ai_generated else {
            return CheckResult(
                kind: kind,
                status: .completed(verdict: .uncertain),
                explanation: "Sightengine returned no AI-pattern score for this image.",
                confidence: 0.2
            )
        }

        let verdict: CheckVerdict
        switch aiScore {
        case 0.7...1.0: verdict = .aiGenerated
        case 0.0..<0.3: verdict = .real
        default:        verdict = .uncertain
        }

        let percent = Int((aiScore * 100).rounded())
        var phrase = "Visual pattern analysis: \(percent)% likelihood of AI generation."

        if let age = response.faces?.first?.attributes?.age?.value {
            phrase += " Detected face age estimate: ~\(Int(age.rounded())) years."
        }

        return CheckResult(
            kind: kind,
            status: .completed(verdict: verdict),
            explanation: phrase,
            confidence: aiScore < 0.5 ? 1.0 - aiScore : aiScore
        )
    }
}

enum SightengineError: LocalizedError {
    case requestFailed(status: Int, message: String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let status, let message):
            return "Sightengine request failed (\(status)): \(message)"
        case .apiError(let message):
            return message
        }
    }
}
