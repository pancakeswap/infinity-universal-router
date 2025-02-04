// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IBinPoolManager} from "infinity-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

import {QaSwapRouter} from "../src/QaSwapRouter.sol";

/**
 * Step 1: Deploy
 * forge script script/02_DeployQaSwapRouter.s.sol:DeployQaSwapRouter -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployQaSwapRouter is Script {
    // ref: https://github.com/pancakeswap/infinity-periphery/blob/main/script/config/bsc-testnet.json
    // WIP pending release 
    IVault vault = IVault(0x000000000000000000000000000000000000dEaD);
    ICLPoolManager clPoolManager = ICLPoolManager(0x000000000000000000000000000000000000dEaD);
    IBinPoolManager binPoolManager = IBinPoolManager(0x000000000000000000000000000000000000dEaD);
    IAllowanceTransfer permit2 = IAllowanceTransfer(0x000000000000000000000000000000000000dEaD);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        QaSwapRouter router = new QaSwapRouter(vault, clPoolManager, binPoolManager, permit2);
        console2.log("QaSwapRouter :", address(router));

        vm.stopBroadcast();
    }
}