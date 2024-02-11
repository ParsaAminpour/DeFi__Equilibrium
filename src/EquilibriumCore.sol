// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Equilibrium} from "./Equilibrium.sol";

/*
 * @title EquilibriumCore
 * @author ParsaAminpour
 * @notice This contract is the core functionality of the Equilibrium algorithmic stable coin.
 * @notice Ownable contract functionality will use in operations which won't be broken the decentalization of the Equilibriu.
 * @notice this smart contract is loosely based on the DAI and MakerDAO smart contract.
*/
contract EquilibriumCore is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /               Errors                /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    error EquilibriumCore__transactionReverted(address from);
    error EquilibriumCore__amountShouldNotBeZero();
    error EquilibriumCore__UnsupportedToken();
    error EquilibriumCore__AddressesInConstructorShouldNotBeSame();

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /           State Variables           /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    uint256 private constant LIQUIDATION_RATIO = 15e17; // 1.liquidation ratio is 1.5
    uint256 private constant PRECISION = 1e18;
    uint256 private constant EXTRA_PRECISION_FOR_PRICED_FEED = 1e10; // because the price feed is on (x * 1e8)

    mapping(address user => uint256 amount) private MapEquilibriumMinted;

    mapping(address user => mapping(address token => uint256 amount)) private MapUserCollateralDeposited;

    mapping(address supportedToken => address supportedTokenPriceFeed) private MapSupportedTokenPriceFeed;

    // supporting WETH and WBTC as low-volatility asserts in our collateral system.
    address[2] private tokenSupported;

    Equilibrium private immutable i_equ_token;

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /              Events                 /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    event CollateralAdded(address indexed owner, address indexed tokenAdded, uint256 indexed amount);
    event EquilibriumMinted(address indexed owner, uint256 indexed amount);

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /           Modifiers                 /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    modifier onlySupportedToken(address _token) {
        if (MapSupportedTokenPriceFeed[_token] == address(0)) {
            revert EquilibriumCore__UnsupportedToken();
        }
        _;
    }

    modifier NotZeroAmount(uint256 _amount) {
        if (_amount == 0) {
            revert EquilibriumCore__amountShouldNotBeZero();
        }
        _;
    }

    /*
     * @param weth is the address of the WETH ERC20 token.
     * @param wbtc is the address of the WBTC ERC20 token.
     * @param weth_feed is the address of the Chainlink price feed for WETH.
     * @param wbtc_feed is the address of the Chainlink price feed for WBTC.
    */
    constructor(address weth, address wbtc, address weth_feed, address wbtc_feed) Ownable(msg.sender) {
        if(weth != wbtc && weth_feed != weth_feed) {
            revert EquilibriumCore__AddressesInConstructorShouldNotBeSame();
        }

        tokenSupported[0] = (weth);
        tokenSupported[1] = (wbtc);

        MapSupportedTokenPriceFeed[weth] = weth_feed;
        MapSupportedTokenPriceFeed[wbtc] = wbtc_feed;

        i_equ_token = new Equilibrium();
    }

    /*
     * @notice follows CEI.
     * @param _tokenToDesposit is the token that user wants to add to his collateral treasury.
     * @param _amount is the amount that the user wants to add to his collateral treasury.
    */
    function depositCollateralAndMintEquilibrium(address _tokenToDeposit, uint256 _amount)
        external
        nonReentrant
        onlySupportedToken(_tokenToDeposit)
        NotZeroAmount(_amount)
    {
        // Coverting collateral to USD amount
        uint256 collateralAmountInUsd = _getUsdValue(_tokenToDeposit, _amount);

        // calculate how much QUI should be minted.
        uint256 amountToMint = _calculateEquilibriumAmountToMint(collateralAmountInUsd);

        // mint EQU
        _mintEquilibrium(msg.sender, amountToMint);

        // add collateral
        _addCollateral(msg.sender, _tokenToDeposit, _amount);

        // check Health Factor.
    }

    /*
     * @param _from is the user address.
     * @param _tokenToDeposit is the token that user wants to add to his collateral treasury.
     * @param _amount is the amount to deposit from the user address.
    */
    function _addCollateral(address _from, address _tokenToDeposit, uint256 _amount) internal {
        MapUserCollateralDeposited[_from][_tokenToDeposit] += _amount;
        emit CollateralAdded(_from, _tokenToDeposit, _amount);

        bool success = IERC20(_tokenToDeposit).transferFrom(_from, address(this), _amount);
        if (!success) {
            revert EquilibriumCore__transactionReverted(_from);
        }
    }

    function _mintEquilibrium(address _owner, uint256 _amount) internal NotZeroAmount(_amount) {
        MapEquilibriumMinted[_owner] += _amount;
        emit EquilibriumMinted(_owner, _amount);

        bool success = i_equ_token.mint(_owner, _amount);
        if (!success) revert EquilibriumCore__transactionReverted(_owner);
    }

    /*
     * @param _collateralAmountAddedInUsd is the amount that user has been added in the contract in USD.
     * @notice we should convert the amount of collateral assert e.g. 1ETH to USD amount e.g. 1000$ using Chainlink Aggregator.
     * @dev The amount of Equilibrium to mint will calculate based on the LIQUIDATION_RATIO which is 1.5.
     * @dev the LIQUIDATION_RATIO will calculate based on the (TOTOAL_COLLATERAL_AMOUNT / TOTAL_EQUILIBRIUM_MINTED)
    */
    function _calculateEquilibriumAmountToMint(uint256 _collateralAmountAddedInUsd) internal pure returns (uint256) {
        return (_collateralAmountAddedInUsd * PRECISION) / LIQUIDATION_RATIO;
    }

    // @audit should we analyze and examine the Chainlink Aggregator safety and data stale status.
    function _getUsdValue(address _collateralAddress, uint256 _amountOfCollateral) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(MapSupportedTokenPriceFeed[_collateralAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (uint256(price) * EXTRA_PRECISION_FOR_PRICED_FEED) * _amountOfCollateral;
    }






    function getSupportedTokenAddress() external view returns(address weth, address wbtc) {
        return (tokenSupported[0], tokenSupported[1]);
    }

    function getCollateralTokenSupportedPriceFeedAddresses() external view returns(address weth_feed, address wbtc_feed) {
        return (MapSupportedTokenPriceFeed[tokenSupported[0]], MapSupportedTokenPriceFeed[tokenSupported[1]]);
    }

    function getEquilibriumTokenAddress() external view returns(address) {
        return address(i_equ_token);
    }
}
