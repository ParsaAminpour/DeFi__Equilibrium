// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EquilibriumCore.sol";

contract Equilibrium is ERC20 {
    using SafeERC20 for ERC20;

    error Equilibrium__amountShouldNotBeZero();
    error Equilibrium__AddressCouldNotBeZero();
    error Equilibrium__OnlyEquilibriumCoreCouldCall();

    address private immutable core;

    modifier onlyEquilibriumCore() {
        if(msg.sender != core) {
            revert Equilibrium__OnlyEquilibriumCoreCouldCall();
        }
        _;
    }

    // msg.sender is the EquilibriumCore contract address
    constructor(address _core) ERC20("Equilibrium", "EQU") {
        if(_core == address(0)) revert Equilibrium__AddressCouldNotBeZero();
        core = _core;
    }

    // The onlyOwner don't break the decentralization principle.
    function mint(address _to, uint256 _amount) external onlyEquilibriumCore returns (bool) {
        if (_amount == 0) revert Equilibrium__amountShouldNotBeZero();

        super._mint(_to, _amount);
        return true;
    }

    function burn(address _fire_owner, uint256 _amount) external onlyEquilibriumCore returns (bool) {
        if (_amount == 0) revert Equilibrium__amountShouldNotBeZero();

        super._burn(_fire_owner, _amount);
        return true;
    }

    function get_core_address() external view returns(address) {
        return core;
    }
}
