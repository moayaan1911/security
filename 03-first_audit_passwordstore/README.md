# Section 3 — First Audit: PasswordStore

**Status:** ✅ Complete &nbsp;·&nbsp; **Days:** 2–4 &nbsp;·&nbsp; **Type:** Hands-on audit
**Goal:** Onboard a real client repo, size it with tooling, review the code, and deliver a client-ready finding report.

📄 **Final report:** **[`audit_data/report.pdf`](audit_data/report.pdf)**

← Back to [Smart Contract Security](../README.md)

---

## Day 2 — Onboarding

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Audit onboarding** | The pre-code phase: collect repo, scope, commit hash, build/test commands and metrics *before* reading a single line. |
| 2 | **Never work from an Etherscan link** | Always ask for the repo — you can't build, test, grep or diff deployed bytecode. |
| 3 | **Check the Rekt Test** | Confirm the team has done it. If not, ask them to, and log it as a **red flag** in the report. |
| 4 | **Minimal onboarding questions** | A 5-point intake doc the client fills in — description, metrics, commands, commit hash, project info. |
| 5 | **Commit hash = the audit scope** | The hash you check out is the code you reviewed. Any commit after it is **unaudited**. |
| 6 | **Scope sizing (nSloc)** | Use `cloc` / Solidity Metrics to measure lines + complexity — that drives your time estimate and your price. |

### The minimal onboarding questions

Send the client a `minimal_onboarding_questions.md` and ask them to fill it in.

> 📄 **Reference file:** the copy in this folder is a **dummy** I made myself — not a real client response. It's my template showing exactly what info I ask for, and how the answers should look once a client fills it in. **[Open the dummy file →](minimal_onboarding_questions.md)**

| # | Question | Why it matters |
|---|----------|----------------|
| 1 | **Summary / description** | What the protocol is and what business it's building — context before code. |
| 2 | **Contract metrics** | `cloc` or Solidity Metrics for nSloc + complexity: how long the review takes and what to charge. |
| 3 | **Complete commands** | Build + test commands, so you can see what the team actually ran themselves. |
| 4 | **Commit hash** | ⚠️ The most important one — it fixes exactly what's in scope. Monitor it; later commits are unaudited. |
| 5 | **Contract / project info** | Solc version, Foundry version, external libs, deployed chains, roles & permissions, `.env` var **names** (never values). |

### Comparison tables

**Etherscan link vs full repo**

| | Etherscan link only | Full repo |
|---|---|---|
| **What you can do** | Read the code | Build, test, fuzz, grep, diff commits |
| **Verdict** | Not enough for a review | **Always ask for this** |

**Scope commit hash vs commits after it**

| | The scope hash | Commits after the hash |
|---|---|---|
| **Status** | ✅ Audited — this is what you reviewed | ❌ **Unaudited** — the team changed code after review |
| **Why it matters** | Fixes the reviewed snapshot | "We fixed it after the audit" is not an audit |

### What I actually did

The client repo lives in `password-store/`. In this case it's the Cyfrin course test repo, but I treated it as a real client handoff.

1. **Cloned** the client repo using the exact clone command from *their* README
2. **Checked out** the commit hash they specified — `7d55682ddc4301a7b13ae9413095feffd9924566`
3. **Created a working branch** (`audit-by-ayaan`) off that commit and did all work inside it
4. **Installed `cloc`** — a one-time global install
5. **Ran `cloc`** on their contract to measure lines of code
6. **Cross-checked** the count against the client's filled-in onboarding answers — and where the client hadn't filled it in, filled it myself (`nSloc: 20`)

> ⚠️ `password-store/` is the **client folder**. I never change its logic — the only edits are `@AUDIT` **comments** marking findings.

### Client at a glance

| Field | Value |
|---|---|
| In scope | `src/PasswordStore.sol` |
| Solc | `0.8.18` |
| Chain | Ethereum |
| Commit hash | `7d55682` |
| nSloc | `20` |

> **Gotcha I hit:** the client's README *inside* the `7d55682` checkout still lists the **older** hash `2e8f81e2`, because the README was updated to `7d55682` only in a **later** commit (`65129ec`). So always confirm the scope hash against the client's **latest** README, not the copy sitting inside your own checkout.

---

## Day 3 — Static metrics & annotation pass

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Solidity Metrics** | A VSCode extension that reports nSLOC, comment lines and a complexity score per contract — sizing *before* you read the code. |
| 2 | **Metrics as a sanity check** | Comparing tool output against my own onboarding estimate proves (or breaks) the time and price I quoted. |
| 3 | **Greppable audit tags** | Annotate the code inline with `// @AUDIT-*` so every finding is findable with one search instead of buried in a doc. |
| 4 | **Findings-first workflow** | Write findings into an `audit_notes.md` as I go — the final report gets assembled from notes, not memory. |

### Metrics on the client contract

Ran the extension over the client's `src/` folder and exported the report: **[`solidity-metrics.html`](solidity-metrics.html)**

| Metric | Value |
|---|---|
| Total lines (sloc) | `41` |
| **Source lines (nSLOC)** | **`20`** |
| Comment lines | `15` |
| Complexity score | **`10`** |
| Logic contracts | `1` |

**Did my onboarding estimate hold up?**

| Metric | My estimate (Day 2) | Solidity Metrics | Match |
|---|---|---|---|
| nSloc | 20 | 20 | ✅ |
| Complexity | 10 | 10 | ✅ |

> Small contract, exact match — good sign the sizing method works. On a real 3,000-line protocol this is the difference between quoting a week and quoting a month.

### My annotation tags

Every finding lives in the code, tagged so it's searchable:

| Tag | Meaning |
|---|---|
| `// @AUDIT-q::` | Open question for the client team |
| `// @AUDIT-HIGH::` | High severity finding |
| `// @AUDIT-Minor::` | Minor / informational |
| `grep -rn "@AUDIT"` | Pull up every annotation at once |

### Findings so far

Recorded in **[`audit_notes.md`](audit_notes.md)**:

| # | Severity | Finding | Where |
|---|---|---|---|
| 1 | Low | Compiler version `0.8.18` is not the latest | `pragma` |
| 2 | 🔴 **High** | `setPassword` has **no owner check** — anyone can overwrite the password | `setPassword()` |
| 3 | Minor | Wrong NatSpec — documents `@param newPassword` on a function that takes no params | `getPassword()` |
| 4 | 🔴 **High** | Password is stored in **plaintext on-chain** and readable by anyone | `s_password` |

> The two Highs are the same core mistake seen from two sides: the contract *pretends* to be private, but on-chain state is public and the write path is unguarded.

### Day 3 — Key takeaways

1. **Metrics first, code second.** Knowing nSLOC and complexity up front tells you how deep to go and what to charge.
2. **Verify your estimate with a tool.** My hand-estimate matched the real numbers here, which is exactly what you want before trusting it on a paid engagement.
3. **Tag findings in the code.** `@AUDIT` comments keep each finding next to the line it describes — far easier to write up than scrolling a doc.
4. **Write findings as you find them.** `audit_notes.md` is the draft; the report is the polish.

---

## Day 4 — Finding report & final PDF

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Finding report vs self notes** | `audit_notes.md` is my private scratchpad — the client only ever receives the structured finding report. |
| 2 | **Minimalist finding layout** | A fixed template (`finding_layout.md`) keeps every finding consistent: title, description, impact, PoC, recommended solution. |
| 3 | **`audit_data/` is the client-facing folder** | Everything inside it is what gets shared with the client; nothing outside it leaves my workspace. |
| 4 | **Severity ratings** | High breaks the protocol and risks user funds; Medium partially breaks it; Low doesn't break it but still needs fixing; Informational is a note, not a vulnerability. |
| 5 | **Report tooling** | `pandoc` + LaTeX produces the polished Cyfrin-style PDF, but the HTML route is far lighter for a first report. |

### What goes to the client (and what doesn't)

| File | Audience | Purpose |
|---|---|---|
| [`audit_notes.md`](audit_notes.md) | 🔒 Me only | Raw self-notes written during review — **never** sent to the client |
| [`finding_layout.md`](finding_layout.md) | Template | The minimalist structure every finding must follow |
| [`audit_data/findings.md`](audit_data/findings.md) | 📤 Client | Industry-standard write-up, built from the `@AUDIT` comments |
| [`audit_data/report.pdf`](audit_data/report.pdf) | 📤 Client | **Final audit report** |

> The findings were harvested straight out of the code with `grep -rn "@AUDIT"` — the Day 3 annotations effectively became the report's table of contents.

### Severity ratings

| Severity | Meaning |
|---|---|
| 🔴 **High** | Breaks the protocol completely, impacts user funds, and is likely to happen |
| 🟠 **Medium** | Partially breaks the protocol, may impact funds, and is likely to happen |
| 🟡 **Low** | Doesn't necessarily break the protocol, but still needs fixing |
| ⚪ **Informational** | Not a vulnerability — a note worth acting on |

**This audit:** `H-1` + `H-2` (High) and `I-1` + `I-2` (Informational). The two findings I'd provisionally marked Low/Minor on Day 3 were finalised as Informational.

### Building the PDF — the path I actually took

The client's README suggests `pandoc` + LaTeX with the `eisvogel` template. I installed pandoc and converted the logo to PDF — but the full LaTeX stack is **heavy (~5GB)** and fiddly for a first report.

**What I did instead:** generated an **HTML-friendly** report template, wrote `report.md` against it, and produced the PDF from that. Same content, a fraction of the setup.

> 📄 Templates kept for reference: [`report-example.md`](report-example.md) · [`report-example.html`](report-example.html)

### Day 4 — Key takeaways

1. **Notes and reports are different artifacts.** Self-notes are messy and private; the client report is structured and shippable.
2. **A template enforces consistency.** `finding_layout.md` means every finding answers the same questions in the same order.
3. **Severity is impact × likelihood, not cleverness.** Two of four findings were High because they hit user funds directly.
4. **Match tooling to your stage.** LaTeX gives the nicest output, but for a first audit the HTML route ships the same information at a fraction of the cost.

---

## Key takeaways

1. **Onboarding is a real phase**, not paperwork — most audit mistakes start with a fuzzy scope.
2. **The commit hash is the contract.** Everything after it is unaudited, so pin it and monitor it.
3. **Never accept an Etherscan link.** Without the repo you can't build, test, or diff.
4. **Sizing drives pricing.** nSloc and complexity tell you how long the review takes and what to charge.
5. **A missing Rekt Test is a red flag** — say so in the report.
6. **Ship the report, not your notes.** The deliverable is a structured finding report the client can act on.

---

*Days 2–4 of my [smart contract security journey](../README.md). **Section 3 complete** — first audit delivered.*