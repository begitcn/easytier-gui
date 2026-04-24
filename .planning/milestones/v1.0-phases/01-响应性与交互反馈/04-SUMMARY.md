---
phase: 01-响应性与交互反馈
plan: 04
subsystem: authorization
tags: [privilege, authorization, toast, nsalert]

# Dependency graph
requires:
  - phase: 01-响应性与交互反馈
    provides: Toast notification system (03-PLAN.md)
provides:
  - Non-blocking authorization error handling via toast
  - Delayed authorization (prompt only on connect, not startup)
  - Retry action for authorization failures
  - isAuthorized and requestAuthorization() helpers in ProcessViewModel
affects: [connection-flow, error-handling]

# Tech tracking
added: []
patterns: [toast-based error notification, delayed authorization]

key-files:
  created: []
  modified:
    - EasyTierGUI/EasyTierGUIApp.swift
    - EasyTierGUI/Services/ProcessViewModel.swift

key-decisions:
  - "Use toast instead of blocking NSAlert for authorization errors"
  - "Delay authorization prompt until user connects (not at startup)"

patterns-established:
  - "Toast-based error handling: Use showToast with action for retryable errors"

requirements-completed: [STAB-03, D-02, D-07]

# Metrics
duration: 8min
completed: 2026-04-24
---

# Plan 1.4: Authorization Error Handling

**Replaced blocking NSAlert with toast notifications, delayed authorization prompt until connect**

## Performance

- **Duration:** 8 min
- **Tasks:** 5
- **Files modified:** 2

## Accomplishments
- Removed blocking `NSAlert.runModal()` for authorization errors
- Implemented toast-based error notification with retry button
- Made startup authorization check silent (no prompt at app launch)
- Added `isAuthorized` and `requestAuthorization()` to ProcessViewModel
- Added toast notification for missing easytier-core error

## Task Commits

All 5 tasks committed in single atomic commit:
- `d41d8f2` - feat(authorization): Replace blocking NSAlert with toast notifications

## Files Created/Modified
- `EasyTierGUI/EasyTierGUIApp.swift` - Modified `showAuthorizationError()` to use toast, made `checkRootPrivileges()` silent
- `EasyTierGUI/Services/ProcessViewModel.swift` - Added authorization helpers, toast for missing core, retry action for auth errors

## Decisions Made
- Replaced blocking NSAlert with toast notification for authorization errors
- Authorization dialog now only appears when user tries to connect, not at app startup

## Deviations from Plan
None - plan executed exactly as written

## Issues Encountered
None

## Next Phase Readiness
- Authorization error handling complete
- Ready for Plan 1.5: Log View Performance

---
*Plan: 04*
*Completed: 2026-04-24*
