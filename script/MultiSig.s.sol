// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract MultiSigScript is Script {
    function run() public {
        // Number of owners to load
        uint256 numOwners = vm.envUint("NUM_OWNERS");

        address[] memory owners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            string memory key = string(abi.encodePacked("OWNER_", vm.toString(i)));
            owners[i] = vm.envAddress(key);
        }

        uint256 required = vm.envUint("REQUIRED");

        vm.startBroadcast();
        console.log("Deploying MultiSig contract...");
        MultiSig multiSig = new MultiSig(owners, required);
        console.log("MultiSig deployed at:", address(multiSig));
        vm.stopBroadcast();
    }
}
