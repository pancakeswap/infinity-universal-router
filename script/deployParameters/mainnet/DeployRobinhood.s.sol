// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {DeployUniversalRouter} from "../../DeployUniversalRouter.s.sol";
import {RouterParameters} from "../../../src/base/RouterImmutables.sol";

/**
 * Step 1: Deploy
 * forge script script/deployParameters/mainnet/DeployRobinhood.s.sol:DeployRobinhood -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployRobinhood is DeployUniversalRouter {
    /// @notice contract address will be based on deployment salt
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("INFINITY-UNIVERSAL-ROUTER/UniversalRouter/1.0.0");
    }

    function setUp() public override {
        params = RouterParameters({
            permit2: 0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768,
            weth9: 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73,
            v2Factory: 0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E,
            v3Factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,
            v3Deployer: 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
            v2InitCodeHash: 0x57224589c67f3f30a6b0d7a1b54cf3153ab84563bc609ef41dfb34f8b2974d2d,
            v3InitCodeHash: 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2,
            stableFactory: UNSUPPORTED_PROTOCOL,
            stableInfo: UNSUPPORTED_PROTOCOL,
            infiVault: 0x4F922d5B15e6691e0469663E4F5C4177f23c5FaF,
            infiClPoolManager: 0xeE04c68742e6Bf434bE8039580D2e89BBE55bc6f,
            infiBinPoolManager: 0x6262B1041596fCeD3Ea7D87C135B0b602Ed05013
        });

        unsupported = 0xD6b5036d85C3E72d24C73eDD54eb9DCB2698C692;
    }
}
