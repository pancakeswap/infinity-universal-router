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
    IVault vault = IVault(0x2CdB3EC82EE13d341Dc6E73637BE0Eab79cb79dD);
    ICLPoolManager clPoolManager = ICLPoolManager(0x36A12c70c9Cf64f24E89ee132BF93Df2DCD199d4);
    IBinPoolManager binPoolManager = IBinPoolManager(0xe71d2e0230cE0765be53A8A1ee05bdACF30F296B);
    IAllowanceTransfer permit2 = IAllowanceTransfer(0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        QaSwapRouter router = new QaSwapRouter(vault, clPoolManager, binPoolManager, permit2);
        console2.log("QaSwapRouter :", address(router));

        vm.stopBroadcast();
    }
}
