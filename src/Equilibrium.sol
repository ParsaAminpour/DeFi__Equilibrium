// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Equilibrium is ERC20, Ownable {
    using SafeERC20 for ERC20;

    error Equilibrium__ZeroAddressDetected();

    // msg.sender is the EquilibriumCore contract address
    constructor() ERC20("Equilibrium", "EQU") Ownable(msg.sender) {}

    // The onlyOwner don't break the decentralization principle.
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) revert Equilibrium__ZeroAddressDetected();

        super._mint(_to, _amount);
        return true;
    }
}
