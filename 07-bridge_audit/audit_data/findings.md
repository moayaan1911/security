### [H-1] `TokenFactory::deployToken` deploys contracts from raw bytecode with `create`, which can never work on ZKsync Era, so token creation is dead on one of the two deployment targets

**Description::**
`deployToken` deploys whatever bytes it is handed using the `create` opcode inside an assembly block:

```javascript
function deployToken(string memory symbol, bytes memory contractBytecode) public onlyOwner returns (address addr) {
    assembly {
        addr := create(0, add(contractBytecode, 0x20), mload(contractBytecode))
    }
    s_tokenToAddress[symbol] = addr;
    emit TokenDeployed(symbol, addr);
}
```

The client deploys `TokenFactory` on both Ethereum Mainnet and ZKsync Era. On EraVM the operator must know the contract's code before deployment: a deployment passes the **bytecode hash** to the `ContractDeployer` system contract, and the bytecode itself has to be supplied in the `factory_deps` field of the EIP-712 transaction. Bytecode handed in as a runtime argument is unknown when the transaction is submitted, so it cannot be deployed. The zkSync docs use this exact snippet as their example of code that "will never work".

**Impact::**
`deployToken` cannot succeed on ZKsync Era, so the factory's only functionality fails on one of the two chains it is deployed to. No token can be created on L2 through it and `TokenDeployed` never fires there, while the identical call works on Ethereum Mainnet, which is exactly what makes it easy to miss before deployment.

**Proof of Concept::**
No test is needed, the official zkSync documentation uses this same code as its example.

- [EVM instructions](https://docs.zksync.io/zksync-protocol/era-vm/differences/evm-instructions): *"using `create`/`create2` in assembly blocks is unsafe, because the compiler will most likely silently produce broken bytecode... For instance, the following code will never work because contracts cannot be deployed on EraVM using any kind of bytecode:"* followed by `addr := create(0, add(bytecode, 0x20), mload(bytecode))`.
- [Contract deployment](https://docs.zksync.io/zksync-protocol/era-vm/differences/contract-deployment): *"the operator must be aware of the contract's code before deployment"*, and deployment calls the `ContractDeployer` with the **hash** of the contract while the bytecode is published through `factory_deps`.

**Recommended Solution::**
1. Stop accepting arbitrary bytecode and deploy a known contract type with constructor arguments, so the compiler knows the creation code and the zkSync tooling can put it in `factory_deps`:

```diff
-    function deployToken(string memory symbol, bytes memory contractBytecode) public onlyOwner returns (address addr) {
-        assembly {
-            addr := create(0, add(contractBytecode, 0x20), mload(contractBytecode))
-        }
+    function deployToken(string memory symbol, string memory name, uint256 initialSupply) public onlyOwner returns (address addr) {
+        L1Token token = new L1Token(name, symbol, initialSupply);
+        addr = address(token);
         s_tokenToAddress[symbol] = addr;
         emit TokenDeployed(symbol, addr);
     }
```
`L1Token` would take `name`, `symbol` and `initialSupply` in its constructor so the factory can still create differently named tokens with different supplies.

2. If arbitrary bytecode really is a requirement, it has to go through the zkSync deployment path: publish the bytecode in `factory_deps` and deploy via the `ContractDeployer` system contract using its bytecode hash, which the `hardhat-zksync` / `zksync-ethers` tooling handles. Do not just swap `create` for `create2`, the same docs page says `create2` in assembly is unsafe too.

3. If neither is acceptable, deploy `TokenFactory` only on Ethereum Mainnet and remove ZKsync Era from its deployment targets.
___
### [I-1] `L1Token::INITIAL_SUPPLY` is a large numeric literal, it should be written in e-notation

**Description::**
The initial supply is written as a full numeric literal, and the mint then multiplies it by the decimals:

```javascript
uint256 private constant INITIAL_SUPPLY = 1_000_000;
...
_mint(msg.sender, INITIAL_SUPPLY * 10 ** decimals());
```

Large literals are easy to miscount by a zero and harder to read at a glance. Aderyn reports this as `large-numeric-literal` (`L-2`).

**Recommended Solution::**
1. Use e-notation for the constant:

```diff
-    uint256 private constant INITIAL_SUPPLY = 1_000_000;
+    uint256 private constant INITIAL_SUPPLY = 1e6;
```

2. The mint stays correct once the constant reads `1e6`, so no other change is needed there.
___
### [I-2] `L1Vault` stores the token address with no zero address check, a misconfiguration is only caught at first use

**Description::**
The constructor assigns the token address directly, with no validation:

```javascript
constructor(IERC20 _token) Ownable(msg.sender) {
    token = _token;
}
```

A zero address is accepted at deployment and can never be corrected, so every later `approveTo` and every transfer through the vault fails only when it is first used. This is already covered by the client's Known Issues, which say zero address checks and input validation are skipped on purpose to save gas, so it is logged here as acknowledged rather than as a new bug. Aderyn reports it as `address-state-variable-set-without-checks` (`L-5`).

**Recommended Solution::**
1. Validate once at deployment, where it costs a single check for the lifetime of the contract:

```diff
     constructor(IERC20 _token) Ownable(msg.sender) {
+        if (address(_token) == address(0)) {
+            revert L1Vault__ZeroAddress();
+        }
         token = _token;
     }
```

2. Since the team already lists this as a known issue, the alternative is to keep the code as it is and record the acknowledgment in the report instead.