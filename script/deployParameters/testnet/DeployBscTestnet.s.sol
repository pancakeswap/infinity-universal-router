// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from "../../DeployUniversalRouter.s.sol";
import {RouterParameters} from "../../../src/base/RouterImmutables.sol";

/**
 * Step 1: Deploy
 * forge script script/deployParameters/testnet/DeployBscTestnet.s.sol:DeployBscTestnet -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployBscTestnet is DeployUniversalRouter {
    /// @notice contract address will be based on deployment salt
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("INFINITY-UNIVERSAL-ROUTER/UniversalRouter/0.97");
    }

    // ref from v3 universal router: https://testnet.bscscan.com/tx/0xdfab014e4f5df56d5a8b16375028ad0340f80070bd848eb57c4e0baf41210487
    function setUp() public override {
        params = RouterParameters({
            permit2: 0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768,
            weth9: 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd,
            v2Factory: 0x6725F303b657a9451d8BA641348b6761A6CC7a17,
            v3Factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,
            v3Deployer: 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
            v2InitCodeHash: 0xd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66,
            v3InitCodeHash: 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2,
            stableFactory: 0xe6A00f8b819244e8Ab9Ea930e46449C2F20B6609,
            stableInfo: 0x0A548d59D04096Bc01206D58C3D63c478e1e06dB,
            infiVault: 0x2CdB3EC82EE13d341Dc6E73637BE0Eab79cb79dD,
            infiClPoolManager: 0x36A12c70c9Cf64f24E89ee132BF93Df2DCD199d4,
            infiBinPoolManager: 0xe71d2e0230cE0765be53A8A1ee05bdACF30F296B,
            v3NFTPositionManager: 0x427bF5b37357632377eCbEC9de3626C71A5396c1,
            infiClPositionManager: 0x77DedB52EC6260daC4011313DBEE09616d30d122,
            infiBinPositionManager: 0x68B834232da911c787bcF782CED84ec5d36909a7
        });

        unsupported = 0xe4da88F38C11C1450c720b8aDeDd94956610a4e5;
    }
}
