// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/** 
 * @title A sample Raffle contract
 * @author Vitor Jaguat
 * @notice This contract creates a sample raffle
 * @dev Implements Chainlink VRFv2.5 and Chainlink Automation
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /** Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /** Type declarations */
    enum RaffleState {
        OPEN,           // 0
        CALCULATING     // 1
    }

    /** State variables (storage) */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    /** @dev The duration of the lottery in seconds */
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players; // an array of payable addresses
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    /** Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, 'Not enough ETH sent.');
        if (msg.value < i_entranceFee) revert Raffle__SendMoreToEnterRaffle();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH (has players)
     * 4. Implicitly, your subscription has LINK
     * @param - ignored for this use case
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored for this use case
     */
    function checkUpkeep(bytes memory /** checkData */) public view returns (bool upkeepNeeded, bytes memory /** performData */) {
        // check if enough time has passed
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, hex""); // optional line
    }

    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Be automatically called (see checkUpkeep function)
    function performUpkeep(bytes calldata /** performData */) external {
        // check ourselves if enough time has REALLY passed (double security to avoid reentrancy)
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));

        // change raffle state, so people are not able to enter the raffle
        s_raffleState = RaffleState.CALCULATING;

        // Get our random number from Chainlink VRF
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false
                    })
                )
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
      
    }

    /** @dev After Chainlink oracle generates the requested random number and proof for a VRF request, the oracle calls a designated callback function (fullfillRandomWords) on the consuming contract, delivering the results. */
    // CEI: Checks, Effects, Interactions PATTERN
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // CHECKS
        // requires, conditionals

        // EFFECTS (Internal contract state changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        // change the raffle state, so that people can enter the raffle
        s_raffleState = RaffleState.OPEN;

        // update other state variables
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // INTERACTIONS (External contract interactions)
        (bool success, ) = recentWinner.call{ value: address(this).balance }("");
        if (!success) revert Raffle__TransferFailed();

    }

    /** Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}