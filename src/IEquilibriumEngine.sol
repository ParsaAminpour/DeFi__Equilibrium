// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IEquilibriumEngine {
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external;

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external;

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) external;

    function burnDsc(uint256 amount) external;

    function liquidate(address collateral, address user, uint256 debtToCover) external;

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256);

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd);

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256);

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256);
}
