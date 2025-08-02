// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    /** Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    modifier prank() {
        vm.prank(PLAYER);
        _;
    }

// ---- enter raffle ---------------------------------------------------------------------
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);
        

        // Act
        raffle.enterRaffle{ value: entranceFee }();

        // Assert
        address playerRecorder = raffle.getPlayer(0);
        assertEq(playerRecorder, PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        // vm.expectEmit(hasTopic1, hasTopic2, hasTopic3, hasData, emitterAddress);
        // MUST copy/past the events into the test contract! (see above)
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{ value: entranceFee } ();
        // the 2 events emitted by the 2 lines above should be equal, and the arguments (topics, data) too! otherwise, the test won't pass.
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();
        // instead of waiting 30s, we can simulate that the time passed using vm.warp(time)
        vm.warp(block.timestamp + interval + 1);
        // we can also simulate that the block number changed:
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();
    }

// ---- checkUpkeep function -------------------------------------------------------------

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange 
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); // not calling enterRaffle before -> balance = 0 -> upkeep not needed

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepIfRaffleIsNotOpen() public {
        // Arrange (same as testDontAllowPlayersToEnterWhileRaffleIsCalculating)
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);

    }
}
