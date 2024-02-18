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
    error EquilibriumCore__HealthFactorViolated(address violater, address collateral_asset, uint256 dangerous_hf);
    error EquilibriumCore__transactionReverted(address from);
    error EquilibriumCore__amountShouldNotBeZero();
    error EquilibriumCore__UnsupportedToken();
    error EquilibriumCore__AddressesInConstructorShouldNotBeSame();
    error EquilibriumCore__ineligibleUser();
    error EquilibriumCore_insufficientAmountToWithdrawCollateral(uint256 amountFailed);
    error EquilibriumCore__healthFactorIsNotViolated();
    error EquilibriumCore__healthFactorNotOptimized();

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /           State Variables           /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    uint256 private constant LIQUIDATION_RATIO = 25e17; // 1.liquidation ratio is 2 and we should be at least 2.5 time over-collaterlized.
    uint256 private constant PRECISION = 1e18; // formal precision in smart contracts.
    uint256 private constant EXTRA_PRECISION_FOR_PRICE_FEED = 1e10; // because the price feed is on (x * 1e8)
    uint256 private constant HEALTH_FACTOR_THRESHOLD = 1e18; // The key of the contract, the Hf shouldn't go under this amount;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // For calculating Health Factor.
    uint256 private constant LIQUIDATION_PRECISION = 100; // For calculating Health Factor.
    uint256 private constant LIQUIDATOR_BONOUS = 10;

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
    event CollateralWithdrew(address indexed owner, address indexed collateral, uint256 indexed amount);
    event EquilibriumBurned(address indexed owner, uint256 indexed amount);

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

    modifier isEligibleUser(address _user, address _collateral) {
        if (MapUserCollateralDeposited[_user][_collateral] == 0) {
            revert EquilibriumCore__ineligibleUser();
        }
        _;
    }

    modifier isAmountProper(address _user, address _collateral, uint256 _amount) {
        if (MapUserCollateralDeposited[_user][_collateral] < _amount) {
            revert EquilibriumCore_insufficientAmountToWithdrawCollateral(_amount);
        }
        _;
    }

    modifier isHealthFactorViolated(address _user, address _collateral) {
        uint256 hf = get_health_factor(_user, _collateral);
        if (hf < HEALTH_FACTOR_THRESHOLD) {
            revert EquilibriumCore__HealthFactorViolated(_user, _collateral, hf);
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
        if (weth == wbtc && weth_feed == wbtc_feed) {
            revert EquilibriumCore__AddressesInConstructorShouldNotBeSame();
        }

        tokenSupported[0] = (weth);
        tokenSupported[1] = (wbtc);

        MapSupportedTokenPriceFeed[weth] = weth_feed;
        MapSupportedTokenPriceFeed[wbtc] = wbtc_feed;

        i_equ_token = new Equilibrium();
    }

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /         External Functions          /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    /*
     * @notice follows CEI.
     * @param _tokenToDesposit is the token that user wants to add to his collateral treasury.
     * @param _amount is the amount that the user wants to add to his collateral treasury.
    */
    function depositCollateralAndMintEquilibrium(address _tokenToDeposit, uint256 _amount)
        external
        nonReentrant // just for being conservatism
        onlySupportedToken(_tokenToDeposit)
        NotZeroAmount(_amount)
    {
        // Coverting collateral to USD amount to calculate amountToMint variable.
        // for example: price(WETH) = 2000e18$ && count = 10e18WETH ==> 20000e36$
        uint256 collateralAmountInUsd = _getUsdValue(_tokenToDeposit, _amount);
 
        // calculate how much QUI should be minted.
        uint256 amountToMint = _calculateEquilibriumAmountToMint(collateralAmountInUsd);

        // add collateral
        _addCollateral(msg.sender, _tokenToDeposit, _amount);

        // mint EQU
        _mintEquilibrium(msg.sender, amountToMint);
    }

    /*
     * @dev this won't break the Health Factor but it will increate this factor too.
    */
    function depositCollateral(address _tokenToDeposit, uint256 _amount)
        external
        nonReentrant // just for being conservatism
        onlySupportedToken(_tokenToDeposit)
        NotZeroAmount(_amount)
    {
        _addCollateral(msg.sender, _tokenToDeposit, _amount);
    }

    // Just when collateral owner wants to withdraw his own collateral.
    // NOTE: this function is not proper for solving health factor chaos.
    function withdrawCollateral(address _tokenToWithdraw, uint256 _amount)
        external
        nonReentrant
        isEligibleUser(msg.sender, _tokenToWithdraw) // verifying collateral address accuracy simulteneuosly.
        isAmountProper(msg.sender, _tokenToWithdraw, _amount)
        isHealthFactorViolated(msg.sender, _tokenToWithdraw)
    {
        _withdrawCollateral(address(this), msg.sender, _tokenToWithdraw, _amount);

        _revertIfHealthFactorViolated(msg.sender, _tokenToWithdraw);
    }

    function withdrawCollateralWithBurnEquilibrium(address _tokenToWithdraw, uint256 _amount)
        external
        nonReentrant
        isEligibleUser(msg.sender, _tokenToWithdraw) // verifying collateral address accuracy simulteneuosly.
        isAmountProper(msg.sender, _tokenToWithdraw, _amount)
        isHealthFactorViolated(msg.sender, _tokenToWithdraw)
    {
        uint256 collateralAmountInUsd = _getUsdValue(_tokenToWithdraw, _amount);
        // calculate how much QUI should be minted.
        uint256 equilibrium_equivalent_to_collateral_amount = _calculateEquilibriumAmountToMint(collateralAmountInUsd);

        _burnEquilibrium(msg.sender, msg.sender, equilibrium_equivalent_to_collateral_amount);
        _withdrawCollateral(address(this), msg.sender, _tokenToWithdraw, _amount);
        _revertIfHealthFactorViolated(msg.sender, _tokenToWithdraw);
    }
    // 100$ WETH ~ 40$ EQU

    // we don't check the health factor after withdrawing in this function.
    function _withdrawCollateral(address _from, address _to, address _collateral, uint256 _amount) internal {
        // we've already checked the amount in isAmountProper modifier.
        if (_from == address(this)) {
            MapUserCollateralDeposited[_to][_collateral] -= _amount;
            emit CollateralWithdrew(_to, _collateral, _amount);

            bool success = IERC20(_collateral).transfer(_to, _amount);
            if (!success) {
                revert EquilibriumCore__transactionReverted(msg.sender);
            }
        } else {
            // the collateral treasury is the EquilibriumCore contract, so the _from address consider as address(this).
            // actual interaction before health factor examined.
            bool success = IERC20(_collateral).transferFrom(_from, _to, _amount);
            if (!success) {
                revert EquilibriumCore__transactionReverted(msg.sender);
            }
            emit CollateralWithdrew(_to, _collateral, _amount);
        }
    }

    /*
     * @param _amount_to_liquidate is the amount which calculated off-chain to make Health Factor value above 1e18
    */
    function liquidation(address _user, address _collateral, uint256 _amount_to_liquidate_in_usd)
        external
        isEligibleUser(_user, _collateral)
        NotZeroAmount(_amount_to_liquidate_in_usd)
        nonReentrant
    {
        uint256 health_factor_ratio_before = get_health_factor(_user, _collateral);
        if (health_factor_ratio_before > HEALTH_FACTOR_THRESHOLD) revert EquilibriumCore__healthFactorIsNotViolated();

        // let see how much _amount_to_liquidate_in_usd is in USD for _collateral
        uint256 liquidator_bonous = (_amount_to_liquidate_in_usd * LIQUIDATOR_BONOUS) / LIQUIDATION_PRECISION;
        uint256 collateral_amount_to_liquidate_in_usd =
            _getCollateralAmountByUsdAmount(_collateral, (_amount_to_liquidate_in_usd + liquidator_bonous));

        // burn liquidator Equilibrium stablecoin
        _burnEquilibrium(_user, msg.sender, _amount_to_liquidate_in_usd);

        // paying back the collateral with 10% bonous
        _withdrawCollateral(_user, msg.sender, _collateral, collateral_amount_to_liquidate_in_usd);

        uint256 health_factor_ratio_after = get_health_factor(_user, _collateral);

        if (health_factor_ratio_after <= health_factor_ratio_before) revert EquilibriumCore__healthFactorNotOptimized();
    }

    function getUsdValue(address _collateral, uint256 _collateral_amount) external view virtual returns(uint256) {
        return _getUsdValue(_collateral, _collateral_amount);
    }




    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /     Internal & Private Function     /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/

    function _revertIfHealthFactorViolated(address _user, address _collateral) internal view {
        uint256 hf = get_health_factor(_user, _collateral);
        if (hf < HEALTH_FACTOR_THRESHOLD) {
            revert EquilibriumCore__HealthFactorViolated(_user, _collateral, hf);
        }
    }

    /*
     * @notice the _liquidator is a volunteer to burn his own Equilibrium stablecoin to get the collateral(+10%) as 
        reward to make protocol health factor solvent. 
    */
    function _burnEquilibrium(address _user, address _liquidator, uint256 _amount) internal {
        MapEquilibriumMinted[_user] -= _amount;

        bool success = i_equ_token.transferFrom(_liquidator, address(this), _amount);
        if (!success) {
            revert EquilibriumCore__transactionReverted(_liquidator);
        }
        emit EquilibriumBurned(_user, _amount);

        i_equ_token.burn(address(this), _amount); // decrease total supply
    }

    function _getUserBalances(address _user, address _collateral) internal view returns (uint256, uint256) {
        uint256 equilibrium_token_balance = MapEquilibriumMinted[_user];
        uint256 total_collateral_balance = MapUserCollateralDeposited[_user][_collateral];
        uint256 total_collateral_balance_in_usd = _getUsdValue(_collateral, total_collateral_balance / 1e18);

        return (equilibrium_token_balance, total_collateral_balance_in_usd);
    }

    /* Calculation has been verified
     * @notice the amount of Equilibiurm minted is 250% times of collateral amount in did and whereas the LIQUIDATION_RATIO
        is 2 which means the amount of collateral should 2 times more than the Equilibrium token amount for a specific user,
        So, we declared the initial ration as 2.5 to be over-collateralized.
    */
    function _calculate_health_factor(uint256 _total_equilibrium_minted, uint256 _total_collateral_deposited_in_usd)
        internal
        pure
        returns (uint256)
    {
        // The actual Hf calculation: _total_equilibrium_minted: A & total_collateral_deposited_in_usd: B
        // Hf (((A * 0.5) * 1e18) / B) ~ ((A * 1e18) / 2*B) Ooh such a math genius am I 😂
        uint256 threshold_for_collateral =
            (_total_collateral_deposited_in_usd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (threshold_for_collateral * PRECISION) / _total_equilibrium_minted;
    }

    function get_health_factor(address _user, address _collateral) public view returns (uint256) {
        (uint256 total_minted, uint256 total_collateral_balance_in_usd) = _getUserBalances(_user, _collateral);
        uint256 hf = _calculate_health_factor(total_minted, total_collateral_balance_in_usd);
        return hf;
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
        return _collateralAmountAddedInUsd / LIQUIDATION_RATIO;
    }

    // @audit should we analyze and examine the Chainlink Aggregator safety and data stale status.
    function _getUsdValue(address _collateralAddress, uint256 _amountOfCollateral) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(MapSupportedTokenPriceFeed[_collateralAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (uint256(price) * EXTRA_PRECISION_FOR_PRICE_FEED) * _amountOfCollateral;
    }

    // @dev should consider PRECISION dividing in other calculations include this function's output.
    function _getCollateralAmountByUsdAmount(address _collateral, uint256 _usd_amount_to_liquidate_in_wei)
        internal
        view
        returns (uint256)
    {
        uint256 collateral_usd_price = _getUsdValue(_collateral, 1); // for example 2000e18
        return (_usd_amount_to_liquidate_in_wei * PRECISION) / (collateral_usd_price);
        // (100e18 * 1e18) / (2000 * 1e18)
    }

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /           get functions             /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    function getSupportedTokenAddress() external view returns (address weth, address wbtc) {
        return (tokenSupported[0], tokenSupported[1]);
    }

    function getCollateralTokenSupportedPriceFeedAddresses()
        external
        view
        returns (address weth_feed, address wbtc_feed)
    {
        return (MapSupportedTokenPriceFeed[tokenSupported[0]], MapSupportedTokenPriceFeed[tokenSupported[1]]);
    }

    function getUserCollateralDepositedAmount(address _user, address _collateral_address)
        external
        view
        returns (uint256)
    {
        return MapUserCollateralDeposited[_user][_collateral_address];
    }

    function getUserEquilibriumTokenMinted(address _user) external view returns (uint256) {
        return MapEquilibriumMinted[_user];
    }

    function getEquilibriumTokenAddress() external view returns (address) {
        return address(i_equ_token);
    }

    // Constant state variable values
    function get_LIQUIDATION_RATIO() external pure returns (uint256) {
        return LIQUIDATION_RATIO;
    }

    function get_PRECISION() external pure returns (uint256) {
        return PRECISION;
    }

    function get_EXTRA_PRECISION_FOR_PRICE_FEED() external pure returns (uint256) {
        return EXTRA_PRECISION_FOR_PRICE_FEED;
    }

    // tmp function, should be removed.
    function get_contract_address() internal view returns (address) {
        return address(this);
    }
}
