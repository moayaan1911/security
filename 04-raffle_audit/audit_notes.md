# Project
A raffle contract, users can enter to win a puppy NFT, duplicate addresses not allowed and contract takes a fee cut. winners decided randomly after X seconds and users can exit and claim refund using refund function.

# Findings
- the code structure is so bad.. no _variable in params and no i_variable in immutable, a noob wrote it
- solidity version is VERY old!
- DOS ATTACK FOUND in loop
- RE ENTRANCY ATTACK found in the refund function
- return 0 as player index with player is inactive in the getActivePlayerIndex function
- there is raffle duration and raffle starttime being set in constructor
- WEAK RANDOMNESS EXPLOIT caught in the selectWinner function
- question in the % of the winner and fee, 80% and 20% int eh selectfinnwer function.
- found the arithmatic overflow in the same function.
- found unsafe casting in same function(selectWinner)

- found many Is and Qs which will verify with the team later tagged them all as // @AUDIT-q
- Found HIGH bug MISHANDLING OF ETH in the withdrawFees check
- found an unused function _isActivePlayer & a loop inside that which should be mapping
- found an informational improvement in the tokenURI function
- found another WEAK RANDOMNESS exploit in the selectWinner function