// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArcERC20.sol";

/// @title TestToken
/// @notice Testnette DEX'i denemek için herkesin ücretsiz mint edebildiği ERC20 token.
///         Her cüzdan istediği zaman FAUCET_AMOUNT kadar token basabilir.
contract TestToken is ArcERC20 {
    uint256 public constant FAUCET_AMOUNT = 1000 * 1e18;

    constructor(string memory _name, string memory _symbol, uint256 initialSupply)
        ArcERC20(_name, _symbol)
    {
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    /// @notice Herkes bu fonksiyonu çağırarak cüzdanına test tokeni basabilir.
    function faucet() external {
        _mint(msg.sender, FAUCET_AMOUNT);
    }
}
