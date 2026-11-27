# Section 7 — Boss Bridge Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Days:** 23 &nbsp;·&nbsp; **Type:** Hands-on audit
**Goal:** Audit Boss Bridge, a centralized L1 ↔ L2 token bridge — onboarding, static analysis first, then the manual review.

← Back to [Smart Contract Security](../README.md)

---

## Day 23 — Section 7 kicked off: onboarding & how bridges work

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **A bridge links two chains that cannot see each other** | L1 locks the token in a vault and emits an event; an off-chain service watches that event and mints the matching token on L2. The contracts never talk to the other chain. |
| 2 | **Deposits and withdrawals are not symmetric** | L1 → L2 is escrow, the real token sits in the vault. L2 → L1 is attestation, an approved payload releases that escrow. |
| 3 | **The signature is the authority** | `sendToL1` recovers the signer from `keccak256(message)` and only executes if that address is in `signers`, so replay protection has to come from the message itself. |
| 4 | **The event is the protocol boundary** | The `Deposit` event is the API the off-chain relayer reads, so what the vault holds and what the event says have to agree. |
| 5 | **The trust model is the audit** | The owner pauses and sets signers, and a centralized service mints on L2. The client's known issues already say the bridge is centralized, so the review is about what the code still lets through. |
| 6 | **Pause is the emergency brake, not a fix** | The owner can pause deposits and sends, which stops the bleeding but trusts the owner to pull the lever in time. |

### How the bridge moves a token

| Direction | What happens | What has to be trusted |
|---|---|---|
| **L1 → L2 (deposit)** | `depositTokensToL2` pulls the token into `L1Vault` with `safeTransferFrom` and emits `Deposit(from, l2Recipient, amount)`. The off-chain service picks the event up and mints on L2. | The vault holds what the event says, and the relayer mints exactly that. |
| **L2 → L1 (withdrawal)** | A signer signs a payload, `withdrawTokensToL1` wraps it into a message and `sendToL1` recovers the signer, then executes the call, which moves the token out of the vault. | The signer set: L1 only checks that a signer signed, not what was signed. |

The L2 half of the bridge is not in this repo, so the L1 code and the off-chain signing policy are the whole auditable surface.

### The client repo & onboarding

- Cloned the client repo into [`boss-bridge/`](boss-bridge/)
- **Commit:** the client README lists `07af21653ab3e8a8362bf5f63eb058047f562375`, but that hash is outdated, so I worked from `main` instead (HEAD `d59479c`) and cut a new branch from there:

```bash
git switch -c audit-by-ayaan        # new branch straight off main
```

> The commit hash being stale is the same situation as Sections 4, 5 and 6. What matters is that the branch is cut from a known commit and the whole review stays on it.

- **Scope:** `src/L1BossBridge.sol`, `src/L1Token.sol`, `src/L1Vault.sol` and `src/TokenFactory.sol`, solc `0.8.20`
- **Deployment targets:** `L1BossBridge`, `L1Token`, `L1Vault` and `TokenFactory` on Ethereum Mainnet, `TokenFactory` also on ZKSync Era
- **Roles:** the owner (pause and unpause, set signers), the signers (authorise a token movement from L2 to L1), the vault (holds the tokens, owned by the bridge), and users (call `depositTokensToL2` for L1 → L2)
- **Known issues, so not findings:** the bridge is centralized, some zero address and input checks are skipped on purpose, magic numbers are literals, and `deployToken` is assumed to always receive a real `L1Token` copy. Weird ERC20s are explicitly out of scope
- Copied the [`templates/`](templates/) folder over from Section 6, since the report will be built from it later

### Static analysis, before manual review

| Tool | Command | Result |
|---|---|---|
| **Slither** | `make slither` | 22 contracts, 100 detectors, 13 results: `arbitrary-send-eth`, `arbitrary-send-erc20`, `low-level-calls`, `assembly`, `missing-zero-check`, `unused-return`, `pragma`, `solc-version`, `reentrancy-events`, `unindexed-event-address`, `constable-states`, `immutable-states` |
| **Aderyn** | `aderyn .` | [`boss-bridge/report.md`](boss-bridge/report.md) with 1 High and 10 Low |

Aderyn's High is `ETH transferred without address checks`. Its Lows are `L-1` centralization risk, `L-2` large numeric literal, `L-3` PUSH0, `L-4` state change without event, `L-5` address state variable set without checks, `L-6` state variable could be constant, `L-7` state variable could be immutable, `L-8` unchecked return, `L-9` unsafe ERC20 operation, `L-10` public function not used internally.

Every one of these is a lead, not a severity. They get read, triaged and either written up or dropped during the manual review.

### What I actually did

1. **Cloned the client repo** into [`boss-bridge/`](boss-bridge/) and read the README, scope, roles and known issues
2. **Checked the commit hash**, found it stale, and cut the `audit-by-ayaan` branch from `main`
3. **Ran `make slither` and `make aderyn`** to get a first map of the code before reading it by hand
4. **Read the four in-scope contracts** and traced one deposit and one withdrawal end to end
5. **Worked through the bridging theory**: what each direction actually does, and which part of the system has to be trusted for it to hold
6. **Carried the `templates/` folder over** from Section 6 so the report can be built the same way

### Day 23 — Key takeaways

1. **A bridge is a trust boundary, not a contract.** The code only enforces what the two chains and the off-chain service agree on.
2. **The two directions are not symmetric.** Deposit is escrow, withdrawal is attestation, and they fail differently.
3. **The signature is the authority.** If the signer set is the only check, replay protection has to live in the signed message.
4. **Read the known issues first.** Four of the client's notes are already out of scope, which changes what is worth writing up.
5. **Static analysis is the map.** Slither and Aderyn gave leads in seconds; the manual review decides what is real.

---

*Day 23 of my [smart contract security journey](../README.md). Section 7 — audit in progress.*