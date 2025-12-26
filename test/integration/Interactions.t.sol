// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {console} from "forge-std/console.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract InteractionsTest is Test, CodeConstants {
    HelperConfig public config;
    Raffle public raffle;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, config) = deployer.run();
    }

    function testInteractions() public {
        // Arrange
        uint256 numOfPlayers = 5;
        uint256 startingPlayerBalance = 10 ether;
        uint256 entranceFee = config.getConfig().entranceFee;

        // Add players
        for (uint256 i = 0; i < numOfPlayers; i++) {
            address player = address(uint160(i));
            hoax(player, startingPlayerBalance);
            raffle.enterRaffle{value: entranceFee}();
            console.log("Entrance Fee for player ", i, " is ", entranceFee);
        }

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        console.log("Upkeep Needed: ", upkeepNeeded);
        console.log("Raffle State: ", uint256(raffleState));

        // Fast forward time
        vm.warp(block.timestamp + config.getConfig().interval + 1);
        vm.roll(block.number + 1);

        (upkeepNeeded, ) = raffle.checkUpkeep("");

        console.log("Upkeep Needed after Interval: ", upkeepNeeded);

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");

        raffleState = raffle.getRaffleState();
        console.log("Raffle State after performUpkeep: ", uint256(raffleState));

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(config.getConfig().vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        raffleState = raffle.getRaffleState();
        console.log("Raffle State after fulfillRandomWords: ", uint256(raffleState));

        address recentWinner = raffle.getRecentWinner();

        console.log("Recent Winner: ", recentWinner);

        // Assert
        assertTrue(address(raffle) != address(0));
        assertTrue(address(config) != address(0));
        assertTrue(upkeepNeeded);
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN));
        assertEq(recentWinner, address(1));
        assertEq(recentWinner.balance, startingPlayerBalance + entranceFee * numOfPlayers - entranceFee);
    }
}
