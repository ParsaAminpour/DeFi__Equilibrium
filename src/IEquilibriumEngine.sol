// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IEquilibriumEngine {
    /*
    /* @param _tokenCollateral is the token that user wants to add it as a collateral.
    /* @param _amount is the amount to add in collateral
    /* @returns bool is the token for collateral sended successfuly to the Engine contract.
    */
    function depositCollateralAndMintDSCE(address _tokenCollateral, uint256 _amount) external returns (bool);

    function depositCollateral() external returns (bool);

    function redeemCollateralForDSCE() external returns (bool);

    function redeemCollateral() external returns (bool);

    function mintDSCE(uint256 _amountDsceToMint) external;

    function burnDSCE() external;

    function liquidation() external returns (bool);

    function getHealthFactor() external returns (bool);

    function getUserCollateralValue(address _user) external view returns (uint256);
}
