// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArcPair.sol";

/// @title ArcFactory
/// @notice Iki token icin likidite havuzu (pair) olusturur ve tum havuzlari takip eder.
///         Her token cifti icin CREATE2 ile deterministik adreste tek bir pair olusur.
contract ArcFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairIndex);

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "ArcFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ArcFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "ArcFactory: PAIR_EXISTS");

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(new ArcPair{salt: salt}());
        ArcPair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length - 1);
    }
}
