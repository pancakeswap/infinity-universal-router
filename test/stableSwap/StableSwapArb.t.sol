// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";
import {IStableSwapFactory} from "../../src/interfaces/IStableSwapFactory.sol";
import {IStableSwapInfo} from "../../src/interfaces/IStableSwapInfo.sol";

/// @dev test stableSwap on arbitrum
contract StableSwapArbTest is Test {
    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100000 ether;
    ERC20 constant WETH9 = ERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IPermit2 constant PERMIT2 = IPermit2(0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768);
    address constant FROM = address(1234);

    /// @dev StableInfo refers to PancakeStableSwapTwoPoolInfo, threePoolInfo is not present as its not used in PCS
    IStableSwapFactory STABLE_FACTORY = IStableSwapFactory(0x5D5fBB19572c4A89846198c3DBEdB2B6eF58a77a);
    IStableSwapInfo STABLE_INFO = IStableSwapInfo(0x58B2F00f74a1877510Ec37b22f116Bf5D63Ab1b0);

    UniversalRouter public router;

    address public PENDLE = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
    address public mPENDLE = 0xB688BA096b7Bb75d7841e47163Cd12D18B36A5bF;

    function setUp() public {
        // Arb: Jun-18-2025 08:50:07 AM +UTC
        vm.createSelectFork(vm.envString("ARB_FORK_URL"), 348588274);

        RouterParameters memory params = RouterParameters({
            permit2: address(PERMIT2),
            weth9: address(WETH9),
            v2Factory: address(0),
            v3Factory: address(0),
            v3Deployer: address(0),
            v2InitCodeHash: bytes32(0),
            v3InitCodeHash: bytes32(0),
            stableFactory: address(STABLE_FACTORY),
            stableInfo: address(STABLE_INFO),
            infiVault: address(0),
            infiClPoolManager: address(0),
            infiBinPoolManager: address(0),
            v3NFTPositionManager: address(0),
            infiClPositionManager: address(0),
            infiBinPositionManager: address(0)
        });
        router = new UniversalRouter(params);

        // pair doesn't exist, revert to keep this test simple without adding to lp etc
        // Pendle-mPendle: https://arbiscan.io/address/0x73ed25e04Aa673ddf7411441098fC5ae19976CE0
        if (STABLE_FACTORY.getPairInfo(PENDLE, mPENDLE).swapContract == address(0)) {
            revert("Pair doesn't exist");
        }

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(PENDLE, FROM, BALANCE);
        deal(mPENDLE, FROM, BALANCE);
        ERC20(PENDLE).approve(address(PERMIT2), type(uint256).max);
        ERC20(mPENDLE).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(PENDLE, address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(mPENDLE, address(router), type(uint160).max, type(uint48).max);
    }

    function test_stableSwap_ExactInput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], uint256[], bool)
        address[] memory path = new address[](2);
        path[0] = PENDLE;
        path[1] = mPENDLE;
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, flag(), true);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput0For1");
        assertEq(ERC20(PENDLE).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(mPENDLE).balanceOf(FROM), BALANCE);
    }

    function test_stableSwap_ExactInput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], uint256[], bool)
        address[] memory path = new address[](2);
        path[0] = mPENDLE;
        path[1] = PENDLE;
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, flag(), true);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput1For0");
        assertEq(ERC20(mPENDLE).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(PENDLE).balanceOf(FROM), BALANCE);
    }

    function test_stableSwap_exactInput0For1FromRouter_Arb() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));
        deal(PENDLE, address(router), AMOUNT);
        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], uint256[], bool)
        address[] memory path = new address[](2);
        path[0] = PENDLE;
        path[1] = mPENDLE;
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, flag(), false);

        router.execute(commands, inputs);
        assertEq(ERC20(PENDLE).balanceOf(FROM), BALANCE); // no token0 taken from user, taken from router
        assertGt(ERC20(mPENDLE).balanceOf(FROM), BALANCE); // token1 received
    }

    function flag() internal pure returns (uint256[] memory pairFlag) {
        pairFlag = new uint256[](1);
        pairFlag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool
    }
}
