# Smart Contract Security

My working repo for learning **smart contract security** — auditing Solidity, breaking things on purpose, and writing up everything I find along the way.

**Course:** [Cyfrin Updraft — Smart Contract Security](https://updraft.cyfrin.io/courses/security)

---

## Progress

| Day | Section | Status | Topics | Notes |
|-----|---------|--------|--------|-------|
| 1 | Section 1 — Revision | ✅ Complete | ERC20, ERC721, OpenZeppelin install, fuzz & invariant tests, storage, constants, `fallback` & `receive`, `abi.encode` & `abi.encodePacked`, `abi.decode`, `call` & `staticCall`, `abi.encodeWithSignature`, `selfdestruct` | [**Day 1 notes →**](01-review/README.md) |

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

## Repo structure

```
security/
└── 01-review/      # Day 1 — Section 1 revision notes + Foundry playground
    └── README.md   # Day 1 concepts & comparison tables
```

Each day gets its own numbered folder. Days that involve code are Foundry projects you can build and test directly.

---

*README written with DeepSeek Harness.*
