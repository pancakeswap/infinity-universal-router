// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IStableSwapFactory} from "../../src/interfaces/IStableSwapFactory.sol";

/// @dev Minimal two-coin stable pool. The rate it actually executes at is set independently from the
/// rate MockStableSwapInfo quotes, so a test can make the pool deliver less (or more) than the quote
/// promised. Real PancakeStableSwap pools quote exactly, which is why these cases need a mock.
contract MockStableSwapPool {
    address public immutable tokenA;
    address public immutable tokenB;

    /// @dev output per unit of input, 1e18 == 1:1
    uint256 public rate;

    /// @dev recorded so a test can assert what the router actually handed to the pool
    uint256 public lastDx;
    uint256 public lastDy;
    uint256 public exchangeCount;

    constructor(address _tokenA, address _tokenB, uint256 _rate) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        rate = _rate;
    }

    function setRate(uint256 _rate) external {
        rate = _rate;
    }

    function coins(uint256 i) external view returns (address) {
        return i == 0 ? tokenA : tokenB;
    }

    function exchange(uint256 i, uint256 j, uint256 dx, uint256 minDy) external payable {
        address input = i == 0 ? tokenA : tokenB;
        address output = j == 0 ? tokenA : tokenB;

        uint256 dy = (dx * rate) / 1e18;
        require(dy >= minDy, "MockStableSwapPool: minDy");

        ERC20(input).transferFrom(msg.sender, address(this), dx);
        ERC20(output).transfer(msg.sender, dy);

        lastDx = dx;
        lastDy = dy;
        exchangeCount++;
    }
}

/// @dev Quotes the input needed for a requested output. Deliberately independent of the pool's rate.
contract MockStableSwapInfo {
    /// @dev output per unit of input the quote assumes, 1e18 == 1:1
    mapping(address => uint256) public quoteRate;

    function setQuoteRate(address pool, uint256 _quoteRate) external {
        quoteRate[pool] = _quoteRate;
    }

    // solium-disable-next-line mixedcase
    function get_dx(address _swap, uint256, uint256, uint256 dy, uint256) external view returns (uint256) {
        return (dy * 1e18) / quoteRate[_swap];
    }
}

/// @dev Only getPairInfo is implemented: that is all UniversalRouterHelper.getStableInfo calls for
/// flag == 2, and duck typing at the call site means we do not need the rest of the interface.
contract MockStableSwapFactory {
    mapping(address => mapping(address => IStableSwapFactory.StableSwapPairInfo)) internal _pairInfo;

    function setPair(address tokenA, address tokenB, address swapContract) external {
        IStableSwapFactory.StableSwapPairInfo memory info = IStableSwapFactory.StableSwapPairInfo({
            swapContract: swapContract, token0: tokenA, token1: tokenB, LPContract: address(0)
        });
        _pairInfo[tokenA][tokenB] = info;
        _pairInfo[tokenB][tokenA] = info;
    }

    function getPairInfo(address tokenA, address tokenB)
        external
        view
        returns (IStableSwapFactory.StableSwapPairInfo memory info)
    {
        info = _pairInfo[tokenA][tokenB];
    }
}
