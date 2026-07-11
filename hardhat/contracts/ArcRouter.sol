// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IArcFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IArcPairRouter {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

interface IERC20Router {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

/// @title ArcRouter
/// @notice Kullanicilarin dogrudan etkilesime girdigi kontrat: likidite ekleme/cikarma
///         ve token takasi (swap) burada gerceklesir. Pair kontratlarini otomatik
///         yonetir; gerekirse yeni pair olusturur.
contract ArcRouter {
    address public immutable factory;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "ArcRouter: EXPIRED");
        _;
    }

    constructor(address _factory) {
        factory = _factory;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _getReserves(address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        address pair = IArcFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "ArcRouter: PAIR_NOT_FOUND");
        (address token0, ) = _sortTokens(tokenA, tokenB);
        (uint112 reserve0, uint112 reserve1, ) = IArcPairRouter(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (uint256(reserve0), uint256(reserve1)) : (uint256(reserve1), uint256(reserve0));
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        require(amountA > 0, "ArcRouter: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "ArcRouter: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "ArcRouter: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "ArcRouter: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "ArcRouter: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /// @notice Bir cift icin havuz yoksa olusturur, varsa mevcut olani kullanir,
    ///         ardindan tokenlari kullaniciya oranli sekilde havuza ekler.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = IArcFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IArcFactory(factory).createPair(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = _getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "ArcRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired, "ArcRouter: EXCESSIVE_A_AMOUNT");
                require(amountAOptimal >= amountAMin, "ArcRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }

        require(IERC20Router(tokenA).transferFrom(msg.sender, pair, amountA), "ArcRouter: TRANSFER_A_FAILED");
        require(IERC20Router(tokenB).transferFrom(msg.sender, pair, amountB), "ArcRouter: TRANSFER_B_FAILED");
        liquidity = IArcPairRouter(pair).mint(to);
    }

    /// @notice LP tokenlarini geri verip havuzdaki payina karsilik gelen tokenlari geri alir.
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = IArcFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "ArcRouter: PAIR_NOT_FOUND");

        require(IArcPairRouter(pair).transferFrom(msg.sender, pair, liquidity), "ArcRouter: LP_TRANSFER_FAILED");
        (uint256 amount0, uint256 amount1) = IArcPairRouter(pair).burn(to);
        (address token0, ) = _sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= amountAMin, "ArcRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "ArcRouter: INSUFFICIENT_B_AMOUNT");
    }

    function _swap(uint256[] memory amounts, address[] calldata path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = _sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? IArcFactory(factory).getPair(output, path[i + 2]) : _to;
            address pair = IArcFactory(factory).getPair(input, output);
            IArcPairRouter(pair).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /// @notice Belirli miktarda giris tokeni ile en az `amountOutMin` kadar cikis tokeni alir.
    ///         path birden fazla adim iceriyorsa ust uste swaplar zincirlenir (coklu hop).
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path.length >= 2, "ArcRouter: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
        require(amounts[amounts.length - 1] >= amountOutMin, "ArcRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        address firstPair = IArcFactory(factory).getPair(path[0], path[1]);
        require(IERC20Router(path[0]).transferFrom(msg.sender, firstPair, amounts[0]), "ArcRouter: TRANSFER_FAILED");
        _swap(amounts, path, to);
    }
}
