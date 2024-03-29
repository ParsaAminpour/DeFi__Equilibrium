// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../src/Equilibrium.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {EquilibriumCore} from "../src/EquilibriumCore.sol";

/*
 * @title InstanceEquilibiriumCore
 * @author ParsaAminpour
 * @dev this contract inherited from EquilibriumCore to make internal and private functions external in aim to have a test units.
*/
contract InstanceEquilibriumCore is EquilibriumCore {
    // Fetched from AAVE documents. (https://docs.aave.com/developers/deployed-contracts/v3-testnet-addresses)
    address private constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    address private constant WBTC = 0x29f2D40B0605204364af54EC677bD022dA425d03;

    // Fetched from official Chainlink website (https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1#sepolia-testnet)
    address private constant WETH_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address private constant WBTC_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    constructor(address weth, address wbtc, address weth_feed, address wbtc_feed)
        EquilibriumCore(weth, wbtc, weth_feed, wbtc_feed)
    {}

    function addCollateral(address _from, address _tokenToDeposit, uint256 _amount) external {
        super._addCollateral(_from, _tokenToDeposit, _amount);
    }

    function mintEquilibrium(address _owner, uint256 _amount) external NotZeroAmount(_amount) {
        super._mintEquilibrium(_owner, _amount);
    }

    function calculateEquilibriumAmountToMint(uint256 _collateralAmountAddedInUsd)
        external
        pure
        returns (uint256 quilibrium_amount)
    {
        quilibrium_amount = super._calculateEquilibriumAmountToMint(_collateralAmountAddedInUsd);
    }

    function getUsdValue(address _collateralAddress, uint256 _amountOfCollateral)
        external
        view
        override
        returns (uint256 usd_value)
    {
        usd_value = super._getUsdValue(_collateralAddress, _amountOfCollateral);
    }

    function getUserBalance(address _user, address _collateral) external view returns (uint256, uint256) {
        (uint256 equ_amount, uint256 collateral_amount) = super._getUserBalances(_user, _collateral);
        return (equ_amount, collateral_amount);
    }

    function calculate_health_factor(uint256 _total_equilibrium_minted, uint256 _total_collateral_deposited_in_usd)
        external
        pure
        returns (uint256)
    {
        return super._calculate_health_factor(_total_equilibrium_minted, _total_collateral_deposited_in_usd);
    }

    function getCollateralAmountByUsdAmount(address _collateral, uint256 _usd_amount_to_liquidate)
        external
        view
        returns (uint256 result)
    {
        result = super._getCollateralAmountByUsdAmount(_collateral, _usd_amount_to_liquidate);
    }

    function withdrawCollateral(address _from, address _to, address _collateral, uint256 _amount) external {
        super._withdrawCollateral(_from, _to, _collateral, _amount);
    }

    function getCoreAddress() external view returns (address) {
        return super.get_contract_address();
    }
}
