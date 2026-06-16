//
//  APIConfig.swift
//  LegitImage
//
//  Single source of truth for the backend proxy the app talks to.
//
//  All third-party API keys (Vertex AI / SynthID, Sightengine) live on
//  the backend — never in the app bundle. Anyone can extract strings
//  from an IPA, so secrets shipped in the binary are not secrets.
//
//  The app posts the image to your backend; the backend forwards to
//  the right vendor and returns a normalized response. See
//  `Backend/cloudflare-worker.js` for a reference implementation and
//  `Backend/README.md` for deploy steps.
//
//  Endpoints the backend must expose:
//    POST {baseURL}/synthid      → { verdict, confidence, explanation }
//    POST {baseURL}/sightengine  → { verdict, confidence, explanation }
//
//  Both accept a multipart body with fields:
//    image   — the image bytes
//    source  — "fileUpload" | "screenshot"
//

import Foundation

enum APIConfig {

    // MARK: - Backend
    //
    // The base URL of *your* Next.js backend (separate repo at
    // /Users/tejus/Developer/build/legitimagebackend). The app posts
    // to `{baseURL}/api/v1/synthid` and `{baseURL}/api/v1/sightengine`;
    // route paths are owned by `BackendProxyDetector`.
    //
    // Local dev tips:
    //   • Simulator + `npm run dev`: use `http://localhost:3000` and add
    //     `NSAppTransportSecurity → NSAllowsLocalNetworking = YES` to
    //     the app's Info.plist so ATS lets plaintext through.
    //   • Real device: easiest is `ngrok http 3000` → use the https URL.
    enum Backend {
        static let baseURL: URL = URL(string: "https://YOUR_BACKEND_URL")!

        /// Bearer token sent in `Authorization`. Must equal `APP_TOKEN`
        /// in the backend's `.env.local`. Will be replaced by an App
        /// Attest-issued session token once that's wired up.
        static let appToken: String = ""

        /// Per-request timeout. SynthID + Sightengine both usually
        /// return within a couple of seconds, but we leave headroom
        /// for cold starts and large screenshots.
        static let requestTimeout: TimeInterval = 30
    }

    // MARK: - Feature flags
    //
    // Turn individual checks off without touching call sites — handy
    // when a backend route is down or a vendor account is past quota.
    enum Features {
        static let c2paEnabled: Bool        = true
        static let synthIDEnabled: Bool     = true
        static let sightengineEnabled: Bool = true
    }

    // MARK: - Validation helpers
    //
    // Detectors call this before making a network request so the UI
    // can surface a clean "not configured" status instead of a 404.
    static var isBackendConfigured: Bool {
        !Backend.baseURL.absoluteString.contains("YOUR_BACKEND_URL")
    }
}
