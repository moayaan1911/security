# Smart Contract Security

My working repo for learning **smart contract security** — auditing Solidity, breaking things on purpose, and writing up everything I find along the way.

**Course:** [Cyfrin Updraft — Smart Contract Security](https://updraft.cyfrin.io/courses/security)

---

## Progress

| Day | Section | Status | Topics | Notes |
|-----|---------|--------|--------|-------|
| 1 | Section 1 — Revision | ✅ Complete | ERC20, ERC721, OpenZeppelin install, fuzz & invariant tests, storage, constants, `fallback` & `receive`, `abi.encode` & `abi.encodePacked`, `abi.decode`, `call` & `staticCall`, `abi.encodeWithSignature`, `selfdestruct` | [**Day 1 notes →**](01-review/README.md) |
| 2 | Section 2 — Smart Contract Audits | ✅ Complete | What an audit really is, the Rekt Test, test suites & tooling (Slither, Aderyn, formal verification, symbolic execution), hack liability, top web3 hacks | [**Day 2 notes →**](02-audit_info/README.md) |
| 2–4 | Section 3 — First Audit: PasswordStore | ✅ Complete | Client onboarding, scope & commit hash, Solidity Metrics sizing, `@AUDIT` annotations, severity ratings, industry-standard finding report, final PDF | [**Section 3 notes →**](03-first_audit_passwordstore/README.md) · [**Report PDF →**](03-first_audit_passwordstore/audit_data/report.pdf) |

---

## Day 1 — What I learnt

Before touching real audits, Section 1 made me go back and properly re-solidify the fundamentals I'd already been using:

- **Token standards** — how ERC20 and ERC721 actually work, and why you use audited OpenZeppelin implementations instead of writing your own.
- **Testing as a security tool** — the difference between fuzz tests (random *inputs* into one function) and invariant tests (random *function sequences*, asserting a property across every reachable state).
- **Where data really lives** — storage slots vs `constant`/`immutable` in bytecode, and why that distinction is a gas *and* correctness question.
- **The special functions** — `fallback` vs `receive`, and what a contract does when it's called with calldata it doesn't recognise.
- **Encoding** — `abi.encode` vs `abi.encodePacked`, `abi.decode`, and the hash-collision class of bug hiding behind packed encoding.
- **Low-level calls** — `call` vs `staticCall`, `abi.encodeWithSignature`, and why an unchecked return value is a silent failure.
- **`selfdestruct`** — how it behaves today, and how forced ETH can break a contract's balance assumptions.

Full one-liners and comparison tables: **[Day 1 notes →](01-review/README.md)**

---

## Day 2 — What I learnt

Day 2 covered Section 2 (how reviews work) and started Section 3 — my first real audit.

### Section 2 — Smart Contract Audits

Section 2 moved from *how contracts work* to *how you review them*:

- **An audit is not a guarantee** — it's a security review. It reduces risk, but it never proves a codebase is safe, and framing it that way is the core lesson of the section.
- **The Rekt Test** — a readiness checklist for protocols: documentation, verified identity of team members, fuzz and invariant tests, automated tooling, incident response plans.
- **The auditor's tooling stack** — Foundry fuzz & invariant tests, static analyzers (Slither, Aderyn), formal verification, symbolic execution, and AI-assisted tools. Each catches different bug classes, so they're layered.
- **Liability after a hack** — auditors are one part of the security review. They aren't solely or legally responsible for a post-audit exploit; an audit is a point-in-time snapshot.
- **Where the money actually goes** — as of 2026, stolen keys beat code exploits: ~76% of stolen value comes from private-key and seed-phrase compromise, not from contract bugs.

Full one-liners and comparison tables: **[Section 2 notes →](02-audit_info/README.md)**

### Section 3 — First Audit: PasswordStore *(in progress)*

- **Onboarding is its own phase** — repo, scope, commit hash, build/test commands and metrics all get collected *before* reading any code.
- **The commit hash is the scope** — the hash you check out is exactly what you reviewed; anything committed after it is unaudited.
- **Never accept an Etherscan link** — without the repo you can't build, test, fuzz, grep or diff.
- **Sizing drives pricing** — `cloc` / Solidity Metrics give nSloc and complexity, which estimate review time and cost.
- **A missing Rekt Test is a red flag** — check it during onboarding and call it out in the report.

Full notes and the onboarding workflow: **[Section 3 notes →](03-first_audit_passwordstore/README.md)**

---

## Day 3 — What I learnt

Day 3 was the actual review pass on the PasswordStore contract — measure it with tooling, then read it line by line.

- **Solidity Metrics for sizing** — the VSCode extension reports nSLOC, comment lines and a complexity score per contract. My Day 2 hand-estimate (nSloc 20, complexity 10) matched the tool **exactly**, which is the check you want before trusting your own sizing on a paid engagement.
- **Annotate findings in the code** — every issue is tagged inline with `// @AUDIT-q::`, `// @AUDIT-HIGH::` or `// @AUDIT-Minor::`, so `grep -rn "@AUDIT"` pulls the entire review up at once instead of digging through a doc.
- **Findings-first workflow** — notes go into `audit_notes.md` as I find them; the final report gets assembled from those notes, not from memory.

**Findings so far — 2 High, 1 Low, 1 Minor:** the Highs are a **missing owner check** on `setPassword` (anyone can overwrite the password) and the password being stored in **plaintext on-chain** (anyone can read it).

Full notes, metrics and the findings table: **[Section 3 notes →](03-first_audit_passwordstore/README.md)**

---

## Day 4 — What I learnt

Day 4 turned the findings into an actual client deliverable — a report.

- **Notes ≠ report.** `audit_notes.md` is my private scratchpad; the client receives only the structured finding report. Keeping those two separate is deliberate, not tidiness.
- **A template enforces consistency.** `finding_layout.md` is a minimalist structure — title, description, impact, proof of concept, recommended solution — and every finding follows it in that order.
- **`audit_data/` is the client-facing folder.** What's inside it gets shared; what's outside stays mine.
- **Severity ratings.** High = breaks the protocol completely and risks user funds. Medium = partially breaks it. Low = doesn't break it but still needs fixing. Informational = a note, not a vulnerability.
- **The report is the product.** Being right about a bug matters less than communicating it in a form the client can actually act on.

**This audit:** `H-1` + `H-2` (High) and `I-1` + `I-2` (Informational). The client README suggested `pandoc` + LaTeX with the eisvogel template — I installed pandoc, but the full LaTeX stack is ~5GB and heavy for a first report, so I used an HTML-friendly template instead and produced the PDF from that.

📄 **Final report: [PasswordStore audit report (PDF) →](03-first_audit_passwordstore/audit_data/report.pdf)**

Full notes: **[Section 3 notes →](03-first_audit_passwordstore/README.md)**

---

## Repo structure

```
security/
├── 01-review/                       # Section 1 — revision notes + Foundry playground
│   └── README.md                    # concepts & comparison tables
├── 02-audit_info/                   # Section 2 — audits & tooling notes
│   └── README.md                    # concepts & comparison tables
└── 03-first_audit_passwordstore/    # Section 3 — first audit ✅
    ├── README.md                    # full write-up: onboarding → findings → report
    ├── audit_notes.md               # private self-notes (never shared)
    ├── finding_layout.md            # finding template
    ├── minimal_onboarding_questions.md
    ├── audit_data/                  # 📤 client-facing deliverables
    │   ├── findings.md              # industry-standard findings
    │   ├── report.md                # report source
    │   └── report.pdf               # ✅ final audit report
    └── password-store/              # client repo
```

Each **section** of the course gets its own numbered folder — the number matches the *section*, not the day. Folders that contain code are Foundry projects you can build and test directly.

---

*README written with DeepSeek Harness.*
