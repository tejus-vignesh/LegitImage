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
    // The base URL of *your* backend proxy. The Backend/ folder ships a
    // Cloudflare Worker you can deploy with `wrangler deploy` in under
    // a minute; swap in any URL once it's live.
    enum Backend {
        static let baseURL: URL = URL(string: "https://YOUR_BACKEND.workers.dev")!

        /// Optional app token sent as `Authorization: Bearer <token>`.
        /// Use it for basic abuse protection / rate limiting on the
        /// backend. Leave blank to disable. Even if intercepted, it
        /// only grants access to your backend — not to vendor keys.
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
        !Backend.baseURL.absoluteString.contains("YOUR_BACKEND")
    }
}
