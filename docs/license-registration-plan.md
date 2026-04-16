# GenQuery License Registration — Research & Implementation Plan

**Date**: 2026-04-15
**Status**: Research / Pre-proposal

---

## Table of Contents

1. [How Software Licensing Works (Primer)](#1-how-software-licensing-works-primer)
2. [Distribution Channels & Their Licensing Models](#2-distribution-channels--their-licensing-models)
3. [Open-Source & Indie-Friendly Licensing Solutions](#3-open-source--indie-friendly-licensing-solutions)
4. [Cost Comparison](#4-cost-comparison)
5. [Recommended Architecture for GenQuery](#5-recommended-architecture-for-genquery)
6. [Implementation Plan](#6-implementation-plan)
7. [Appendix: Key Concepts Glossary](#7-appendix-key-concepts-glossary)

---

## 1. How Software Licensing Works (Primer)

When a user "buys" desktop software, two things must happen: **payment** and **license issuance**. These are often handled by separate systems.

### The License Lifecycle

```
Purchase → Key/Receipt Issued → Activation (bind to machine) → Validation (on each launch) → Renewal/Expiration
```

1. **Purchase**: User pays through a store (Apple/Microsoft) or your website (via Stripe, Paddle, etc.)
2. **License issuance**: A license key, signed token, or store receipt is generated
3. **Activation**: The app "activates" the license, binding it to the user's machine (via a hardware fingerprint). This prevents one key from being shared across unlimited machines.
4. **Validation**: On each launch, the app checks that the license is valid — either by calling a server ("phone home") or by verifying a cryptographic signature locally (offline)
5. **Renewal/Expiration**: For subscriptions, the license must be periodically refreshed

### Online vs. Offline Validation

| Approach | How it works | Pros | Cons |
|----------|-------------|------|------|
| **Online (phone-home)** | App calls your server on every launch | Real-time control; can revoke instantly | Requires internet; users dislike it; server downtime = app broken |
| **Offline (signed license file)** | Server issues a cryptographically signed file at activation; app verifies the signature locally using a bundled public key | Works without internet; no server dependency after activation | Can't revoke instantly; harder to implement |
| **Hybrid (recommended)** | Activate online once; validate offline day-to-day; periodic heartbeat (e.g., every 14-30 days) to refresh | Best of both worlds | Slightly more complex |

The **hybrid approach** is the modern standard. Sublime Text, JetBrains, and most serious indie apps use some variant of this.

### Machine Fingerprinting

To prevent a single license from being used on unlimited machines, the app generates a "fingerprint" of the hardware:

- **macOS**: Hardware UUID from `IOPlatformExpertDevice` (via `ioreg` or `system_profiler`)
- **Windows**: Combination of motherboard serial, CPU ID, disk serial, Windows product ID
- **Best practice**: Hash multiple hardware identifiers together. Use a threshold approach (2-of-3 components must match) so that replacing a single component (e.g., a hard drive) doesn't invalidate the license.

The fingerprint is registered with the licensing server at activation time. The license policy defines how many machines are allowed (e.g., "3 machines per license").

---

## 2. Distribution Channels & Their Licensing Models

GenQuery can reach users through three channels, each with its own licensing mechanism.

### Channel 1: Apple App Store (macOS)

**How it works**: When a user buys your app from the Mac App Store, macOS places a cryptographically signed **receipt** inside the app bundle at `Contents/_MASReceipt/receipt`. Your app validates this receipt to confirm the purchase.

**Modern approach (StoreKit 2)**:
- `AppTransaction.shared` provides a JWS (JSON Web Signature) signed by Apple
- `Transaction.currentEntitlements` returns all active purchases
- Each transaction is a signed JSON token that can be verified locally (using Apple's public certificate) or server-side
- For subscriptions: **App Store Server Notifications V2** sends real-time webhooks to your server for renewals, cancellations, refunds

**Business terms**:
- Apple takes **30%** (or **15%** under the Small Business Program for developers earning < $1M/year — GenQuery qualifies)
- Handles all global tax compliance
- Apps **must** use App Sandbox (limits file system access, network, etc.)
- Provides automatic updates, Family Sharing, and discoverability

**Key constraint for GenQuery**: App Sandbox may limit access to `.rmtree` files in arbitrary locations. Users would need to grant explicit folder access. This is manageable but adds friction.

### Channel 2: Microsoft Store (Windows)

**How it works**: Uses the `Windows.Services.Store` API namespace:
- `StoreContext.GetAppLicenseAsync()` returns license status (`IsActive`, `IsTrial`, `ExpirationDate`)
- License is tied to the user's Microsoft Account, not the device
- Server-side validation available via Microsoft Store Collection API (REST)

**Business terms**:
- Microsoft takes **15%** for apps (reduced from 30% in 2021 — notably better than Apple)
- Handles tax compliance
- Requires MSIX packaging (Win32 apps supported via MSIX bridge since 2022)
- No sandboxing requirement for Win32 bridge apps

### Channel 3: Direct Sales (Your Website)

**How it works**: You sell the app directly from your website using a payment processor. You handle license key generation and validation yourself (or use a service like Keygen).

**Business terms**:
- No store commission — only payment processing fees (~3-5%)
- You handle (or outsource) global tax compliance
- No sandboxing restrictions on macOS (just notarization required)
- You provide your own update mechanism (GenQuery already uses Sparkle for macOS auto-update)
- Full control over trials, pricing, and licensing terms

### The Dual Distribution Model

Most successful indie apps sell through **both** stores and directly. The app detects which channel it came from and validates accordingly:

```
App Launch
  ├── Detect App Store receipt exists? → Validate via StoreKit 2
  ├── Detect MSIX Store package? → Validate via Windows.Services.Store
  └── Neither? → Check for direct-sale license key → Validate via your server or offline signature
```

**Real-world examples**:
- **BBEdit**: On App Store AND direct sale for years (dual unlock paths in same binary)
- **Panic (Transmit, Nova)**: App Store + direct via Paddle
- **1Password**: App Store subscription + direct website subscription, unified by their own account system
- **Sketch**: Left App Store entirely (sandboxing too limiting); direct-only via own subscription

---

## 3. Open-Source & Indie-Friendly Licensing Solutions

### Tier 1: Full Licensing Platforms

#### Keygen CE (Self-Hosted) — Recommended for Maximum Control

| | |
|---|---|
| **What** | Full-featured licensing API server |
| **License** | Elastic License 2.0 (source-available; can self-host, cannot resell as SaaS) |
| **Self-hostable** | Yes — Ruby on Rails + PostgreSQL, Docker images provided |
| **GitHub** | [keygen-sh/keygen-api](https://github.com/keygen-sh/keygen-api) (~1.5k stars) |
| **Cost** | Free (self-hosted). Hosted cloud: free tier (100 licenses), then $49+/month |

**Key features**:
- REST API for license creation, validation, activation, suspension, renewal
- Machine fingerprinting with configurable activation limits
- License policies (rules: max machines, expiration, trial, feature flags)
- Entitlements system (feature gating per license tier)
- **Offline validation via signed license files** (cryptographic tokens validated without server)
- Webhook integration with Stripe, Paddle, and Apple receipts
- Release/artifact distribution (signed updates)

**Why it's the best fit for a developer like you**: You get a battle-tested API without paying SaaS fees, and you maintain full control. Running it on a $5-10/month VPS is trivial. The offline license file feature means GenQuery users aren't dependent on your server being up.

#### Keygen Cloud (Hosted SaaS)

Same as above but hosted by Keygen. Free tier allows 100 licenses. Good for getting started without running your own server, with a clear migration path to self-hosted later.

### Tier 2: Merchant of Record + Built-in Licensing

These handle **both** payment and licensing, eliminating the need for a separate licensing server:

#### Paddle

| | |
|---|---|
| **What** | Merchant of Record with licensing SDK |
| **Cost** | 5% + $0.50 per transaction (no monthly fee) |
| **Tax handling** | Yes — handles all global VAT/sales tax as MoR |
| **Licensing** | Built-in license key generation, activation API, machine limits |
| **Who uses it** | CleanShot X, Sketch (formerly), many indie Mac apps |

**The indie Mac app gold standard.** Paddle is the most widely used platform in the indie macOS community. They handle checkout UI, payment processing, tax compliance, and license key management in one package.

#### LemonSqueezy (now owned by Stripe)

| | |
|---|---|
| **What** | Modern MoR with built-in licensing |
| **Cost** | 5% + $0.50 per transaction (no monthly fee) |
| **Tax handling** | Yes — full MoR |
| **Licensing** | License key generation, activation limits, validation API |
| **Advantage** | More modern DX than Paddle; backed by Stripe (acquired 2024) |

Growing rapidly in the indie community. Simpler dashboard and API than Paddle. Good choice for new projects.

### Tier 3: Payment Only (No Licensing)

#### Stripe (Direct)

| | |
|---|---|
| **Cost** | 2.9% + $0.30 per transaction |
| **Tax handling** | No — you handle it (tools like TaxJar cost $50-500/month) |
| **Licensing** | None — you build your own |

Cheapest per-transaction cost, but you take on tax compliance and licensing infrastructure. Only worth it at significant volume or if you're using Keygen CE anyway.

### Comparison Matrix

| Solution | Open Source | Self-Host | MoR (taxes) | License Keys | Offline Validation | Monthly Cost |
|----------|:----------:|:---------:|:-----------:|:------------:|:------------------:|:------------:|
| **Keygen CE** | Source-avail. | Yes | No | Yes | Yes | ~$5-10 (VPS) |
| **Keygen Cloud** | — | No | No | Yes | Yes | Free-$49+ |
| **Paddle** | No | No | Yes | Yes | Limited | $0 (% only) |
| **LemonSqueezy** | No | No | Yes | Yes | No | $0 (% only) |
| **Polar** | Apache 2.0 | Yes | Yes | Basic | No | Free (self) |
| **Stripe + DIY** | — | — | No | DIY | DIY | ~$5-10 (VPS) |

---

## 4. Cost Comparison

Scenario: GenQuery at $35, ~100 sales/month ($3,500 monthly revenue).

| Channel | Fee per $35 sale | Monthly (100 sales) | Handles taxes? |
|---------|:----------------:|:-------------------:|:--------------:|
| **Apple App Store** (Small Business 15%) | $5.25 | $525 | Yes |
| **Microsoft Store** (15%) | $5.25 | $525 | Yes |
| **Paddle** (5% + $0.50) | $2.25 | $225 | Yes |
| **LemonSqueezy** (5% + $0.50) | $2.25 | $225 | Yes |
| **Stripe direct** (2.9% + $0.30) | $1.32 | $132 | No |
| **Keygen CE + Stripe** | $1.32 + ~$10 hosting | $142 | No |

**The hidden tax compliance cost**: If you use Stripe directly (without an MoR), you're responsible for sales tax in 40+ US states, VAT in 27 EU countries, UK VAT, Canadian GST, Australian GST, etc. Tools like TaxJar cost $50-500/month. An MoR like Paddle/LemonSqueezy eliminates this entirely.

**Recommended approach for GenQuery**: Use an MoR (Paddle or LemonSqueezy) for direct sales + App Stores for discoverability. The 5% MoR fee is a bargain compared to handling global tax compliance yourself.

---

## 5. Recommended Architecture for GenQuery

### Option A: Simplest Path (Recommended to Start)

**LemonSqueezy (or Paddle) for everything.**

```
┌──────────────────────────────────────────────────┐
│  Direct Purchase (genquery.io)                   │
│  LemonSqueezy checkout → license key issued      │
│  App validates via LemonSqueezy activation API   │
├──────────────────────────────────────────────────┤
│  Mac App Store Purchase                          │
│  StoreKit 2 receipt validation (local)           │
│  No license key needed — receipt IS the license  │
├──────────────────────────────────────────────────┤
│  Microsoft Store Purchase                        │
│  Windows.Services.Store API (local)              │
│  No license key needed — Store IS the license    │
└──────────────────────────────────────────────────┘
```

**Pros**: Minimal infrastructure. No server to run. LemonSqueezy handles payments, taxes, and licensing for direct sales. Store versions use native APIs.
**Cons**: Less control. No offline validation for direct-sale licenses. Can't unify entitlements across channels.

### Option B: Full Control (Recommended Long-Term)

**Keygen CE (self-hosted) + LemonSqueezy/Paddle as MoR for payments.**

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Licensing Server                     │
│                  (Keygen CE on a VPS)                        │
│                                                             │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ Direct Purchase  │  │ App Store    │  │ MS Store      │  │
│  │ LemonSqueezy    │  │ StoreKit 2   │  │ Store API     │  │
│  │ webhook ────────►│  │ JWS ────────►│  │ ID key ──────►│  │
│  └─────────────────┘  └──────────────┘  └───────────────┘  │
│           │                   │                  │           │
│           ▼                   ▼                  ▼           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Unified License Database                      │   │
│  │   license_key | channel | user | machines | features  │   │
│  └──────────────────────────────────────────────────────┘   │
│           │                                                  │
│           ▼                                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Signed License File (issued at activation)         │   │
│  │    Contains: user, features, expiry, machine_id       │   │
│  │    Signed with Ed25519 private key                    │   │
│  │    App verifies with bundled public key (offline)     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

GenQuery App (any platform):
  1. On first launch → prompt for license key (or detect store receipt)
  2. Activate online → server validates + returns signed license file
  3. Subsequent launches → verify signed license file locally (offline)
  4. Periodic heartbeat (every 14 days) → refresh license file
  5. Grace period (30 days) if server unreachable
```

**Pros**: Full control over licensing logic. Unified entitlements across all channels. Offline validation. Can implement complex tiers/features. Portable — not locked into any vendor.
**Cons**: You run a server (~$10/month). More upfront implementation work.

### Recommendation

**Start with Option A**, then migrate to Option B when you need more control (feature gating, offline validation, unified cross-platform entitlements). LemonSqueezy/Paddle for payments works with both options — only the licensing backend changes.

---

## 6. Implementation Plan

### Phase 0 — Decisions (Before Writing Code)

- [ ] Choose pricing model: one-time purchase, subscription, or freemium with paid upgrade
- [ ] Choose payment MoR: Paddle vs LemonSqueezy (both are solid; LemonSqueezy has more modern API)
- [ ] Decide on initial distribution: direct-only first? Or App Store simultaneously?
- [ ] Define license tiers and what features are gated (e.g., free = basic reports, pro = all reports + extensions)

### Phase 1 — Direct Sales Licensing (Weeks 1-3)

**Goal**: Users can buy GenQuery from your website and activate it.

1. **Set up MoR account** (LemonSqueezy or Paddle)
   - Create product listing ($X one-time or subscription)
   - Configure license key generation (activation limit: e.g., 3 machines)
   - Set up webhook endpoint for purchase events

2. **Implement license validation in GenQuery** (Nushell)
   - Store license key in `config/license.toml` or platform-specific secure storage
   - On first run: prompt for license key (or offer trial)
   - Validate key against MoR's activation API (HTTP POST)
   - Cache validation result locally (with timestamp) for offline use
   - On subsequent runs: check cached result; re-validate if stale (>14 days)

3. **Implement feature gating**
   - Define which `genq` commands are free vs. paid
   - Check license status before executing gated commands
   - Show friendly "upgrade" message for gated features

4. **Trial support**
   - Option A: Time-limited trial (14 days from first run, stored in signed local file)
   - Option B: Feature-limited free tier (no expiration, just fewer features)
   - Option B is generally better for long-term engagement

### Phase 2 — Mac App Store (Weeks 4-6)

**Goal**: GenQuery Terminal available on Mac App Store.

1. **App Store preparation**
   - Enable App Sandbox entitlements (test `.rmtree` file access with user-granted permissions)
   - Implement StoreKit 2 integration in genq-terminal (Swift/Zig interop layer)
   - Add `AppTransaction` validation for paid app or IAP unlock
   - Submit to App Store review

2. **Dual unlock path**
   - Detect `Contents/_MASReceipt/receipt` → use StoreKit validation
   - No receipt → fall back to direct-sale license key validation
   - Same binary, two unlock paths

### Phase 3 — Microsoft Store (Weeks 6-8)

**Goal**: GenQuery available on Microsoft Store.

1. **MSIX packaging**
   - Package genq-terminal for Windows as MSIX
   - Integrate `Windows.Services.Store` API for license validation
   - Submit to Microsoft Store

2. **Dual unlock path (Windows)**
   - Detect MSIX package context → use Store API
   - No package context → fall back to direct-sale license key

### Phase 4 — Unified Licensing Server (Optional, Weeks 8-12)

**Goal**: Migrate from MoR-managed licensing to self-hosted Keygen CE for full control.

1. **Deploy Keygen CE**
   - Provision a small VPS (DigitalOcean $10/month or Fly.io)
   - Deploy Keygen CE via Docker
   - Configure license policies (tiers, machine limits, expiration rules)
   - Set up webhook receivers for LemonSqueezy/Paddle purchase events

2. **Implement signed license files**
   - Generate Ed25519 keypair; embed public key in GenQuery
   - At activation: Keygen issues a signed license file
   - GenQuery validates signature locally (no network needed after activation)
   - Periodic heartbeat refreshes the file

3. **Integrate store receipts**
   - Apple: App sends StoreKit 2 JWS to Keygen → validate → issue license
   - Microsoft: App sends Store ID key to Keygen → validate via Collections API → issue license
   - All channels converge on unified license database

### Phase 5 — Polish & Hardening

- [ ] Implement graceful degradation (server unreachable → use cached license for 30 days)
- [ ] Add license management UI in genq-terminal (view license, deactivate machine, etc.)
- [ ] Set up monitoring/alerting on licensing server
- [ ] Implement license recovery flow (lost key → email lookup)
- [ ] Security audit of license validation (obfuscate validation logic to resist patching)

---

## 7. Appendix: Key Concepts Glossary

| Term | Definition |
|------|-----------|
| **Merchant of Record (MoR)** | A company that legally sells your product on your behalf, handling payment processing and all tax obligations (VAT, sales tax, GST). Paddle and LemonSqueezy are MoRs. Apple and Microsoft are MoRs for their stores. |
| **License key** | A string (e.g., `GENQ-XXXX-XXXX-XXXX`) that proves the user paid. Entered into the app to unlock it. |
| **Activation** | The process of binding a license key to a specific machine, registering the machine's fingerprint with the licensing server. |
| **Machine fingerprint** | A hash derived from hardware identifiers (CPU, disk, motherboard) that uniquely identifies a computer. |
| **Signed license file** | A JSON/binary file containing license details (user, features, expiry), signed with the developer's private key. The app verifies the signature using a bundled public key — no server needed. |
| **Entitlements** | Feature flags embedded in a license (e.g., `"advanced_reports": true`). Used to gate features by license tier. |
| **Receipt (App Store)** | A cryptographically signed proof of purchase placed in the app bundle by macOS. Validates that the user legitimately bought the app. |
| **StoreKit 2** | Apple's modern framework for handling purchases and subscriptions. Returns JWS (signed JSON) tokens. |
| **Notarization** | Apple's malware scanning service. Required for all macOS apps distributed outside the App Store. Not a licensing mechanism — just a safety gate. |
| **MSIX** | Microsoft's modern app packaging format. Required for Microsoft Store distribution of Win32 apps. |
| **Webhook** | An HTTP callback from a service to your server when an event occurs (e.g., "user purchased product"). Used to trigger license creation after payment. |
| **Keygen CE** | The self-hostable, source-available (ELv2) edition of Keygen's licensing API server. Free to run. |
| **Offline validation** | Verifying a license without contacting a server, using cryptographic signatures. |
| **Grace period** | Time the app continues working after the licensing server becomes unreachable (e.g., 30 days). |

---

## Key Resources

- **Keygen CE**: https://github.com/keygen-sh/keygen-api (self-host) / https://keygen.sh (cloud)
- **Keygen docs**: https://keygen.sh/docs/api/
- **LemonSqueezy**: https://lemonsqueezy.com (MoR + licensing)
- **Paddle**: https://paddle.com (MoR + licensing)
- **Apple StoreKit 2**: https://developer.apple.com/documentation/storekit
- **Apple App Store Server API**: https://developer.apple.com/documentation/appstoreserverapi
- **Apple server libraries**: https://github.com/apple/app-store-server-library-python (also Java, Node, Swift)
- **Microsoft Store licensing**: https://learn.microsoft.com/en-us/windows/uwp/monetize/view-and-grant-products-from-a-service
- **Sparkle (macOS auto-update)**: Already integrated in genq-terminal
