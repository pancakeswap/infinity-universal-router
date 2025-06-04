// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";
import {IStableSwapFactory} from "../../src/interfaces/IStableSwapFactory.sol";
import {IStableSwapInfo} from "../../src/interfaces/IStableSwapInfo.sol";
import {StableSwapRouter} from "../../src/modules/pancakeswap/StableSwapRouter.sol";

contract StableSwapMultiHop is Test {
    ERC20 constant USDC = ERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    ERC20 constant BUSD = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    ERC20 constant USDT = ERC20(0x55d398326f99059fF775485246999027B3197955);

    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100000 ether;
    ERC20 constant WETH9 = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPermit2 constant PERMIT2 = IPermit2(0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768);
    address constant FROM = address(1234);

    /// @dev Address found from smart router via https://bscscan.com/address/0x13f4EA83D0bd40E75C8222255bc855a974568Dd4#readContract
    /// @dev StableInfo refers to PancakeStableSwapTwoPoolInfo, threePoolInfo is not present as its not used in PCS
    IStableSwapFactory STABLE_FACTORY = IStableSwapFactory(0x25a55f9f2279A54951133D503490342b50E5cd15);
    IStableSwapInfo STABLE_INFO = IStableSwapInfo(0x150c8AbEB487137acCC541925408e73b92F39A50);

    UniversalRouter public router;

    function setUp() public {
        // BSC: Jun-04-2025 01:23:02 AM +UTC)
        vm.createSelectFork(vm.envString("FORK_URL"), 50837520);

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

        // verify USDC<>USDT pair and USDT<>BUSD pair exist
        if (STABLE_FACTORY.getPairInfo(address(USDC), address(USDT)).swapContract == address(0)) {
            revert("Pair doesn't exist");
        }
        if (STABLE_FACTORY.getPairInfo(address(USDT), address(BUSD)).swapContract == address(0)) {
            revert("Pair doesn't exist");
        }

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(address(USDC), FROM, BALANCE);
        deal(address(BUSD), FROM, BALANCE);
        deal(address(USDT), FROM, BALANCE);
        ERC20(address(USDC)).approve(address(PERMIT2), type(uint256).max);
        ERC20(address(BUSD)).approve(address(PERMIT2), type(uint256).max);
        ERC20(address(USDT)).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(address(USDC), address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(address(BUSD), address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(address(USDT), address(router), type(uint160).max, type(uint48).max);
    }

    /// do a multi-hop swap from USDC -> USDT -> BUSD and assume balance in contract
    function test_stableSwap_ExactInput0For1_MultiHop_FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        deal(address(USDC), address(router), AMOUNT);

        uint256[] memory flag = new uint256[](2);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool
        flag[1] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(USDT);
        path[2] = address(BUSD);

        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], uint256[], bool)
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, flag, false);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput0For1_MultiHop_FromRouter");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), BALANCE); // no token0 taken from user, taken from router
        assertGt(ERC20(address(BUSD)).balanceOf(FROM), BALANCE); // token1 received.
        assertEq(ERC20(address(BUSD)).balanceOf(FROM), 100000999768181033551138); // roughly 0.999768181 recieved from swap
    }

    function test_stableSwap_ExactInput0For1_MultiHop_FromUser() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        uint256[] memory flag = new uint256[](2);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool
        flag[1] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(USDT);
        path[2] = address(BUSD);

        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], uint256[], bool)
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, flag, true);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput0For1_MultiHop_FromUser");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(ERC20(address(BUSD)).balanceOf(FROM), 100000999768181033551138); // roughly 0.999768181 recieved from swap
    }

    function test_stableSwap_ExactInput0For1_DualAction_FromRouter() public {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)), bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        deal(address(USDC), address(router), AMOUNT);

        uint256[] memory flag = new uint256[](1);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path1 = new address[](2);
        path1[0] = address(USDC);
        path1[1] = address(USDT);
        address[] memory path2 = new address[](2);
        path2[0] = address(USDT);
        path2[1] = address(BUSD);

        bytes[] memory inputs = new bytes[](2);
        // first hop output to universal router
        inputs[0] = abi.encode(ActionConstants.ADDRESS_THIS, AMOUNT, 0, path1, flag, false);
        inputs[1] = abi.encode(ActionConstants.MSG_SENDER, ActionConstants.CONTRACT_BALANCE, 0, path2, flag, false);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput0For1_DualAction_FromRouter");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), BALANCE); // no token0 taken from user, taken from router
        assertGt(ERC20(address(BUSD)).balanceOf(FROM), BALANCE); // token1 received. roughly 0.999768181
        assertEq(ERC20(address(BUSD)).balanceOf(FROM), 100000999768181033551138); // roughly 0.999768181 recieved from swap
    }

    function test_stableSwap_ExactInput0For1_DualAction_FromUser() public {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)), bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        uint256[] memory flag = new uint256[](1);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path1 = new address[](2);
        path1[0] = address(USDC);
        path1[1] = address(USDT);
        address[] memory path2 = new address[](2);
        path2[0] = address(USDT);
        path2[1] = address(BUSD);

        bytes[] memory inputs = new bytes[](2);
        // first hop output to universal router
        inputs[0] = abi.encode(ActionConstants.ADDRESS_THIS, AMOUNT, 0, path1, flag, true);
        inputs[1] = abi.encode(ActionConstants.MSG_SENDER, ActionConstants.CONTRACT_BALANCE, 0, path2, flag, false);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput0For1_DualAction_FromUser");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(ERC20(address(BUSD)).balanceOf(FROM), 100000999768181033551138); // roughly 0.999768181 recieved from swap
    }

    function test_stableSwap_ExactInput0For1_SamePath_FromRouter() public {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)), bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        deal(address(USDC), address(router), AMOUNT * 4);

        uint256[] memory flag = new uint256[](1);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(USDT);

        bytes[] memory inputs = new bytes[](2);
        // first hop output to universal router
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, flag, false);
        inputs[1] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT * 3, 0, path, flag, false);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput0For1_SamePath_FromRouter");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), BALANCE); // no token0 taken from user, taken from router
        assertEq(ERC20(address(USDT)).balanceOf(FROM), 100003996633124466009871); // roughly 3.9966331244 recieved from swap
    }

    function test_stableSwap_ExactInput0For1_SamePath_FromUser() public {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)), bytes1(uint8(Commands.STABLE_SWAP_EXACT_IN)));

        uint256[] memory flag = new uint256[](1);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(USDT);

        bytes[] memory inputs = new bytes[](2);
        // first hop output to universal router
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, flag, true);
        inputs[1] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT * 3, 0, path, flag, true);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactInput0For1_SamePath_FromUser");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), BALANCE - (AMOUNT * 4));
        assertEq(ERC20(address(USDT)).balanceOf(FROM), 100003996633124466009871); // roughly 3.9966331244 recieved from swap
    }

    function test_stableSwap_ExactOutput0For1_SamePath_FromRouter() public {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_OUT)), bytes1(uint8(Commands.STABLE_SWAP_EXACT_OUT)));

        uint256 AMOUNT_IN = 1 ether;
        deal(address(USDC), address(router), AMOUNT_IN * 4);

        uint256[] memory flag = new uint256[](1);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(USDT);

        bytes[] memory inputs = new bytes[](2);
        // (recipient, amountOut, amountInMax, path, flag, payerIsUser)
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, 0.9 ether, AMOUNT_IN, path, flag, false);
        inputs[1] = abi.encode(ActionConstants.MSG_SENDER, 0.9 ether * 3, AMOUNT_IN * 3, path, flag, false);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactOutput0For1_SamePath_FromRouter");
        assertEq(ERC20(address(USDT)).balanceOf(FROM), 100003600000000000000000); // exactly 3.6 usdt received 
    }

    function test_stableSwap_ExactOutput0For1_MultiHop_FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_OUT)));

        uint256 AMOUNT_IN = 1 ether;
        deal(address(USDC), address(router), AMOUNT_IN);

        uint256[] memory flag = new uint256[](2);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool
        flag[1] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(USDT);
        path[2] = address(BUSD);

        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], uint256[], bool)
        bytes[] memory inputs = new bytes[](1);
        // (recipient, amountOut, amountInMax, path, flag, payerIsUser)
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, 0.9 ether, AMOUNT_IN, path, flag, false);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactOutput0For1_MultiHop_FromRouter");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), BALANCE); // no token0 taken from user, taken from router
        assertEq(ERC20(address(USDC)).balanceOf(address(router)), 99791314908871029); // roughly 0.9 usdc taken from router, leaving 0.1 left
        assertEq(ERC20(address(BUSD)).balanceOf(FROM), 100000900000000000000000); // exactly 0.9 busd received
    }

    function test_stableSwap_ExactOut0For1_MultiHop_FromUser() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.STABLE_SWAP_EXACT_OUT)));

        uint256 AMOUNT_IN = 1 ether;

        uint256[] memory flag = new uint256[](2);
        flag[0] = 2; // 2 is the flag to indicate StableSwapTwoPool
        flag[1] = 2; // 2 is the flag to indicate StableSwapTwoPool

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(USDT);
        path[2] = address(BUSD);

        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], uint256[], bool)
        bytes[] memory inputs = new bytes[](1);
        // (recipient, amountOut, amountInMax, path, flag, payerIsUser)
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER,0.9 ether, AMOUNT_IN, path, flag, true);

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_stableSwap_ExactOut0For1_MultiHop_FromUser");
        assertEq(ERC20(address(USDC)).balanceOf(FROM), 99999099791314908871029); // roughly 0.9 usdc taken from user 
        assertEq(ERC20(address(BUSD)).balanceOf(FROM), 100000900000000000000000); // exactly 0.9 busd received
    }
}
