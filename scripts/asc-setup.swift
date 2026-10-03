#!/usr/bin/env swift
// Idempotent App Store Connect setup for one app. Safe to re-run: every step
// checks before it writes.
//
//   1. Register the bundle ID (iOS) if it doesn't exist.
//   2. Find the app record. The App Store Connect API cannot create apps, so
//      if it's missing this prints what to enter in the web form and exits 2.
//   3. Create an internal TestFlight group with access to all builds, so
//      every Xcode Cloud upload reaches internal testers with no per-build step.
//   4. Add testers to that group (must already be users on the team).
//
// Usage:
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=~/path/AuthKey_XXXX.p8 \
//     swift scripts/asc-setup.swift --bundle-id com.example.app --name "Example" \
//       [--group "Internal Testers"] [--tester a@b.com …] [--dry-run]
//   swift scripts/asc-setup.swift --self-test
//
// The key is read from ASC_KEY_PATH and only used to sign a token — it is
// never printed.

import CryptoKit
import Foundation

// MARK: - Args

var arguments = Array(CommandLine.arguments.dropFirst())
func takeValue(_ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...index + 1)
    return value
}
func takeAll(_ flag: String) -> [String] {
    var values: [String] = []
    while let value = takeValue(flag) { values.append(value) }
    return values
}
func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(code)
}

// MARK: - Token

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func makeToken(keyID: String, issuerID: String, key: P256.Signing.PrivateKey, now: Date = Date()) throws -> String {
    let header = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
    let issuedAt = Int(now.timeIntervalSince1970)
    let payload: [String: Any] = ["iss": issuerID, "iat": issuedAt, "exp": issuedAt + 1200, "aud": "appstoreconnect-v1"]
    let signingInput = base64URL(try JSONSerialization.data(withJSONObject: header, options: .sortedKeys))
        + "." + base64URL(try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys))
    let signature = try key.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

if arguments.contains("--self-test") {
    let key = P256.Signing.PrivateKey()
    let token = try makeToken(keyID: "KEY123", issuerID: "issuer-1", key: key)
    let parts = token.split(separator: ".").map(String.init)
    precondition(parts.count == 3, "token must have 3 parts")
    func decode(_ part: String) -> Data {
        var base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)!
    }
    let header = try JSONSerialization.jsonObject(with: decode(parts[0])) as! [String: String]
    precondition(header["alg"] == "ES256" && header["kid"] == "KEY123", "bad header")
    let payload = try JSONSerialization.jsonObject(with: decode(parts[1])) as! [String: Any]
    precondition(payload["aud"] as? String == "appstoreconnect-v1" && payload["iss"] as? String == "issuer-1", "bad payload")
    let signature = try P256.Signing.ECDSASignature(rawRepresentation: decode(parts[2]))
    precondition(key.publicKey.isValidSignature(signature, for: Data((parts[0] + "." + parts[1]).utf8)), "bad signature")
    print("self-test passed")
    exit(0)
}

// MARK: - Config

let dryRun = arguments.contains("--dry-run")
guard let bundleID = takeValue("--bundle-id"), let appName = takeValue("--name") else {
    fail("usage: --bundle-id <id> --name <app name> [--group <name>] [--tester <email> …] [--dry-run]")
}
let groupName = takeValue("--group") ?? "Internal Testers"
let testers = takeAll("--tester")

let environment = ProcessInfo.processInfo.environment
guard let keyID = environment["ASC_KEY_ID"], let issuerID = environment["ASC_ISSUER_ID"],
      let keyPath = environment["ASC_KEY_PATH"] else {
    fail("set ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (path to the .p8 file)")
}
let privateKey: P256.Signing.PrivateKey
do {
    let pem = try String(contentsOfFile: (keyPath as NSString).expandingTildeInPath, encoding: .utf8)
    privateKey = try P256.Signing.PrivateKey(pemRepresentation: pem)
} catch {
    fail("could not read a P-256 key from ASC_KEY_PATH")
}
let token = try makeToken(keyID: keyID, issuerID: issuerID, key: privateKey)

// MARK: - API

typealias JSON = [String: Any]

func api(_ method: String, _ path: String, query: [String: String] = [:], body: JSON? = nil) async throws -> JSON {
    var components = URLComponents(string: "https://api.appstoreconnect.apple.com" + path)!
    if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
    var request = URLRequest(url: components.url!)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as! HTTPURLResponse).statusCode
    let json = (try? JSONSerialization.jsonObject(with: data)) as? JSON ?? [:]
    guard (200..<300).contains(status) else {
        let details = (json["errors"] as? [JSON])?.compactMap { $0["detail"] as? String }.joined(separator: "; ")
        throw NSError(domain: "ASC", code: status, userInfo: [NSLocalizedDescriptionKey: "\(method) \(path) → \(status): \(details ?? "no details")"])
    }
    return json
}

func items(_ json: JSON) -> [JSON] { json["data"] as? [JSON] ?? [] }
func attribute(_ item: JSON, _ key: String) -> Any? { (item["attributes"] as? JSON)?[key] }

// MARK: - Steps

do {
    // 1. Bundle ID
    let bundleIDs = items(try await api("GET", "/v1/bundleIds", query: ["filter[identifier]": bundleID]))
    if bundleIDs.contains(where: { attribute($0, "identifier") as? String == bundleID }) {
        print("✓ bundle ID \(bundleID) exists")
    } else if dryRun {
        print("→ would register bundle ID \(bundleID)")
    } else {
        _ = try await api("POST", "/v1/bundleIds", body: ["data": [
            "type": "bundleIds",
            "attributes": ["identifier": bundleID, "name": appName, "platform": "IOS"],
        ]])
        print("✓ registered bundle ID \(bundleID)")
    }

    // 2. App record (read-only — the API cannot create apps)
    guard let app = items(try await api("GET", "/v1/apps", query: ["filter[bundleId]": bundleID]))
        .first(where: { attribute($0, "bundleId") as? String == bundleID }),
          let appID = app["id"] as? String else {
        print("""
        ✗ no App Store Connect app for \(bundleID) — the API can't create one.
          Create it at https://appstoreconnect.apple.com/apps → + → New App:
            Platform: iOS · Name: \(appName) · Bundle ID: \(bundleID) · SKU: \(bundleID)
          Then re-run this script.
        """)
        exit(2)
    }
    print("✓ app record exists (\(appID))")

    // 3. Internal group with access to all builds
    let groups = items(try await api("GET", "/v1/apps/\(appID)/betaGroups", query: ["limit": "200"]))
    var groupID = groups.first(where: { attribute($0, "name") as? String == groupName })?["id"] as? String
    if let groupID {
        print("✓ TestFlight group \"\(groupName)\" exists (\(groupID))")
    } else if dryRun {
        print("→ would create internal TestFlight group \"\(groupName)\" with access to all builds")
    } else {
        let created = try await api("POST", "/v1/betaGroups", body: ["data": [
            "type": "betaGroups",
            "attributes": ["name": groupName, "isInternalGroup": true, "hasAccessToAllBuilds": true],
            "relationships": ["app": ["data": ["type": "apps", "id": appID]]],
        ]])
        groupID = (created["data"] as? JSON)?["id"] as? String
        print("✓ created internal TestFlight group \"\(groupName)\"")
    }

    // 4. Testers
    for email in testers {
        if let groupID, !items(try await api("GET", "/v1/betaTesters",
                                             query: ["filter[email]": email, "filter[betaGroups]": groupID])).isEmpty {
            print("✓ tester \(email) already in group")
            continue
        }
        if dryRun || groupID == nil {
            print("→ would add tester \(email)")
            continue
        }
        do {
            _ = try await api("POST", "/v1/betaTesters", body: ["data": [
                "type": "betaTesters",
                "attributes": ["email": email],
                "relationships": ["betaGroups": ["data": [["type": "betaGroups", "id": groupID!]]]],
            ]])
            print("✓ added tester \(email)")
        } catch {
            print("✗ tester \(email): \(error.localizedDescription) (internal testers must already be users on the team)")
        }
    }
} catch {
    fail(error.localizedDescription)
}
