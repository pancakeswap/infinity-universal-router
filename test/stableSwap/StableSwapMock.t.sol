// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";

import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";
import {StableSwapRouter} from "../../src/modules/pancakeswap/StableSwapRouter.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockStableSwapFactory, MockStableSwapInfo, MockStableSwapPool} from "../mock/MockStableSwap.sol";

/// @dev Local, non-fork coverage for the invariants that a real PancakeStableSwap pool cannot
/// exercise. On the real pools `get_dx` quotes exactly, so the forward swap always returns exactly
/// the requested output and the quote/execution mismatch cases are unreachable on a fork.
/// The mock pool's execution rate is set independently from the quoted rate, which lets us drive
/// the pool above and below the quote on demand.
///
/// Every test uses payerIsUser = false, so the swap input comes from the router's own balance and no
/// Permit2 deployment is needed.
contract StableSwapMockTest is Test {
    uint256 constant SWAP_AMOUNT = 100 ether;
    uint256 constant DONATION = 900 ether;
    uint256 constant POOL_LIQUIDITY = 1_000_000 ether;

    address constant RECIPIENT = address(0xA11CE);

    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;

    MockStableSwapFactory factory;
    MockStableSwapInfo info;
    MockStableSwapPool poolAB;
    MockStableSwapPool poolBC;

    UniversalRouter public router;

    function setUp() public {
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        tokenC = new MockERC20();

        factory = new MockStableSwapFactory();
        info = new MockStableSwapInfo();

        // both pools execute 1:1 and are quoted 1:1 by default; individual tests move the rates
        poolAB = new MockStableSwapPool(address(tokenA), address(tokenB), 1e18);
        poolBC = new MockStableSwapPool(address(tokenB), address(tokenC), 1e18);

        factory.setPair(address(tokenA), address(tokenB), address(poolAB));
        factory.setPair(address(tokenB), address(tokenC), address(poolBC));
        info.setQuoteRate(address(poolAB), 1e18);
        info.setQuoteRate(address(poolBC), 1e18);

        tokenB.mint(address(poolAB), POOL_LIQUIDITY);
        tokenA.mint(address(poolAB), POOL_LIQUIDITY);
        tokenC.mint(address(poolBC), POOL_LIQUIDITY);
        tokenB.mint(address(poolBC), POOL_LIQUIDITY);

        RouterParameters memory params = RouterParameters({
            permit2: address(0),
            weth9: address(0),
            v2Factory: address(0),
            v3Factory: address(0),
            v3Deployer: address(0),
            v2InitCodeHash: bytes32(0),
            v3InitCodeHash: bytes32(0),
            stableFactory: address(factory),
            stableInfo: address(info),
            infiVault: address(0),
            infiClPoolManager: address(0),
            infiBinPoolManager: address(0)
        });
        router = new UniversalRouter(params);
    }

    /*//////////////////////////////////////////////////////////////
                    exact output: amtOut vs amountOut
    //////////////////////////////////////////////////////////////*/

    /// @dev The quote promises 1:1 but the pool only delivers 0.9:1. Without the output check the
    /// router would still pay the recipient the full requested amountOut, covering the shortfall out
    /// of whatever else it happened to hold.
    function test_stableSwap_ExactOutput_RevertWhenPoolDeliversLessThanAmountOut() public {
        poolAB.setRate(0.9e18);
        tokenA.mint(address(router), SWAP_AMOUNT * 2);
        // give the router output tokens too: pre-fix these would have silently covered the shortfall
        tokenB.mint(address(router), SWAP_AMOUNT);

        vm.expectRevert(StableSwapRouter.StableTooLittleReceived.selector);
        router.execute(_exactOutCommand(), _exactOutInputs(_pathAB(), SWAP_AMOUNT, SWAP_AMOUNT * 2));
    }

    /// @dev The pool delivers 1.1:1 against a 1:1 quote. The surplus must reach the recipient rather
    /// than staying on the router, where the public SWEEP command would make it anyone's.
    function test_stableSwap_ExactOutput_PaysSurplusToRecipient() public {
        poolAB.setRate(1.1e18);
        tokenA.mint(address(router), SWAP_AMOUNT * 2);

        router.execute(_exactOutCommand(), _exactOutInputs(_pathAB(), SWAP_AMOUNT, SWAP_AMOUNT * 2));

        // only the quoted input was swapped, not the router's whole balance
        assertEq(poolAB.lastDx(), SWAP_AMOUNT, "pool received more than the quoted input");
        assertEq(tokenA.balanceOf(address(router)), SWAP_AMOUNT, "unused input should stay untouched");

        // the full 110 reaches the recipient and nothing is retained
        assertEq(tokenB.balanceOf(RECIPIENT), (SWAP_AMOUNT * 11) / 10, "recipient did not get the surplus");
        assertEq(tokenB.balanceOf(address(router)), 0, "surplus left on the router");
    }

    /*//////////////////////////////////////////////////////////////
                      donation cannot inflate amountIn
    //////////////////////////////////////////////////////////////*/

    /// @dev A donation sitting on the router must not be pulled into the swap. Before the router
    /// respected amountIn it used balanceOf, so the donation would have been swapped as well.
    function test_stableSwap_ExactInput_DonationDoesNotInflateAmountIn() public {
        tokenA.mint(address(router), SWAP_AMOUNT + DONATION);

        router.execute(_exactInCommand(), _exactInInputs(_pathAB(), SWAP_AMOUNT, 0));

        assertEq(poolAB.lastDx(), SWAP_AMOUNT, "donation was swapped along with amountIn");
        assertEq(tokenA.balanceOf(address(router)), DONATION, "donation should be untouched");
        assertEq(tokenB.balanceOf(RECIPIENT), SWAP_AMOUNT, "recipient output mismatch");
    }

    /// @dev Same for exact output: only the quoted input may be consumed.
    function test_stableSwap_ExactOutput_DonationDoesNotInflateAmountIn() public {
        tokenA.mint(address(router), SWAP_AMOUNT + DONATION);

        router.execute(_exactOutCommand(), _exactOutInputs(_pathAB(), SWAP_AMOUNT, SWAP_AMOUNT + DONATION));

        assertEq(poolAB.lastDx(), SWAP_AMOUNT, "donation was swapped along with the quoted input");
        assertEq(tokenA.balanceOf(address(router)), DONATION, "donation should be untouched");
        assertEq(tokenB.balanceOf(RECIPIENT), SWAP_AMOUNT, "recipient output mismatch");
    }

    /// @dev The boundary of the rule above: CONTRACT_BALANCE is an explicit request to trade the
    /// router's whole balance, so it does include a donation. That is by design, and harmless -- the
    /// extra input produces extra output for the same recipient.
    function test_stableSwap_ExactInput_ContractBalanceIntentionallyIncludesDonation() public {
        tokenA.mint(address(router), SWAP_AMOUNT + DONATION);

        router.execute(_exactInCommand(), _exactInInputs(_pathAB(), ActionConstants.CONTRACT_BALANCE, 0));

        assertEq(poolAB.lastDx(), SWAP_AMOUNT + DONATION, "CONTRACT_BALANCE should trade everything");
        assertEq(tokenA.balanceOf(address(router)), 0, "CONTRACT_BALANCE should leave nothing");
        assertEq(tokenB.balanceOf(RECIPIENT), SWAP_AMOUNT + DONATION, "recipient output mismatch");
    }

    /// @dev Multi-hop feeds the next hop with the measured delta of the previous hop, not with the
    /// balance of the intermediate token, so a donation of that intermediate token is excluded.
    function test_stableSwap_ExactInput_MultiHopExcludesIntermediateDonation() public {
        tokenA.mint(address(router), SWAP_AMOUNT);
        tokenB.mint(address(router), DONATION); // donation of the intermediate token

        router.execute(_exactInCommand(), _exactInInputs(_pathABC(), SWAP_AMOUNT, 0));

        assertEq(poolAB.lastDx(), SWAP_AMOUNT, "first hop input mismatch");
        // the second hop gets the first hop's actual output only
        assertEq(poolBC.lastDx(), SWAP_AMOUNT, "second hop swallowed the intermediate donation");
        assertEq(tokenB.balanceOf(address(router)), DONATION, "intermediate donation should be untouched");
        assertEq(tokenC.balanceOf(RECIPIENT), SWAP_AMOUNT, "recipient output mismatch");
    }

    /// @dev Multi-hop still carries a favorable hop forward in full: hop 1 over-delivers and hop 2
    /// must receive that larger amount, not the originally quoted one.
    function test_stableSwap_ExactInput_MultiHopCarriesExcessForward() public {
        poolAB.setRate(1.2e18);
        tokenA.mint(address(router), SWAP_AMOUNT);

        router.execute(_exactInCommand(), _exactInInputs(_pathABC(), SWAP_AMOUNT, 0));

        uint256 hop1Out = (SWAP_AMOUNT * 12) / 10;
        assertEq(poolAB.lastDy(), hop1Out, "first hop output mismatch");
        assertEq(poolBC.lastDx(), hop1Out, "excess from the first hop did not carry forward");
        assertEq(tokenC.balanceOf(RECIPIENT), hop1Out, "recipient output mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                                helpers
    //////////////////////////////////////////////////////////////*/

    function _exactInCommand() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));
    }

    function _exactOutCommand() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_OUT)));
    }

    /// @dev (recipient, amountIn, amountOutMinimum, path, flag, payerIsUser)
    function _exactInInputs(address[] memory path, uint256 amountIn, uint256 amountOutMinimum)
        internal
        pure
        returns (bytes[] memory inputs)
    {
        inputs = new bytes[](1);
        inputs[0] = abi.encode(RECIPIENT, amountIn, amountOutMinimum, path, _flag(path.length - 1), false);
    }

    /// @dev (recipient, amountOut, amountInMaximum, path, flag, payerIsUser)
    function _exactOutInputs(address[] memory path, uint256 amountOut, uint256 amountInMaximum)
        internal
        pure
        returns (bytes[] memory inputs)
    {
        inputs = new bytes[](1);
        inputs[0] = abi.encode(RECIPIENT, amountOut, amountInMaximum, path, _flag(path.length - 1), false);
    }

    function _pathAB() internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
    }

    function _pathABC() internal view returns (address[] memory path) {
        path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
    }

    /// @dev flag 2 selects the two-coin pool lookup for every hop
    function _flag(uint256 hops) internal pure returns (uint256[] memory flag) {
        flag = new uint256[](hops);
        for (uint256 i; i < hops; i++) {
            flag[i] = 2;
        }
    }
}
