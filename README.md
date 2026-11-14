# Smart Contract Security

My working repo for learning **smart contract security** — auditing Solidity, breaking things on purpose, and writing up everything I find along the way.

**Course:** [Cyfrin Updraft — Smart Contract Security](https://updraft.cyfrin.io/courses/security)
**Blog:** [What I Learnt From My First Smart Contract Audit](https://medium.com/@moayaan.eth/what-i-learnt-from-my-first-smart-contract-audit-42f355b53886) — Medium

---

## Progress

| Day | Section | Status | Topics | Notes |
|-----|---------|--------|--------|-------|
| 1 | Section 1 — Revision | ✅ Complete | ERC20, ERC721, OpenZeppelin install, fuzz & invariant tests, storage, constants, `fallback` & `receive`, `abi.encode` & `abi.encodePacked`, `abi.decode`, `call` & `staticCall`, `abi.encodeWithSignature`, `selfdestruct` | [**Day 1 notes →**](01-review/README.md) |
| 2 | Section 2 — Smart Contract Audits | ✅ Complete | What an audit really is, the Rekt Test, test suites & tooling (Slither, Aderyn, formal verification, symbolic execution), hack liability, top web3 hacks | [**Day 2 notes →**](02-audit_info/README.md) |
| 2–4 | Section 3 — First Audit: PasswordStore | ✅ Complete | Client onboarding, scope & commit hash, Solidity Metrics sizing, `@AUDIT` annotations, severity ratings, industry-standard finding report, final PDF | [**Section 3 notes →**](03-first_audit_passwordstore/README.md) · [**Report PDF →**](03-first_audit_passwordstore/audit_data/report.pdf) |
| 5–9 | Section 4 — Puppy Raffle Audit | ✅ Complete | Slither & Aderyn static analysis, DoS proof, ReEntrancy & CEI, weak randomness, overflow & unsafe casting, mishandling of ETH via `selfdestruct`, `@AUDIT` question tagging, competitive audit submission, 17 findings written up | [**Section 4 notes →**](04-raffle_audit/README.md) · [**Report PDF →**](04-raffle_audit/audit_data/report.pdf) |
| 10 | Section 5 — TSwap Audit | 🚧 In Progress | Client onboarding (extensive questions), AMMs vs order books, liquidity pools, constant product formula, LP shares & provider risk, `forge coverage`, stale commit hash | [**Section 5 notes →**](05-tswap_audit/README.md) |

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

## Day 5 — What I learnt

Day 5 started Section 4 (the Puppy Raffle audit) — my first time running automated analysis tools over a real codebase.

- **Static analyzers first.** Slither (`uv tool install slither-analyzer`) and Aderyn (`npm install @cyfrin/aderyn -g`) both scan a codebase and hand you a map of it in seconds — far more valuable as contracts grow past a few dozen lines.
- **Colour is triage, not truth.** Slither's output is red (high risk), yellow (medium) and green (informational/low). Red gets investigated immediately; green still gets read during a deep audit.
- **Aderyn writes the report for you.** Running `aderyn .` produces `report.md` — a near-ready audit report in markdown.
- **Denial of Service (DoS)** — an attacker doesn't steal anything; they make an action so gas-expensive that legitimate users can no longer use the protocol.
- **The classic DoS shape** — an unbounded loop over an array that only grows. In `DoS.sol`, every `enter()` loops over all previous entrants, so each new entry costs more gas until nobody else can afford to enter.
- **Real-world DoS** — the course showed audits where this pattern actually mattered: **GMX V2** and **Bridges Exchange**.

**One deviation from the client's README:** this time their commit hash was stale, so per the course I stayed on the latest commit and worked from a new branch (`audit-by-ayaan`) instead of checking out the hash.

Full notes: **[Section 4 notes →](04-raffle_audit/README.md)**

---

## Day 6 — What I learnt

Day 6 was about **proving** findings rather than just spotting them, plus my first taste of ReEntrancy.

- **A finding isn't a finding until you can prove it.** The DoS was visible in the code, but the gas-measuring test is what made it credible: the first 100 players cost `6,538,557` gas, the next 100 cost `19,242,109`. Nearly 3× for identical work.
- **Dependencies are part of the audit surface.** The client's pinned `forge-std` was too old — `vm.txGasPrice` needs v1.6.0+, and its legacy `console.log(string, uint)` silently emitted nothing, so the test passed with no output at all.
- **ReEntrancy is an ordering bug.** If a contract makes an external call before updating its own state, the attacker re-enters before their balance is zeroed and drains the contract in a loop.
- **The CEI pattern is the fix:** **C**hecks (validate) → **E**ffects (update state) → **I**nteractions (external calls last). Reorder the function and re-entry hits a zero balance.
- **ReentrancyGuard is the seatbelt.** [OpenZeppelin's `ReentrancyGuard`](https://docs.openzeppelin.com/contracts/3.x/api/utils#ReentrancyGuard) blocks re-entrant calls — one reason ReEntrancy is much rarer today than in early contracts.

**Findings so far:** `H-1` (DoS in `enterRaffle`) and `H-2` (ReEntrancy in `refund`), both written up in `audit_data/findings.md`, plus 3 open `// @AUDIT-q::` questions carried over from Day 5. Section 4 is still in progress — it's a big one.

Full notes: **[Section 4 notes →](04-raffle_audit/README.md)**

---

## Day 7 — What I learnt

Day 7 was the biggest finding day so far: five findings written up, four of them with working tests.

- **Weak randomness is grindable.** `keccak256(msg.sender, block.timestamp, block.difficulty)` is not random. All three inputs are public, and the block producer picks two of them, so an attacker can brute-force the timestamp until the "random" output favours them. Real fairness needs an oracle like [Chainlink VRF](https://docs.chain.link/vrf).
- **Overflow on 0.7.x is silent.** `totalFees + fee` wraps around instead of reverting, because the contract runs Solidity `0.7.6`. My PoC pushes the total past `uint64` max and shows 24 ETH of fees recording as 5.55 ETH.
- **Narrowing casts never revert.** `uint64(fee)` drops the high bits, so a 20 ETH fee records as 1.55 ETH. This still happens on Solidity 0.8+, because the built-in checks cover arithmetic but not conversions.
- **Ambiguous return values are bugs too.** `getActivePlayerIndex` returns `0` for players who never entered, which is exactly the same value as the real player sitting at index `0`.
- **A question counts as a finding.** The 80/20 winner-to-fee split is never documented anywhere, so it went in as `Q-1` rather than being assumed correct.

**Today's findings:** `H-3` (weak randomness), `M-1` (overflow), `M-2` (unsafe casting), `I-1` (index `0` collision) and `Q-1` (split percentage), all in `audit_data/findings.md`.

**Tests written:** `test_GetActivePlayerIndex_AUDIT`, `test_WeakRandomness_AUDIT`, `test_ArithmeticOverflow_AUDIT`, `test_UnsafeCasting_AUDIT`.

Full notes: **[Section 4 notes →](04-raffle_audit/README.md)**

---

## Day 8 — What I learnt

Day 8 was about annotating the contract properly, and one more High: mishandling of ETH.

- **An audit is not only a bug hunt.** Questions get tagged inline too, with `// @AUDIT-q`, even the small ones. Clearing every question with the client is what makes a bigger bug show up later.
- **Never assume, always ask.** If the intent is not written down, it is a question for the client, not something to decide yourself.
- **Mishandling of ETH.** A contract that assumes its ETH balance can only change through its own functions. `selfdestruct` proves it wrong: it force-feeds ETH without ever calling the target, so no `receive` or `fallback` can reject it.
- **Strict balance checks are a trap.** `address(this).balance == totalFees` becomes permanently false once extra ETH lands, so `withdrawFees` reverts forever. The fix is `>=`, or better, tracking what the protocol owes in its own variable.
- **Slither suppressions carry responsibility.** `// slither-disable-next-line arbitrary-send-eth` silences one detector, and only where I had verified it was a false positive (`feeAddress` is owner controlled).
- **Tag lifecycle.** Answered by the code? Remove it. Code quality? Convert it to a finding tag. Genuine design intent? Leave it as `-q` for the client.

**Today's findings:** `H-4` (mishandling of ETH, High), `L-1` (loop vs mapping, Low) and eight Informationals (`I-2` to `I-9`), plus `Q-1` rewritten as the empty players array question. Also ran `slither .` and `aderyn .` for the final automated pass.

**Tests written:** `test_MishandlingOfETH_AUDIT` (with an `ETHForcer` attacker) and `test_LoopBasedMembershipCheck_AUDIT`. Suite: 27 tests passing.

`findings.md` is now ordered **H → M → L → Q → I**, so the worst news comes first.

Full notes: **[Section 4 notes →](04-raffle_audit/README.md)**

---

## Day 9 — What I learnt

Day 9 closed out Section 4: a competitive audit submission and the final client report.

- **Competitive audits are a different game.** Many auditors review the same code, findings get deduplicated, and judges decide the final severity. Being right is not enough, the write-up has to be provable and easy to grade.
- **Only High, Medium and Low get submitted.** Competitive platforms pay for those. Informational and Question findings are good practice and belong in a QA report, not in the main submission.
- **The submission format is its own skill.** Title as Root cause + Impact, `@>` markers on the buggy lines, Risk as Likelihood × Impact, then a PoC and a mitigation diff.
- **The report is a pipeline, not a file.** `report.md` is the editable source, `report.html` is the styled version with the logo and the open code blocks, and `report.pdf` is the only artifact the client actually needs.
- **Metadata matters.** A PDF with a wrong title or no author looks unfinished, so the title, author, subject and keywords get set properly.

**Submitted:** my first competitive audit on CodeHawks, with `H-1` to `H-4`, `M-1`, `M-2` and `L-1` (7 findings). The 10 Informational and Question findings stayed out of the submission and live in `findings.md`.

**Deliverables:** `findings_competitive.md` (CodeHawks format), and the report set `report.md` → `report.html` → `report.pdf` (25 pages), all in `04-raffle_audit/audit_data/`.

📄 **Final report: [PuppyRaffle audit report (PDF) →](04-raffle_audit/audit_data/report.pdf)**

Full notes: **[Section 4 notes →](04-raffle_audit/README.md)**

---

## Day 10 — What I learnt

Day 10 started Section 5: onboarding the TSwap client and learning how AMMs actually work.

- **AMMs replaced order books.** Order books are gas-expensive and do not scale on-chain. An AMM prices trades with a formula against a pool instead of matching buyers and sellers.
- **Liquidity pools have no counterparty.** Anyone can trade against the pool at any time, with no central entity and no confirmation from other users.
- **The constant product formula** (`x * y = k`) is what sets the price: buying one token pushes its price up and the other down.
- **Liquidity providers are the other side of every trade.** They deposit both tokens and receive LP shares, which earn a cut of the trading fees.
- **Being an LP is a financial risk, not free yield.** If one token in the pool collapses, the loss can dwarf everything earned in fees.
- **Onboarding quality is a signal.** A client that fills in extensive onboarding questions properly shows professionalism, and it decides how much you can trust their docs.
- **Thin test coverage is itself a finding.** TSwap's `forge coverage` came back very low, so the existing tests prove almost nothing about the protocol.

**One deviation from the client's README, again:** the commit hash was stale, so I stayed on the latest commit and worked from a new branch `audit-by-ayaan`.

**Scope:** `src/PoolFactory.sol` and `src/TSwapPool.sol`. Section folder now has `templates/` (finding layout, report templates, onboarding questions, logo) and the client repo under `tswap/`.

Full notes: **[Section 5 notes →](05-tswap_audit/README.md)**

---

## Repo structure

```
security/
├── 01-review/                       # Section 1 — revision notes + Foundry playground
│   └── README.md                    # concepts & comparison tables
├── 02-audit_info/                   # Section 2 — audits & tooling notes
│   └── README.md                    # concepts & comparison tables
├── 03-first_audit_passwordstore/    # Section 3 — first audit ✅
│   ├── README.md                    # full write-up: onboarding → findings → report
│   ├── audit_notes.md               # private self-notes (never shared)
│   ├── finding_layout.md            # finding template
│   ├── minimal_onboarding_questions.md
│   ├── audit_data/                  # 📤 client-facing deliverables
│   │   ├── findings.md              # industry-standard findings
│   │   ├── report.md                # report source
│   │   └── report.pdf               # ✅ final audit report
│   └── password-store/              # client repo
└── 04-raffle_audit/                 # Section 4 — puppy raffle audit ✅
    ├── README.md                    # full audit write-up (Days 5–9)
    ├── audit_notes.md               # private self-notes (never shared)
    ├── findings_layout.md           # finding template
    ├── report_template.md           # report skeleton
    ├── profile.jpeg                 # logo used on the report cover
    ├── DoS.sol                      # teaching example — denial of service
    ├── ReEntrancy.sol               # teaching example — ReEntrancy
    ├── WeakRandomness.sol           # teaching example — weak randomness
    ├── Arithmatic.sol               # teaching example — overflow / precision loss
    ├── MishandlingEth.sol           # teaching example — forced ETH / selfdestruct
    ├── audit_data/                  # 📤 client-facing deliverables
    │   ├── findings.md              # H-1…H-4, M-1, M-2, L-1, Q-1, I-1…I-9
    │   ├── findings_competitive.md  # H/M/L only, CodeHawks format
    │   ├── report.md                # report source
    │   ├── report.html              # styled single-file report
    │   └── report.pdf               # ✅ final audit report
    └── puppy-raffle/                # client repo
└── 05-tswap_audit/                  # Section 5 — TSwap audit (WIP)
    ├── README.md                    # full audit write-up (Day 10)
    ├── audit_notes.md               # private self-notes (never shared)
    ├── templates/                   # finding + report templates, onboarding questions, logo
    └── tswap/                       # client repo
```

Each **section** of the course gets its own numbered folder — the number matches the *section*, not the day. Folders that contain code are Foundry projects you can build and test directly.

---

*README written with DeepSeek Harness.*
