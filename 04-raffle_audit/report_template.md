<div class="cover">

<img src="logo.jpeg" alt="Logo" class="cover-logo" />

<h1 class="cover-title">Protocol Audit Report</h1>

<p class="cover-version">Version 1.0</p>

<p class="cover-org"><em>Mohammad Ayaan</em><br/>moayaan.com</p>

<p class="cover-date">November 8, 2026</p>

</div>

<div class="page-break"></div>

Prepared by: [Mohammad Ayaan](https://moayaan.com)

Lead Auditors:

- Mohammad Ayaan

# Table of Contents

- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [High](#high)
  - [\[H-1\] TITLE (Root Cause + Impact)](#h-1-title-root-cause-impact)
- [Medium](#medium)
- [Low](#low)
- [Informational](#informational)
- [Gas](#gas)

# Protocol Summary

Protocol does X, Y, Z

# Disclaimer

Mohammad Ayaan makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details

**The findings described in this document correspond to the following commit hash:**

```
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

## Scope

```
./src/
└── ProtocolName.sol
```

## Roles

- **Role 1:** What this role can do.
- **Role 2:** What this role can do.

# Executive Summary

_Add some notes about how the audit went, types of things you found, things you learned, etc._

## Issues found

| Severity      | Number of issues found |
| ------------- | ---------------------- |
| High          | 0                      |
| Medium        | 0                      |
| Low           | 0                      |
| Informational | 0                      |
| Gas           | 0                      |
| **Total**     | **0**                  |

# Findings

# High

### [H-1] TITLE (Root Cause + Impact)

**Description:**
Describe the issue and where it lives in the code.

**Impact:**
Describe what an attacker or user could do, and how bad it is.

**Proof of Concept:**
Steps, commands or a test that demonstrate the issue.

<details>
<summary>Here's the full code</summary>

```javascript
// Optional: long PoC test code goes here
```

</details>

**Recommended Mitigation:**
Describe the fix, with code if possible.

# Medium

No medium severity findings.

# Low

No low severity findings.

# Informational

No informational findings.

# Gas

No gas findings.
