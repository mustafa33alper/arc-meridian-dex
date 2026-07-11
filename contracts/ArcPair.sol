// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArcERC20.sol";

interface IArcERC20Token {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

interface IArcCallee {
    function arcCall(address sender, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}

/// @title ArcPair
/// @notice Bir token çifti için likidite havuzu. Uniswap V2 mantığına dayanan
///         sabit çarpım (constant product, x*y=k) otomatik piyasa yapıcı (AMM).
///         LP tokenlari bu kontratin kendisidir (ArcERC20'yi miras alir).
contract ArcPair is ArcERC20 {
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_NUMERATOR = 997; // %0.3 islem ucreti
    uint256 public constant FEE_DENOMINATOR = 1000;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 private unlocked = 1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    modifier lock() {
        require(unlocked == 1, "ArcPair: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() ArcERC20("Arc LP Token", "ARC-LP") {
        factory = msg.sender;
    }

    /// @notice Sadece factory tarafindan, pair olusturulurken bir kez cagrilir.
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "ArcPair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _update(uint256 balance0, uint256 balance1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "ArcPair: OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp % 2**32);
        emit Sync(reserve0, reserve1);
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Likidite ekler. Router bu fonksiyonu cagirmadan once tokenlari
    ///         zaten bu kontrata transfer etmis olmalidir.
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 balance0 = IArcERC20Token(token0).balanceOf(address(this));
        uint256 balance1 = IArcERC20Token(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdEaD), MINIMUM_LIQUIDITY); // ilk likiditeyi kalici olarak kilitle
        } else {
            liquidity = _min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        require(liquidity > 0, "ArcPair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice Likiditeyi geri alir. Router bu fonksiyonu cagirmadan once LP
    ///         tokenlarini zaten bu kontrata transfer etmis olmalidir.
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = IArcERC20Token(token0).balanceOf(address(this));
        uint256 balance1 = IArcERC20Token(token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply;
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "ArcPair: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);
        IArcERC20Token(token0).transfer(to, amount0);
        IArcERC20Token(token1).transfer(to, amount1);

        balance0 = IArcERC20Token(token0).balanceOf(address(this));
        balance1 = IArcERC20Token(token1).balanceOf(address(this));
        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice Takas islemi. Cagirmadan once giris tokeni bu kontrata transfer edilmis olmalidir.
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "ArcPair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "ArcPair: INSUFFICIENT_LIQUIDITY");

        require(to != token0 && to != token1, "ArcPair: INVALID_TO");
        if (amount0Out > 0) IArcERC20Token(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IArcERC20Token(token1).transfer(to, amount1Out);
        if (data.length > 0) IArcCallee(to).arcCall(msg.sender, amount0Out, amount1Out, data);

        uint256 balance0 = IArcERC20Token(token0).balanceOf(address(this));
        uint256 balance1 = IArcERC20Token(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "ArcPair: INSUFFICIENT_INPUT_AMOUNT");

        // %0.3 ucret dusuldukten sonra k degerinin azalmadigini dogrula
        uint256 balance0Adjusted = (balance0 * FEE_DENOMINATOR) - (amount0In * (FEE_DENOMINATOR - FEE_NUMERATOR));
        uint256 balance1Adjusted = (balance1 * FEE_DENOMINATOR) - (amount1In * (FEE_DENOMINATOR - FEE_NUMERATOR));
        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * (FEE_DENOMINATOR**2),
            "ArcPair: K"
        );

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @notice Fazladan (rezervin uzerindeki) bakiyeleri disariya sifirlar.
    function skim(address to) external lock {
        IArcERC20Token(token0).transfer(to, IArcERC20Token(token0).balanceOf(address(this)) - reserve0);
        IArcERC20Token(token1).transfer(to, IArcERC20Token(token1).balanceOf(address(this)) - reserve1);
    }

    /// @notice Bakiyeleri rezervlerle eslesecek sekilde gunceller.
    function sync() external lock {
        _update(IArcERC20Token(token0).balanceOf(address(this)), IArcERC20Token(token1).balanceOf(address(this)));
    }
}
