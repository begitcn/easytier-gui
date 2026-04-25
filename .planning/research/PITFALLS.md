# Pitfalls Research

**Domain:** VPN/Network Management macOS Application Feature Enhancement
**Researched:** 2026-04-24
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Config Import Without Schema Validation

**What goes wrong:**
Importing a configuration file without validating the schema allows invalid or malicious configs to crash the app or cause undefined behavior. The app may fail silently or throw cryptic errors when loading malformed JSON.

**Why it happens:**
Developers assume imported configs follow the same format as exported configs. They skip validation because "we control the export format". However, users may hand-edit configs, use configs from different app versions, or import configs from other sources.

**How to avoid:**
- Implement explicit schema validation on import using a schema version field
- Validate all required fields exist and are of correct type before processing
- Provide clear error messages indicating which field is invalid
- Add a "dry run" mode that validates without applying

**Warning signs:**
- App crashes when importing user-edited config file
- Config loads but network fails with unrelated error messages
- Different behavior between imported and manually-created configs

**Phase to address:** Phase 1 (Config Import/Export Foundation)

---

### Pitfall 2: Config Export Includes Sensitive Data

**What goes wrong:**
Exporting configuration includes credentials, private keys, or tokens in plain text. Users share these files unknowingly, exposing sensitive network access credentials.

**Why it happens:**
Developers store all config properties in a single model without marking sensitive fields. Export serialization includes everything by default.

**How to avoid:**
- Mark sensitive fields (passwords, tokens, keys) with a protocol or attribute
- Implement `Codable` with `encode(to:)` that skips or redacts sensitive fields for export
- Provide explicit UI toggle "Include credentials" defaulting to off
- Warn users before exporting configs with sensitive data

**Warning signs:**
- Export file contains plaintext passwords or tokens
- Users share exported configs and later experience unauthorized access
- No warning dialog when exporting config with secrets

**Phase to address:** Phase 1 (Config Import/Export Foundation)

---

### Pitfall 3: Real-time Stats Polling Causes Performance Degradation

**What goes wrong:**
Fetching peer statistics, latency, and bandwidth data too frequently (e.g., every 100ms) consumes CPU, causes UI stuttering, and may overwhelm the underlying easytier-cli process.

**Why it happens:**
Developers implement "real-time" as "poll as fast as possible" without considering the cost. The easytier-cli command itself is relatively expensive, and SwiftUI bindings amplify the problem.

**How to avoid:**
- Use a polling interval of at least 1-2 seconds for stats updates
- Batch all stat queries into a single CLI call rather than multiple calls
- Use `Combine` throttling (`throttle(for:)`) to limit UI updates
- Consider using event-driven updates if easytier-cli supports it

**Warning signs:**
- CPU usage spikes when stats view is visible
- App becomes sluggish with multiple network runtimes
- Terminal shows rapid easytier-cli invocations

**Phase to address:** Phase 2 (Network Stats Implementation)

---

### Pitfall 4: Stats Display Shows Stale Data Without Indication

**What goes wrong:**
The stats UI shows latency/bandwidth numbers that are minutes old without any visual indication, leading users to believe they have current data when the network may be disconnected.

**Why it happens:**
Polling stops or fails silently when the network disconnects, but the UI continues showing the last known values. There's no "last updated" timestamp or "disconnected" state visualization.

**How to avoid:**
- Display "last updated" timestamp for all stats
- Show a clear disconnected/offline state with dimmed or grayed stats
- Use visual indicators (color, icon) for stale data (e.g., yellow after 30s, red after 60s)
- Implement a "refresh" button for manual update

**Warning signs:**
- Users report "stats show connected" when actually disconnected
- No visual change when network state changes while stats view is open
- Stats continue showing previous values after disconnect

**Phase to address:** Phase 2 (Network Stats Implementation)

---

### Pitfall 5: Advanced Settings Expose Internal Debug Options

**What goes wrong:**
Advanced settings panel exposes internal debugging options (log levels, verbose output, test flags) that can confuse users, cause unintended behavior, or create support burden.

**Why it happens:**
Developers add debug controls "temporarily" during development and forget to remove them. Or they add all possible options without prioritizing user-facing ones.

**How to avoid:**
- Separate "advanced" (power user) from "debug" (developer-only) settings
- Use a build flag to completely disable debug options in release builds
- Add a separate "Developer" section hidden by default behind a secret gesture or preference
- Document which options are safe to change

**Warning signs:**
- Settings include options like "Verbose logging", "Dump packet hex", "Test mode"
- Users ask about settings they shouldn't touch
- Settings contain values that crash the app when changed

**Phase to address:** Phase 3 (Advanced Settings UI)

---

### Pitfall 6: Auto-connect Runs Before Network is Ready

**What goes wrong:**
Auto-connect on startup fails because the network stack isn't ready when the app attempts to connect. The app shows "auto-connecting" but fails, confusing users.

**Why it happens:**
The app launches at login and immediately tries to connect, but macOS may not have fully initialized the network interfaces. Race condition between app launch and network availability.

**How to avoid:**
- Add a delay (3-5 seconds) before attempting auto-connect
- Monitor network interface availability and only connect when at least one interface is up
- Provide feedback: "Waiting for network..." rather than showing a failed attempt
- Allow users to configure auto-connect delay

**Warning signs:**
- Auto-connect always fails on first login attempt but works on retry
- Console shows network errors immediately after app launch
- Users disable auto-connect because it "never works"

**Phase to address:** Phase 4 (Auto-connect Implementation)

---

### Pitfall 7: Auto-connect Without User Consent After Update

**What goes wrong:**
After an app update, auto-connect settings are unexpectedly enabled or changed, causing the app to connect without the user's explicit intention.

**Why it happens:**
Code preserves the previous auto-connect preference during migration but doesn't consider that default should be off for new users, or there's a bug in preference migration logic.

**How to avoid:**
- Default auto-connect to OFF for new installations
- During migration, explicitly prompt users about auto-connect preference rather than assuming
- Log auto-connect state changes for debugging
- Provide clear UI indication when auto-connect is active

**Warning signs:**
- Users report unexpected network connections after update
- Auto-connect preference is unexpectedly true after fresh install
- No indication in UI that auto-connect is enabled

**Phase to address:** Phase 4 (Auto-connect Implementation)

---

### Pitfall 8: Quick Connect URL Scheme Collision

**What goes wrong:**
The custom URL scheme (e.g., `easytier://`) collides with another app or is too generic, causing conflicts. Or worse, a malicious app can register the same scheme and intercept connections.

**Why it happens:**
Developers pick a simple URL scheme without checking for conflicts, or use a scheme that's commonly used (e.g., `vpn://`, `connect://`).

**How to avoid:**
- Use a reverse-DNS style scheme: `com.easytier.gui.connect`
- Register the scheme with a complex, app-specific path
- Include a secret token in the URL to prevent brute-force attacks
- Document the URL scheme and warn about security implications

**Warning signs:**
- Other apps fail to register the same scheme
- Security scanners flag the URL scheme as vulnerable
- No validation of URL parameters before executing connect

**Phase to address:** Phase 5 (Quick Connect Implementation)

---

### Pitfall 9: Quick Connect Executes Without Confirmation

**What goes wrong:**
A quick-connect URL opens the app and automatically connects to a network without user confirmation. This can be exploited by malicious websites or other apps to silently connect the VPN.

**Why it happens:**
Developer assumes URLs come from trusted sources (e.g., user-created shortcuts). However, any app or webpage can trigger the URL scheme.

**How to avoid:**
- Always show a confirmation dialog for URL-triggered connections
- Display the network name and warn about network behavior
- Require user interaction to confirm before connecting
- Log all URL-based connection attempts for security audit

**Warning signs:**
- App connects immediately when receiving a URL without any UI
- No confirmation dialog appears for quick-connect shortcuts
- Security review flags "silent connect" vulnerability

**Phase to address:** Phase 5 (Quick Connect Implementation)

---

### Pitfall 10: Backup Excludes Critical Application State

**What goes wrong:**
Backup/restore only includes user-created configs but misses app state like window positions, recent connections, auto-connect preferences, or core version settings.

**Why it happens:**
Developer only backs up the obvious "config" files in Application Support, ignoring other state files. Different versions may have different state file locations.

**How to address:**
- Audit all files in Application Support and Library that contain user preferences
- Include version information in the backup to enable migration
- Test restore on a clean installation to verify completeness
- Provide a checklist of what's included in the backup

**Warning signs:**
- After restore, window position resets to default
- Auto-connect preference is lost after restore
- Recent networks list is empty after restore

**Phase to address:** Phase 6 (Backup/Restore Implementation)

---

### Pitfall 11: Backup File Format Not Versioned

**What goes wrong:**
Backup files created by different app versions are incompatible. Restoring an old backup on a new app version (or vice versa) fails or corrupts data.

**Why it happens:**
Developer assumes backup format is static. Adding new settings or changing data structures breaks backward/forward compatibility.

**How to avoid:**
- Include a version number in the backup file format
- Implement version-aware migration logic that can upgrade/downgrade
- Document the backup format and version history
- Test migration paths between major versions

**Warning signs:**
- Users cannot restore backups from older app versions
- Backup fails with "unsupported format version" error
- Data loss occurs after restore (missing fields)

**Phase to address:** Phase 6 (Backup/Restore Implementation)

---

### Pitfall 12: Restore Overwrites Current Configs Without Warning

**What goes wrong:**
Restoring a backup silently replaces all current configurations, causing data loss. Users lose their active networks without any confirmation.

**Why it happens:**
Developer implements restore as a simple "delete and replace" without checking if configs already exist or asking for user intent.

**How to avoid:**
- Always prompt: "Merge with existing" vs "Replace all"
- Show a preview of what will change before applying
- Create a backup of current state before restoring
- Offer to restore to a different profile/location

**Warning signs:**
- Users lose all configs after restore without warning
- No confirmation dialog appears during restore
- Current networks disappear without any indication why

**Phase to address:** Phase 6 (Backup/Restore Implementation)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip schema validation for config import | Faster to ship | App crashes on invalid configs | Never |
| Include credentials in config export | Simpler code | Security vulnerability | Never |
| Poll stats as fast as possible | "Real-time" feel | CPU drain, UI stuttering | Never |
| All settings visible by default | Simpler UI | User confusion, support burden | Never |
| Auto-connect without delay | Faster connection | Unreliable on slow networks | Never |
| Simple URL scheme | Easy to type | Conflicts, security issues | Never |
| Backup only config JSON | Less code to write | Lost preferences, inconsistent state | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| easytier-cli stats | Query separately for each metric | Batch all queries into single CLI call |
| File import | Read entire file into memory | Stream large files, validate incrementally |
| URL scheme handling | Parse URL without sanitization | Validate all URL parameters before use |
| Keychain for credentials | Store with accessibility always | Use `kSecAttrAccessibleWhenUnlocked` |
| Launch at login | Use deprecated `SMLoginItemSetEnabled` | Use `SMAppService.mainApp` (macOS 13+) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Stats polling every 100ms | High CPU, sluggish UI | Use 1-2s polling interval | Any network runtime |
| Large config arrays | Slow export/import | Paginate or lazy-load | >50 network configs |
| SwiftUI binding to CLI output | Rapid re-renders | Use `@State` with throttling | Any stats view |
| Blocking file I/O on main thread | App freezes during backup | Use async file operations | Large backup files |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Export config with plaintext passwords | Credential exposure | Use Keychain or redact before export |
| No URL scheme validation | Command injection | Validate all URL parameters strictly |
| Backup stored in unsecured location | Data theft | Encrypt backup with user password |
| Quick-connect without confirmation | Silent network connection | Always require user confirmation |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No import progress indication | User thinks app froze | Show progress bar for large configs |
| Stats show stale data without indication | User has wrong expectations | Show "last updated" + stale indicators |
| Auto-connect fails silently | User thinks feature broken | Show clear error with retry option |
| Backup complete overwrite | User loses current configs | Prompt for merge vs replace |

## "Looks Done But Isn't" Checklist

- [ ] **Config import:** Has schema validation — verify with malformed JSON
- [ ] **Config export:** Excludes sensitive fields — check exported file for passwords
- [ ] **Stats polling:** Uses throttling — verify no CPU spike in Instruments
- [ ] **Stats stale state:** Shows last updated time — verify on disconnect
- [ ] **Advanced settings:** No debug options exposed — check in release build
- [ ] **Auto-connect:** Has network-ready check — verify on slow network
- [ ] **URL scheme:** Uses reverse-DNS format — check for collisions
- [ ] **Quick-connect:** Shows confirmation dialog — verify from test URL
- [ ] **Backup:** Includes all app state — compare before/after folder
- [ ] **Restore:** Prompts for merge vs replace — verify with existing configs

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Invalid config import | LOW | Show error message, reject import, keep current config |
| Credential in export | MEDIUM | Issue security advisory, add redaction, ask users to regenerate credentials |
| Stats performance issue | LOW | Add throttling, reduce polling frequency |
| Auto-connect failure | LOW | Add retry with delay, show clear status |
| URL scheme conflict | MEDIUM | Change scheme to unique reverse-DNS format |
| Backup data loss | HIGH | Implement versioning, add migration tests |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Config import schema validation | Phase 1 | Test import with malformed JSON |
| Config export sensitive data | Phase 1 | Verify exported file has no secrets |
| Stats polling performance | Phase 2 | Profile CPU with stats view open |
| Stats stale data indication | Phase 2 | Disconnect network, verify UI shows stale |
| Advanced settings cleanup | Phase 3 | Release build should hide debug options |
| Auto-connect timing | Phase 4 | Test on slow network boot |
| Auto-connect consent | Phase 4 | Fresh install should have auto-connect off |
| URL scheme security | Phase 5 | Verify reverse-DNS scheme + validation |
| Quick-connect confirmation | Phase 5 | Trigger URL, verify confirmation dialog |
| Backup completeness | Phase 6 | Restore on clean install, verify all state |
| Backup versioning | Phase 6 | Restore old backup on new version |
| Restore overwrite | Phase 6 | Test with existing configs present |

## Sources

- Apple Developer Documentation: SMAppService for Login Items
- Apple Developer Documentation: URL Scheme Registration
- OWASP: Generic URL Scheme Security Considerations
- EasyTier GitHub: easytier-cli command documentation
- WWDC 2023: SwiftUI Performance Best Practices
- macOS Security: Authorization Services Best Practices
- Codebase analysis of EasyTierGUI v1.0 (2026-04-24)
- Personal experience with macOS app feature development

---
*Pitfalls research for: VPN/Network Management macOS Application Feature Enhancement*
*Researched: 2026-04-24*
