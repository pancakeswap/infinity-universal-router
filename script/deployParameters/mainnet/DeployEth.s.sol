// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {DeployUniversalRouter} from "../../DeployUniversalRouter.s.sol";
import {RouterParameters} from "../../../src/base/RouterImmutables.sol";

/**
 * Step 1: Deploy
 * forge script script/deployParameters/mainnet/DeployEth.s.sol:DeployEth -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployEth is DeployUniversalRouter {
    /// @notice contract address will be based on deployment salt
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("INFINITY-UNIVERSAL-ROUTER/UniversalRouter/0.0001");
    }

    function setUp() public override {
        params = RouterParameters({
            permit2: 0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768,
            weth9: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            v2Factory: 0x1097053Fd2ea711dad45caCcc45EfF7548fCB362,
            v3Factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,
            v3Deployer: 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
            v2InitCodeHash: 0x57224589c67f3f30a6b0d7a1b54cf3153ab84563bc609ef41dfb34f8b2974d2d,
            v3InitCodeHash: 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2,
            stableFactory: UNSUPPORTED_PROTOCOL,
            stableInfo: UNSUPPORTED_PROTOCOL,
            infiVault: UNSUPPORTED_PROTOCOL,
            infiClPoolManager: UNSUPPORTED_PROTOCOL,
            infiBinPoolManager: UNSUPPORTED_PROTOCOL,
            v3NFTPositionManager: UNSUPPORTED_PROTOCOL,
            infiClPositionManager: UNSUPPORTED_PROTOCOL,
            infiBinPositionManager: UNSUPPORTED_PROTOCOL
        });

        unsupported = 0x5C19Add791a23C55be09fAB1db73bFd5fa80C2b0;
    }
}
