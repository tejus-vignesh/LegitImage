//
//  BackendProxyDetector.swift
//  LegitImage
//
//  Detector that proxies a check through the user-owned backend
//  (see `APIConfig.Backend.baseURL`). Both the SynthID and Sightengine
//  passes use this one type, parameterized by `kind` — the backend
//  exposes one route per check and returns a normalized response so
//  the app never knows which vendor was called.
//
//  Wire format the backend speaks:
//    POST {baseURL}/{route}
//      Authorization: Bearer <APP_TOKEN>   (optional)
//      multipart/form-data:
//        image  — bytes
//        source — "fileUpload" | "screenshot"
//    Response (200):
//      { "verdict": "ai_generated"|"real"|"uncertain",
//        "confidence": 0..1 (optional),
//        "explanation": "…plain-English sentence…" }
//

import Foundation

struct BackendProxyDetector: Detector {
    let kind: CheckKind
    let session: URLSession

    init(kind: CheckKind, session: URLSession = .shared) {
        precondition(kind != .c2pa, "C2PA runs locally — don't proxy it.")
        self.kind = kind
        self.session = session
    }

    func run(on input: ImageInput) async -> CheckResult {
        guard isFeatureEnabled else {
            return .skipped(kind, reason: "\(kind.title) is disabled in configuration.")
        }
        guard APIConfig.isBackendConfigured else {
            return .skipped(kind, reason: "Backend URL is not configured. Set it in APIConfig.")
        }

        do {
            let response = try await callBackend(input: input)
            return interpret(response, source: input.source)
        } catch {
            return .failed(kind, message: error.localizedDescription)
        }
    }

    // MARK: - Feature flag lookup

    private var isFeatureEnabled: Bool {
        switch kind {
        case .synthID:     return APIConfig.Features.synthIDEnabled
        case .sightengine: return APIConfig.Features.sightengineEnabled
        case .c2pa:        return false
        }
    }

    private var route: String {
        switch kind {
        case .synthID:     return "api/v1/synthid"
        case .sightengine: return "api/v1/sightengine"
        case .c2pa:        return ""
        }
    }

    // MARK: - Network

    private struct ProxyResponse: Decodable {
        let verdict: String
        let confidence: Double?
        let explanation: String?
    }

    private func callBackend(input: ImageInput) async throws -> ProxyResponse {
        let url = APIConfig.Backend.baseURL.appendingPathComponent(route)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfig.Backend.requestTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(boundary: boundary, input: input)

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BackendProxyError.requestFailed(status: http.statusCode, message: message)
        }
        return try JSONDecoder().decode(ProxyResponse.self, from: data)
    }

    private func buildMultipartBody(boundary: String, input: ImageInput) -> Data {
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("source", input.source == .screenshot ? "screenshot" : "fileUpload")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(input.mimeType ?? "image/jpeg")\r\n\r\n".data(using: .utf8)!)
        body.append(input.data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    // MARK: - Interpretation

    private func interpret(_ response: ProxyResponse, source: ImageSource) -> CheckResult {
        let verdict: CheckVerdict = {
            switch response.verdict.lowercased() {
            case "ai_generated", "ai", "aigenerated": return .aiGenerated
            case "real":                              return .real
            default:                                  return .uncertain
            }
        }()

        let explanation = response.explanation ?? defaultExplanation(for: verdict)

        // SynthID is unreliable on screenshots regardless of what the
        // backend returned — the watermark may not survive the capture.
        if kind == .synthID && !source.synthIDIsReliable {
            return CheckResult(
                kind: kind,
                status: .unreliable(verdict: verdict, reason: "Screenshots can damage watermarks; treat as low signal."),
                explanation: explanation,
                confidence: (response.confidence ?? 0.5) * 0.3
            )
        }

        return CheckResult(
            kind: kind,
            status: .completed(verdict: verdict),
            explanation: explanation,
            confidence: response.confidence
        )
    }

    private func defaultExplanation(for verdict: CheckVerdict) -> String {
        switch verdict {
        case .aiGenerated: return "\(kind.title) flagged this image as AI-generated."
        case .real:        return "\(kind.title) found no AI signal."
        case .uncertain:   return "\(kind.title) was inconclusive."
        }
    }
}

enum BackendProxyError: LocalizedError {
    case requestFailed(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let status, let message):
            return "Backend request failed (\(status)): \(message)"
        }
    }
}
