// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Chapter2Guard} from "../src/Chapter2Guard.sol";
import {MockSafe} from "../src/mocks/MockSafe.sol";

contract DeployChapter2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0xA11CE));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MockSafe safe = new MockSafe(deployer);

        uint256 maxAutonomous = 100 * 1e6;
        uint256 dailyLimit = 500 * 1e6;
        address autonomousAgent = vm.envOr("AGENT_ADDRESS", address(uint160(0xB0B0b0B0B0B0B0b0B0B0B0b0b0b0b0B0b0b0B0B0)));
        address ledgerSigner = vm.envOr("LEDGER_SIGNER_ADDRESS", deployer);

        Chapter2Guard guard = new Chapter2Guard(
            deployer,
            address(safe),
            autonomousAgent,
            ledgerSigner,
            maxAutonomous,
            dailyLimit
        );

        safe.setGuard(address(guard));

        address alchemy = address(uint160(0x41C4E));
        address cloudflare = address(uint160(0xCF));
        guard.setApprovedRecipient(alchemy, true);
        guard.setApprovedRecipient(cloudflare, true);

        vm.stopBroadcast();

        console.log("Safe deployed at:", address(safe));
        console.log("Chapter2Guard deployed at:", address(guard));
    }
}
