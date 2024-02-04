// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract EquilibriumEngine {
    function depositCollateralAndMintDSCE() external returns (bool) {}

    /*
    /* @param _tokenCollateral is the token that user wants to add it as a collateral.
    /* @param _amount is the amount to add in collateral
    /* @returns bool is the token for collateral sended successfuly to the Engine contract.
    */
    function depositCollateral() external returns (bool) {}

    function redeemCollateralForDSCE() external returns (bool) {}

    function redeemCollateral() external returns (bool) {}

    function mintDSCE() external {}

    function burnDSCE() external {}

    function liquidation() external returns (bool) {}

    function getHealthFactor() external returns (bool) {}

    function getUserCollateralValue(address _user) external view returns (uint256) {}

    /// Internal and Private functions

    /*
    /* Returns how close to liquidation a user is
    /* If a uses's H(f) goes below 1, then they can get liquidation
    */
    function _healthFactor(address _user) private view returns (uint256) {
        // Check healt factor (Do they have enough collateral?)
        // If do not, then revert
    }

    function _revertIfHealthFactorIsBelow1() private view {}
}
