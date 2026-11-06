# Day 2 — Smart Contract Audits

**Status:** ✅ Section 2 complete &nbsp;·&nbsp; **Type:** New concepts
**Goal:** Understand what an audit actually is, how protocols prepare for one, what tooling auditors use, and who's responsible when things go wrong.

← Back to [Smart Contract Security](../README.md)

---

## Concepts covered

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Smart contract audit** | It's really a *security review* — a point-in-time expert read of the codebase plus testing, which **does not guarantee** the code is secure. |
| 2 | **The Rekt Test** | A readiness checklist that asks whether a protocol is even *prepared* to be audited — docs, verified team identity, fuzz/invariant tests, automated tooling, incident response. |
| 3 | **The test suite / tooling** | The auditor's kit: Foundry fuzz + invariant tests, static analyzers (Slither, Aderyn), formal verification, symbolic execution, and AI-assisted tools. |
| 4 | **"What if a protocol I audited gets hacked?"** | Auditors are **part** of the security review, not solely — or legally — responsible. An audit is a snapshot, not a warranty. |
| 5 | **Top web3 hacks** | Most losses come from a handful of recurring classes — and the ranking has **changed a lot** since 2023 (see the 2026 table below). |
| 6 | **The audit process** | A loop, not a one-off: initial review (scope → find → report) → protocol fixes → re-audit the fixes. |

---

## The audit process

1. **Initial phase** — **scoping** (what's in/out of scope, existing docs, threat model) → **vulnerability identification** (manual review + automated tooling) → **reporting** (severity, proof-of-concept, recommendations)
2. **Remediation** — the protocol team fixes the findings
3. **Re-audit** — verify each fix *and* check it didn't introduce new bugs, then loop back to step 1 until resolved

> This is a **loop, not a one-off handoff**. "Repeat step 1" in practice means a focused re-audit of the *changes*, not a full second audit of everything.

---

## Comparison tables

### "Audit" vs "security review"

| | "Audit" | Security review |
|---|---|---|
| **What it really is** | A point-in-time expert review of a codebase | The accurate name for that same work |
| **What it promises** | **Nothing absolute** — no guarantee the code is secure | **Nothing absolute** — auditors are one part of the process |

---

### Static analysis vs dynamic testing

| | Static analysis | Dynamic testing |
|---|---|---|
| **How it works** | Scans source code **without** running it | Runs the code with real or randomly generated inputs |
| **Best at** | Fast, cheap sweeps for known bad patterns (Slither, Aderyn) | Catching runtime bugs and broken invariants (Foundry fuzz/invariant) |

---

### Slither vs Aderyn

| | Slither | Aderyn |
|---|---|---|
| **Built with / by** | Python — Trail of Bits | Rust — Cyfrin |
| **Trade-off** | Mature, huge detector set, slower | Much faster, newer and smaller detector set |

---

### Formal verification vs symbolic execution

| | Formal verification | Symbolic execution |
|---|---|---|
| **Goal** | Prove a property holds for **all** possible inputs | Search paths for an input that **breaks** it |
| **Cost** | Very high effort — reserved for critical invariants | Cheaper, and often the engine formal tools run on (Halmos, Mythril) |

---

## Top web3 hacks — 2026 data

| # | Attack vector | 2026 picture |
|---|---|---|
| **#1** | **Private key / seed-phrase compromise** | **~76% of stolen value** from only ~15% of incidents — attacks on signing infrastructure, not on code |
| **#2** | **Social engineering / phishing** | 4 operations alone produced **$310M**, ~85% of all phishing losses |
| **#3** | **Smart contract bugs** | Still the most *common* category, but the **least lucrative** per incident |

**The ranking has flipped since 2023.** The course's 2023 data had price oracle manipulation at #1; by 2026, the majority of value is lost to stolen keys and operational failures, not clever code exploits.

Other 2026 numbers worth remembering:

- **H1 2026:** $1.315B stolen across 344 incidents (CertiK Hack3D)
- **Just two attacks** — KelpDAO (~$292M) and Drift Protocol (~$285M) — accounted for **~44% of all H1 losses**, and neither was a smart contract bug
- **North Korea** was linked to **~66%** of all stolen value in H1 2026 (TRM Labs)
- Individual incidents dropped in count but got **larger and more surgical** — fewer sprays, more precision strikes on big balances

> Sources: [TRM Labs — H1 2026 crypto hacks](https://www.trmlabs.com/resources/blog/h1-2026-crypto-hacks-reach-record-high-as-losses-fall-below-usd-1-billion) · [Chainalysis — 2025 crypto theft](https://www.chainalysis.com/blog/crypto-hacking-stolen-funds-2026/) · [CertiK Hack3D H1 2026](https://www.certik.com/skynet-report/certik-hack3d-h1-2026-report) · [Forbes analysis](https://www.forbes.com/sites/boazsobrado/2026/07/17/fewer-but-far-more-surgical-crypto-hacks-hit-13-billion-in-2026/)

---

## Key takeaways from Day 2

1. **An audit is risk reduction, not a guarantee.** Never tell anyone a codebase is "secure" because it was audited — that's the single most important framing in this section.
2. **Readiness matters as much as skill.** The Rekt Test is about whether a protocol can be *effectively* audited at all — missing docs or unverified team identity make an audit much weaker.
3. **Tooling is layered, never single.** Static analysis, fuzz/invariant testing, formal verification and manual review each catch different bug classes. No single tool finds everything.
4. **Most money is lost to a few repeated mistakes** — oracle manipulation, incentive design, and key management — not to clever novel exploits.
5. **Auditors are one link in the chain.** Post-audit hacks are usually a failure of the whole security process, not proof that the audit "didn't work".

---

*Day 2 of my [smart contract security journey](../README.md). Section 2 complete.*