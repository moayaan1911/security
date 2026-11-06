# Day 2 — First Audit: PasswordStore

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Section:** 3 &nbsp;·&nbsp; **Type:** Hands-on audit
**Goal:** Run real audit onboarding on a client repo, then start the security review.

← Back to [Smart Contract Security](../README.md)

---

## What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Audit onboarding** | The pre-code phase: collect repo, scope, commit hash, build/test commands and metrics *before* reading a single line. |
| 2 | **Never work from an Etherscan link** | Always ask for the repo — you can't build, test, grep or diff deployed bytecode. |
| 3 | **Check the Rekt Test** | Confirm the team has done it. If not, ask them to, and log it as a **red flag** in the report. |
| 4 | **Minimal onboarding questions** | A 5-point intake doc the client fills in — description, metrics, commands, commit hash, project info. |
| 5 | **Commit hash = the audit scope** | The hash you check out is the code you reviewed. Any commit after it is **unaudited**. |
| 6 | **Scope sizing (nSloc)** | Use `cloc` / Solidity Metrics to measure lines + complexity — that drives your time estimate and your price. |

---

## The minimal onboarding questions

Send the client a `minimal_onboarding_questions.md` and ask them to fill it in.

> 📄 **Reference file:** the copy in this folder is a **dummy** I made myself — not a real client response. It's my template showing exactly what info I ask for, and how the answers should look once a client fills it in. **[Open the dummy file →](minimal_onboarding_questions.md)**

| # | Question | Why it matters |
|---|----------|----------------|
| 1 | **Summary / description** | What the protocol is and what business it's building — context before code. |
| 2 | **Contract metrics** | `cloc` or Solidity Metrics for nSloc + complexity: how long the review takes and what to charge. |
| 3 | **Complete commands** | Build + test commands, so you can see what the team actually ran themselves. |
| 4 | **Commit hash** | ⚠️ The most important one — it fixes exactly what's in scope. Monitor it; later commits are unaudited. |
| 5 | **Contract / project info** | Solc version, Foundry version, external libs, deployed chains, roles & permissions, `.env` var **names** (never values). |

---

## Comparison tables

### Etherscan link vs full repo

| | Etherscan link only | Full repo |
|---|---|---|
| **What you can do** | Read the code | Build, test, fuzz, grep, diff commits |
| **Verdict** | Not enough for a review | **Always ask for this** |

---

### Scope commit hash vs commits after it

| | The scope hash | Commits after the hash |
|---|---|---|
| **Status** | ✅ Audited — this is what you reviewed | ❌ **Unaudited** — the team changed code after review |
| **Why it matters** | Fixes the reviewed snapshot | "We fixed it after the audit" is not an audit |

---

## What I actually did

The client repo lives in `password-store/`. In this case it's the Cyfrin course test repo, but I treated it as a real client handoff.

1. **Cloned** the client repo using the exact clone command from *their* README
2. **Checked out** the commit hash they specified — `7d55682ddc4301a7b13ae9413095feffd9924566`
3. **Created a working branch** (`audit-by-ayaan`) off that commit and did all work inside it
4. **Installed `cloc`** — a one-time global install
5. **Ran `cloc`** on their contract to measure lines of code
6. **Cross-checked** the count against the client's filled-in onboarding answers — and where the client hadn't filled it in, filled it myself (`nSloc: 20`)

> ⚠️ `password-store/` is the **client folder** — strictly read-only. Nothing inside it gets edited.

---

## Client at a glance

| Field | Value |
|---|---|
| In scope | `src/PasswordStore.sol` |
| Solc | `0.8.18` |
| Chain | Ethereum |
| Commit hash | `7d55682` |
| nSloc | ~20 |

> **Gotcha I hit:** the client's README *inside* the `7d55682` checkout still lists the **older** hash `2e8f81e2`, because the README was updated to `7d55682` only in a **later** commit (`65129ec`). So always confirm the scope hash against the client's **latest** README, not the copy sitting inside your own checkout.

---

## Key takeaways

1. **Onboarding is a real phase**, not paperwork — most audit mistakes start with a fuzzy scope.
2. **The commit hash is the contract.** Everything after it is unaudited, so pin it and monitor it.
3. **Never accept an Etherscan link.** Without the repo you can't build, test, or diff.
4. **Sizing drives pricing.** nSloc and complexity tell you how long the review takes and what to charge.
5. **A missing Rekt Test is a red flag** — say so in the report.

---

*Day 2 of my [smart contract security journey](../README.md). Section 3 — audit in progress.*