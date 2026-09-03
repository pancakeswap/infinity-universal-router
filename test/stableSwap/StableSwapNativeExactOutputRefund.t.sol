// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";
import {IStableSwapFactory} from "../../src/interfaces/IStableSwapFactory.sol";
import {IStableSwapInfo} from "../../src/interfaces/IStableSwapInfo.sol";

/// @dev Regression test for the stable exact-output overswap.
/// The stable router used to swap its entire input balance instead of the quoted `amountIn`, so the
/// official native-input exact-output flow (WRAP_ETH(max) -> STABLE_SWAP_EXACT_OUT -> UNWRAP_WETH)
/// consumed the user's full `amountInMaximum`, returned no native change, and left the surplus
/// output on the router where anyone could take it with SWEEP.
contract StableSwapNativeExactOutputRefundTest is Test {
    ERC20 constant WETH9 = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    ERC20 constant BNBX = ERC20(0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275);
    IPermit2 constant PERMIT2 = IPermit2(0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768);

    /// @dev Same addresses as StableSwapTest: PancakeStableSwapTwoPool factory and info
    IStableSwapFactory constant STABLE_FACTORY = IStableSwapFactory(0x25a55f9f2279A54951133D503490342b50E5cd15);
    IStableSwapInfo constant STABLE_INFO = IStableSwapInfo(0x150c8AbEB487137acCC541925408e73b92F39A50);

    address constant FROM = address(1234);
    address constant ATTACKER = address(0xBEEF);

    uint256 constant BALANCE = 100000 ether;
    uint256 constant AMOUNT_OUT = 1 ether;
    uint256 constant SLIPPAGE_BIPS = 500; // 5% headroom, only ever meant as an upper bound

    UniversalRouter public router;

    function setUp() public {
        // BSC: May-09-2024 03:05:23 AM +UTC, same block as StableSwapTest
        vm.createSelectFork(vm.envString("FORK_URL"), 38560000);

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
            infiBinPoolManager: address(0)
        });
        router = new UniversalRouter(params);

        // pair doesn't exist, revert to keep this test simple without adding to lp etc
        if (STABLE_FACTORY.getPairInfo(address(WETH9), address(BNBX)).swapContract == address(0)) {
            revert("Pair doesn't exist");
        }

        deal(FROM, BALANCE);
    }

    function test_nativeExactOutput_refundsUnusedNativeInput() public {
        uint256 quotedAmountIn = _quoteAmountIn(AMOUNT_OUT);
        uint256 amountInMaximum = (quotedAmountIn * (10_000 + SLIPPAGE_BIPS)) / 10_000;
        assertGt(amountInMaximum, quotedAmountIn, "test needs a real slippage buffer");

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.WRAP_ETH)),
            bytes1(uint8(Commands.STABLE_SWAP_EXACT_OUT)),
            bytes1(uint8(Commands.UNWRAP_WETH))
        );

        address[] memory path = new address[](2);
        path[0] = address(WETH9);
        path[1] = address(BNBX);

        uint256[] memory flag = new uint256[](1);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(ActionConstants.ADDRESS_THIS, amountInMaximum);
        // (recipient, amountOut, amountInMaximum, path, flag, payerIsUser)
        inputs[1] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT_OUT, amountInMaximum, path, flag, false);
        inputs[2] = abi.encode(ActionConstants.MSG_SENDER, 0);

        uint256 nativeBefore = FROM.balance;
        uint256 outputBefore = BNBX.balanceOf(FROM);

        vm.prank(FROM);
        router.execute{value: amountInMaximum}(commands, inputs);

        assertEq(BNBX.balanceOf(FROM) - outputBefore, AMOUNT_OUT, "user receives exactly the requested output");

        // the fix: only the quoted input is consumed, the untouched headroom is unwrapped back
        assertEq(nativeBefore - FROM.balance, quotedAmountIn, "only the quoted input is spent");
        assertEq(WETH9.balanceOf(address(router)), 0, "no wrapped input stranded on the router");

        // the overswapped output that used to be stranded is gone; only get_dx rounding dust is left
        assertLt(BNBX.balanceOf(address(router)), AMOUNT_OUT / 1000, "no overswapped output residue");

        // and therefore a public SWEEP no longer collects the user's slippage headroom
        bytes memory sweepCommands = abi.encodePacked(bytes1(uint8(Commands.SWEEP)));
        bytes[] memory sweepInputs = new bytes[](1);
        sweepInputs[0] = abi.encode(address(BNBX), ATTACKER, 0);

        vm.prank(ATTACKER);
        router.execute(sweepCommands, sweepInputs);

        assertLt(BNBX.balanceOf(ATTACKER), AMOUNT_OUT / 1000, "attacker cannot steal overswapped output");
    }

    function _quoteAmountIn(uint256 amountOut) internal view returns (uint256 amountIn) {
        IStableSwapFactory.StableSwapPairInfo memory info = STABLE_FACTORY.getPairInfo(address(WETH9), address(BNBX));

        uint256 i = address(WETH9) == info.token0 ? 0 : 1;
        uint256 j = i == 0 ? 1 : 0;
        amountIn = STABLE_INFO.get_dx(info.swapContract, i, j, amountOut, type(uint256).max);
    }
}
