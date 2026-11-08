### [H-1] Password stored on-chain without encryption, ANYONE can read them

**description::**
All data stored on-chain is visible to anyone and can be read directly from the blockchain. The `s_password` variable is intended to be a private variable and only accessed through the `getPassword` function, which is intended to be only called by the owner of the contract.

We show one such method of reading any data off chain below.

**impact::**
Anyone can read the private password, severely breaking the functionality of the protocol

**Proof of Concept::**
The below test case proves that anyone can read the private passwords from blockchain easily

1. Run the local anvil chain using anvil command

```bash
make anvil
```

2. Run the deployment command

```bash
make deploy
```

3. Run the cast storage command to read slot 1, where `s_password` is stored

```bash
cast storage <Address> 1 --rpc-url http://127.0.0.1:8545
```

You will get something like this:

```text
0x6d7950617373776f726400000000000000000000000000000000000000000014
```

4. Run the cast parse-bytes32-string command on that returned value

```bash
cast parse-bytes32-string <Bytes32Object>
```

You will get the password in plain text:

```text
myPassword
```

**Recommended Solution::**
Because of this, the entire ARCHITECTURE of the contract should be rethought. We usually send example code to help with the fix, but in this case the architecture itself is wrong, so the team needs to think through a better design and problem-solve from scratch.
One possible approach is to encrypt the password off-chain and store only the encrypted value on-chain — but this would require the user to remember a second password off-chain in order to decrypt the original. You would also likely want to remove the view function, so the password can never be exposed just by calling the contract.

___

### [H-2] `setPassword` has no access controls, means a non-owner can change the password.

**Description::**
The `setPassword` function has no access control, and is external, allowing anyone to set passwords. However, the natspec comment indicates that the purpose is for only the `owner` to set the password

```javascript
    /*
     * @notice This function allows only the owner to set a new password.
     * @param newPassword The new password to set.
     */
    // @AUDIT-HIGH:: This function has no access control, allows anyone to set the password, not just the owner. This is a critical security flaw!
    function setPassword(string memory newPassword) external {
        s_password = newPassword;
        emit SetNetPassword();
    }
```

**Impact::**
Anyone can set/change the password of the contract, breaking the contract's design severely.

**Proof of Concept::**
Added the `test_anyone_can_set_password_AUDIT` test function inside the `PasswordStore.t.sol` file. Run the test using 
`forge test --mt test_anyone_can_set_password_AUDIT` and it will pass, proving that the setPassword can be called by random address which is not owner
<details>
<summary>Here's the full code</summary>

```javascript
    // @AUDIT-HIGH:: This test demonstrates that anyone can set the password, not just the owner. This is a critical security flaw!
    function test_anyone_can_set_password_AUDIT(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.prank(randomAddress);
        string memory newPassword = "hackedPassword";
        passwordStore.setPassword(newPassword);
        vm.prank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, newPassword);
    }
```

</details>

**Recommended Solution::**
Add an access control conditional to the `setPassword` function. Could also use an `onlyOwner` modifier

```javascript
if(msg.sender != s_owner){
    revert PasswordStore__NotOwner();
}
```

___

### [I-1] Compiler Version check. NO impact on the code

**Description::**
The compiler version is old. Since this is a new protocol I "expected" it to have newest compiler version.

**Impact::**
No Impact on the codebase.

**Proof of Concept::**
You are using a Solidity version that is quite old

```javascript
pragma solidity 0.8.18;
```

**Recommended Solution::**
You can use the latest solidity compiler version

```javascript
pragma solidity ^0.8.34;
```

___

### [I-2] Documentation Error in `getPassword`, Incorrect Natspec confuses the devs and auditors 

**Description::**
The natspec comment in the `getPassword` indicates that there is a param `newPassword`
```javascript
    /*
     * @notice This allows only the owner to retrieve the password.
     * @param newPassword The new password to set.
     */
    // @AUDIT-Minor:: Wrong documentation. It says "param newPassword" but the function does not take any parameters. This is a minor issue but should be fixed for clarity.
    function getPassword() external view returns (string memory) {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        return s_password;
    }
```

**Impact::**
Wrong documentation will confuse the auditors and devs, if someone "acts" on that incorrect documentation and adds a param `newPassword` it will cause build and deployment errors

**Proof of Concept::**
Add param `newPassword` in the smart contract and all tests will break

**Recommended Solution::**
Remove the incorrect natspec line
```diff
-   * @param newPassword The new password to set.
```