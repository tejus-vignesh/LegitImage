//
//  APIConfig.swift
//  LegitImage
//
//  Single source of truth for every API key, endpoint, and toggle used by
//  the detection services. Fill in the placeholder values below before
//  shipping. No keys are permitted anywhere else in the project.
//

import Foundation

enum APIConfig {

    // MARK: - Google Cloud Vertex AI (SynthID)
    //
    // SynthID detection runs through Vertex AI. You need:
    //   1. A Google Cloud project with Vertex AI enabled.
    //   2. An OAuth 2.0 access token (short-lived) OR a service account
    //      access token minted on a backend. Do NOT ship a service account
    //      JSON in the app bundle for production — proxy through a backend.
    //   3. The model location (region) you provisioned.
    //
    // Docs: https://cloud.google.com/vertex-ai/generative-ai/docs/image/synthid
    enum SynthID {
        static let projectID: String = "YOUR_GCP_PROJECT_ID"
        static let location: String  = "us-central1"
        static let accessToken: String = "YOUR_GCP_ACCESS_TOKEN"
        static let modelID: String   = "image-verification"

        static var endpoint: URL {
            URL(string: "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelID):predict")!
        }
    }

    // MARK: - Sightengine (AI pattern + age estimation)
    //
    // Sign up at https://sightengine.com and grab a User ID + Secret.
    // The `models` query parameter controls which checks run; we request
    // the GenAI detector plus age estimation.
    enum Sightengine {
        static let user: String   = "YOUR_SIGHTENGINE_USER"
        static let secret: String = "YOUR_SIGHTENGINE_SECRET"

        static let endpoint: URL = URL(string: "https://api.sightengine.com/1.0/check.json")!
        static let models: String = "genai,properties"
    }

    // MARK: - Feature flags
    //
    // Lets us turn individual checks off without touching call sites — handy
    // when an API is over quota or a key has not been provisioned yet.
    enum Features {
        static let c2paEnabled: Bool        = true
        static let synthIDEnabled: Bool     = true
        static let sightengineEnabled: Bool = true
    }

    // MARK: - Validation helpers
    //
    // Detectors call these before making network requests so we can surface
    // a clean "not configured" status instead of a 401.
    static var isSynthIDConfigured: Bool {
        !SynthID.projectID.hasPrefix("YOUR_") && !SynthID.accessToken.hasPrefix("YOUR_")
    }

    static var isSightengineConfigured: Bool {
        !Sightengine.user.hasPrefix("YOUR_") && !Sightengine.secret.hasPrefix("YOUR_")
    }
}
