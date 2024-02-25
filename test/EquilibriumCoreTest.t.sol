// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../src/Equilibrium.sol";
import {EquilibriumCore} from "../src/EquilibriumCore.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {InstanceEquilibriumCore} from "../src/InstanceEquilibriumCore.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

// NOTE: These test units are only available and useable in local test networl / anvil network.

contract EquilibriumCoreTest is Test {
    // Errors are belong to the EquilibriumCore smart contract that we are testing it.
    error EquilibriumCore__HealthFactorViolated(address violater, address collateral_asset, uint256 dangerous_hf);
    error EquilibriumCore__transactionReverted(address from);
    error EquilibriumCore__amountShouldNotBeZero();
    error EquilibriumCore__UnsupportedToken();
    error EquilibriumCore__AddressesInConstructorShouldNotBeSame();
    error EquilibriumCore__ineligibleUser();
    error EquilibriumCore_insufficientAmountToWithdrawCollateral(uint256 amountFailed);
    error EquilibriumCore__healthFactorIsNotViolated();
    error EquilibriumCore__healthFactorNotOptimized();

    address public bob; // The main role.
    address public alice;
    address public jack;

    // We don't need these addresses, should be removed ASAP.
    // Fetched from AAVE documents. (https://docs.aave.com/developers/deployed-contracts/v3-testnet-addresses)
    address private constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    address private constant WBTC = 0x29f2D40B0605204364af54EC677bD022dA425d03;

    // Fetched from official Chainlink website (https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1#sepolia-testnet)
    address private constant WETH_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address private constant WBTC_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    uint8 public constant DECIMALS = 8;
    // inital answers
    int256 public constant INIT_ETH_USD_PRICE = 2000e8;
    int256 public constant INIT_BTC_USD_PRICE = 5000e8;

    uint256 public constant INIT_TOKEN_BALANCE = 100e18;

    EquilibriumCore public core;
    InstanceEquilibriumCore public core_instance;

    ERC20Mock public weth_mock;
    ERC20Mock public wbtc_mock;

    MockV3Aggregator public weth_feed;
    MockV3Aggregator public wbtc_feed;

    event CollateralAdded(address indexed owner, address indexed tokenAdded, uint256 indexed amount);
    event EquilibriumMinted(address indexed owner, uint256 indexed amount);
    event CollateralWithdrew(address indexed owner, address indexed collateral, uint256 indexed amount);

    function setUp() public {
        weth_mock = new ERC20Mock("WETH", "WETH", 1000e18);
        wbtc_mock = new ERC20Mock("WBTC", "WBTC", 1000e18);

        weth_feed = new MockV3Aggregator(DECIMALS, INIT_ETH_USD_PRICE);
        wbtc_feed = new MockV3Aggregator(DECIMALS, INIT_BTC_USD_PRICE);

        core = new EquilibriumCore(address(weth_mock), address(wbtc_mock), address(weth_feed), address(wbtc_feed));
        core_instance =
            new InstanceEquilibriumCore(address(weth_mock), address(wbtc_mock), address(weth_feed), address(wbtc_feed));
        
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        jack = makeAddr("jack");

        // First off we should add balance amount for Bob
        weth_mock.transfer(bob, INIT_TOKEN_BALANCE);
        weth_mock.transfer(alice, INIT_TOKEN_BALANCE);
        weth_mock.transfer(jack, INIT_TOKEN_BALANCE);
    }

    function testCollateralAddresses() public {
        (address weth, address wbtc) = core.getSupportedTokenAddress();

        assertEq(weth, address(weth_mock));
        assertEq(wbtc, address(wbtc_mock));
    }

    function testPriceFeedInserted() public {
        (address eth_feed, address btc_feed) = core.getCollateralTokenSupportedPriceFeedAddresses();
        assertEq(eth_feed, address(weth_feed));
        assertEq(btc_feed, address(wbtc_feed));
    }

    function testEquilibriumCoreContractOwnership() public {
        assertEq(core.owner(), address(this));
    }

    function testEquilibriumTokenContractOwnership() public {
        address equilibium_token_address = core.getEquilibriumTokenAddress();
        assertEq(Equilibrium(equilibium_token_address).get_core_address(), address(core));
    }

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /     Deposit Collateral Test Units   /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    function testAddCollateral() public {
        //NOTE: bob Funded in setUp function
        vm.startPrank(bob);
        uint256 amount_to_deposit = 10 ether;
        weth_mock.approve(address(core_instance), amount_to_deposit);

        // check event emitted
        vm.expectEmit(true, true, true, true);
        emit CollateralAdded(bob, address(weth_mock), amount_to_deposit);

        core_instance.addCollateral(bob, address(weth_mock), amount_to_deposit);

        uint256 deposited_amount_in_contract = core_instance.getUserCollateralDepositedAmount(bob, address(weth_mock));
        assertEq(deposited_amount_in_contract, amount_to_deposit);

        uint256 real_equilibiurm_core_collateral_balance = weth_mock.balanceOf(address(core_instance));
        assertEq(real_equilibiurm_core_collateral_balance, amount_to_deposit);
        vm.stopPrank();
    }

    function testDepositCollateral() public {
        //NOTE: bob Funded in setUp function
        vm.startPrank(bob);
        uint256 amount_to_deposit = 10 ether;
        weth_mock.approve(address(core), amount_to_deposit);

        // check event emitted
        vm.expectEmit(true, true, true, true);
        emit CollateralAdded(bob, address(weth_mock), amount_to_deposit);

        core.depositCollateral(address(weth_mock), amount_to_deposit);

        uint256 deposited_amount_in_contract = core.getUserCollateralDepositedAmount(bob, address(weth_mock));
        assertEq(deposited_amount_in_contract, amount_to_deposit);

        uint256 real_equilibiurm_core_collateral_balance = weth_mock.balanceOf(address(core));
        assertEq(real_equilibiurm_core_collateral_balance, amount_to_deposit);
        vm.stopPrank();
    }

    function testMintEquilibrium() public {
        // NOTE: bob funded at setUp function
        vm.startPrank(bob);
        uint256 amount_to_deposit = 100e18; // mint 10 Equilibrium tokens.

        vm.expectEmit(true, true, true, true);
        emit EquilibriumMinted(bob, amount_to_deposit);
        core_instance.mintEquilibrium(bob, amount_to_deposit);

        // check state variables
        uint256 amount_stored_in_contract_state_variable = core_instance.getUserEquilibriumTokenMinted(bob);
        assertEq(amount_stored_in_contract_state_variable, amount_to_deposit);

        Equilibrium equilibrium_token = Equilibrium(core_instance.getEquilibriumTokenAddress());
        uint256 amount_balance_in_equilibrium_token_contract = equilibrium_token.balanceOf(bob);
        assertEq(amount_balance_in_equilibrium_token_contract, amount_to_deposit);

        assertEq(amount_stored_in_contract_state_variable, amount_balance_in_equilibrium_token_contract);
        vm.stopPrank();
    }

    function testRevertsMintEquilibriumByZeroAmount() public {
        vm.startPrank(bob);
        vm.expectRevert(EquilibriumCore__amountShouldNotBeZero.selector);
        core_instance.mintEquilibrium(bob, 0);
        vm.stopPrank();
    }

    function testGetUsdValueForWETH() public {
        uint256 collateral_amount = 7e18; // represent WETH
        // expected: 7e18 * 2000$ | price(WETH) == 2000$
        uint256 expected_result = collateral_amount * uint256(2000e18);

        uint256 main_result = core_instance.getUsdValue(address(weth_mock), collateral_amount);

        console.log("value usd result is: ", main_result);
        console.log("Expected value usd result is: ", expected_result);
        assertEq(expected_result, main_result);
    }

    // NOTE: should be a FUZZ test in here.
    function testCalculateEquilibriumAmountToMint() public {
        // internal calculation
        uint256 collateral_amount_to_add_in_usd = core_instance.getUsdValue(address(weth_mock), 10 ether);

        uint256 liquidation_ratio = 25e17;
        uint256 expected_answer = collateral_amount_to_add_in_usd / liquidation_ratio;

        uint256 real_answer = core_instance.calculateEquilibriumAmountToMint(collateral_amount_to_add_in_usd);

        assertEq(expected_answer, real_answer);
        // For example we have 100$ of WETH as collateral
    }

    function testFailDepositCollateralIfTokenDoesntSupported() public {
        address unsupported_address = makeAddr("unsupported_address");
        // vm.expectRevert(core.EquilibriumCore__UnsupportedToken.selector);
        core.depositCollateralAndMintEquilibrium(unsupported_address, 100e18);
    }

    function testFaildepositCollateralIfZeroamountInserted() public {
        uint256 zero_amount = 0;
        core.depositCollateralAndMintEquilibrium(address(weth_mock), zero_amount);
    }

    function testDepositCollateralAndMinEquilibrium() public {
        vm.startPrank(bob);
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        weth_mock.approve(address(core), amount_to_deposit);

        // check event emitted
        vm.expectEmit(true, true, true, true);
        emit CollateralAdded(bob, address(weth_mock), amount_to_deposit);

        core.depositCollateralAndMintEquilibrium(token_to_deposit, amount_to_deposit);

        uint256 deposited_amount_in_contract = core.getUserCollateralDepositedAmount(bob, address(weth_mock));
        assertEq(deposited_amount_in_contract, amount_to_deposit);

        uint256 real_equilibiurm_core_collateral_balance = weth_mock.balanceOf(address(core));
        assertEq(real_equilibiurm_core_collateral_balance, amount_to_deposit);

        assertEq(uint256(1), uint256(1));
        vm.stopPrank();
    }

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /    Withdraw Collateral Test Units   /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    // Tests that should be failed
    function testFailwithdrawCollateralIneligibleUser() public {
        address inenigible_user = makeAddr("Inenigible_user");
        vm.startPrank(inenigible_user);
        core.withdrawCollateral(address(weth_mock), 10e18);
        vm.stopPrank();
    }

    function testFailwithdrawCollateralNotProperAmount() public {
        vm.startPrank(bob);
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        weth_mock.approve(address(core), amount_to_deposit);

        core.depositCollateralAndMintEquilibrium(token_to_deposit, amount_to_deposit);

        core.withdrawCollateral(address(weth_mock), 11e18);
        vm.stopPrank();
    }

    // function testFailwithdrawCollateralWhenHealthFactorViolated() public {
    // @bug we should manipulate the WETH price due to Mock price feeds which I don't know how
    // }
    // beforeEach for these series of test units.
    modifier DepositCollateralInWETH() {
        vm.startPrank(bob);
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        weth_mock.approve(address(core), amount_to_deposit);

        core.depositCollateralAndMintEquilibrium(token_to_deposit, amount_to_deposit);
        vm.stopPrank();
        _;
    }

    // Tests that should not be failed.
    function testwithdrawCollateral() public DepositCollateralInWETH {
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        uint256 hf = core.get_health_factor(bob, address(weth_mock));
        if (hf > 1e18) console.log("It's ok");
        else console.log("It's not ok");

        vm.startPrank(bob);
        uint256 balance_before = IERC20(weth_mock).balanceOf(bob); // should be init_balance - 10e18
        console.log("balance before: ", balance_before / 1e18); // init balance = 100 => result = 100e18 - 10e18 = 90e18

        // this amount won't break the health factor
        // If you make it for example 10 ether, the last line _revertIfHealthFactorViolated will be triggered.
        uint256 amount_to_withdraw = 1e18;
        weth_mock.approve(address(core), amount_to_withdraw);

        core.withdrawCollateral(token_to_deposit, amount_to_withdraw);
        // uint256 hf2 = core.get_health_factor(bob, address(weth_mock));
        // console.log("Hf after withdraw: ", hf2); // result = 100

        // checking state variable
        uint256 expected_balance_in_state_variable = amount_to_deposit - amount_to_withdraw;
        uint256 state_variable_balance = core.getUserCollateralDepositedAmount(bob, address(weth_mock));
        assertEq(expected_balance_in_state_variable, state_variable_balance);

        // checking the balance from the token's own state variable
        uint256 expect_balance_in_weth_token = balance_before + amount_to_withdraw;
        uint256 state_variable_balance_in_weth = IERC20(weth_mock).balanceOf(bob);
        assertEq(expect_balance_in_weth_token, state_variable_balance_in_weth);

        vm.stopPrank();
    }

    // other FailTest due to modifiers are repeatitive and I won't write them again (because this is just a demo project NOT production).
    // Just more care about the main functionality.
    function testWithdrawCollateralWithBurnEquilibrium() public DepositCollateralInWETH {
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_withdraw = 1e18;

        uint256 hf = core.get_health_factor(bob, address(weth_mock));
        if (hf > 1e18) console.log("It's ok");
        else console.log("It's not ok");

        Equilibrium equilibrium_token = Equilibrium(core.getEquilibriumTokenAddress());

        uint256 equilibrium_balance_before_burning = equilibrium_token.balanceOf(bob);
        uint256 collateral_balance_before_withdrawing = core.getUserCollateralDepositedAmount(bob, address(weth_mock));

        // Effects
        vm.startPrank(bob);
        uint256 collateralAmountInUsd = core_instance.getUsdValue(address(weth_mock), amount_to_withdraw);
        uint256 equilibrium_equivalent_to_collateral_amount =
            core_instance.calculateEquilibriumAmountToMint(collateralAmountInUsd);

        equilibrium_token.approve(address(core), equilibrium_equivalent_to_collateral_amount);
        core.withdrawCollateralWithBurnEquilibrium(token_to_deposit, amount_to_withdraw);
        vm.stopPrank();

        /////// Let's check ///////
        uint256 equilibrium_balance_after_burning = equilibrium_token.balanceOf(bob);

        console.log("The EQU balance before burn: ", equilibrium_balance_before_burning / 1e18);
        console.log("The EQU balance after burn: ", equilibrium_balance_after_burning / 1e18);

        // check the Equilibrium which has been burned
        uint256 expected_equilibrium_balance_after_burn =
            equilibrium_balance_before_burning - equilibrium_equivalent_to_collateral_amount;
        uint256 equilibrium_balance_after_burn = equilibrium_token.balanceOf(bob);
        assertEq(expected_equilibrium_balance_after_burn, equilibrium_balance_after_burn);

        // check that collateral withdrew
        uint256 expected_collateral_balance_after_withdraw = collateral_balance_before_withdrawing - amount_to_withdraw;
        uint256 actual_user_balance_after_withdraw = core.getUserCollateralDepositedAmount(bob, address(weth_mock));
        assertEq(expected_collateral_balance_after_withdraw, actual_user_balance_after_withdraw);
    }

    function testFailWithdrawCollateralWhenHealthFactorViolated() public DepositCollateralInWETH {
        address token_to_deposit = address(weth_mock);
        // The dangrous amount which make protocol Hf violate if we want to withdraw this amount.
        uint256 amount_to_withdraw = 10e18;

        uint256 hf = core.get_health_factor(bob, address(weth_mock));
        if (hf > 1e18) console.log("It's ok");
        else console.log("It's not ok");

        Equilibrium equilibrium_token = Equilibrium(core.getEquilibriumTokenAddress());

        // Effects
        vm.startPrank(bob);
        uint256 collateralAmountInUsd = core_instance.getUsdValue(address(weth_mock), amount_to_withdraw);
        uint256 equilibrium_equivalent_to_collateral_amount =
            core_instance.calculateEquilibriumAmountToMint(collateralAmountInUsd);

        equilibrium_token.approve(address(core), equilibrium_equivalent_to_collateral_amount);

        // bytes4 SELECTOR = bytes4(keccak256("EquilibriumCore__HealthFactorViolated(address,address,uint256)"));
        // vm.expectRevert(SELECTOR);
        core.withdrawCollateral(token_to_deposit, amount_to_withdraw);
        vm.stopPrank();
    }

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /       Liquidation Test Units        /
    *.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*/
    // tests units that should fail.
    function testFailLiquidationIneligibleUser() public {
        address inenigible_user = makeAddr("Inenigible_user");
        vm.startPrank(bob);
        core.liquidation(inenigible_user, address(weth_mock), 1e18);
        vm.stopPrank();
    }

    function testFailLiquidationNotZeroAmount() public {
        vm.startPrank(bob);
        core.liquidation(alice, address(weth_mock), 0);
        vm.stopPrank();
    }

    function testRevertLiquidationWhenHealthFactorIsNotViolated() public DepositCollateralInWETH {
        // Now bob has 10 WETH collateral inside the EquilibriumCore contract.
        vm.startPrank(bob);
        vm.expectRevert(EquilibriumCore__healthFactorIsNotViolated.selector);
        core.liquidation(bob, address(weth_mock), 1e18);
        vm.stopPrank();
    }

    function testLiquidationWithProperAmount() public DepositCollateralInWETH {
        // Now bob has 10 WETH collateral inside the EquilibriumCore contract.
        // Let's make the Health Factor Violate.
    }

    // NOTE: should we write a fuzz test for this Health Factor functionality.
    function testHealthFactor() public {
        vm.startPrank(alice);
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        weth_mock.approve(address(core_instance), amount_to_deposit);

        core_instance.depositCollateralAndMintEquilibrium(token_to_deposit, amount_to_deposit);

        (uint256 total_minted, uint256 total_collateral_balance_in_usd) =
            core_instance.getUserBalance(alice, address(weth_mock));
        console.log("Total minted: ", total_minted / 1e18); // 8000
        console.log("Total collateral: ", total_collateral_balance_in_usd / 1e18); // 20000

        uint256 hf = core_instance.calculate_health_factor(total_minted, total_collateral_balance_in_usd);
        console.log("Health factor is: ", hf);

        assertLt(1e18, hf);
        vm.stopPrank();
    }

    //////burn//////
    function testGetCollateralAmountByUsdAmount() public {
        vm.startPrank(bob);
        // for example the WETH price is 2000$ and we want to liquidate 100$, so we should back 0.05 in did
        uint256 amount_to_liquidate = 100e18;

        uint256 result = core_instance.getCollateralAmountByUsdAmount(address(weth_mock), amount_to_liquidate);

        uint256 expected_calculation = 5e16;

        assertEq(result, expected_calculation);
        vm.stopPrank();
    }

    // test unit for EquilibriumCore::liquidation (all pf aspects).
    function testFailLiquidationUserIsNotEligible() public {
        vm.startPrank(bob);
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        weth_mock.approve(address(core), amount_to_deposit);

        core.depositCollateralAndMintEquilibrium(token_to_deposit, amount_to_deposit);
        vm.stopPrank();

        address ineligible_user = makeAddr("ineligible_user");
        uint256 amount_to_liquidate = 100e18; // 100$ for example
        vm.prank(ineligible_user);
        core.liquidation(ineligible_user, address(weth_mock), amount_to_liquidate);
    }

    function testFailLiquidationWhenHealthFactorIsOk() public {
        vm.startPrank(bob);
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        weth_mock.approve(address(core), amount_to_deposit);

        core.depositCollateralAndMintEquilibrium(token_to_deposit, amount_to_deposit);
        vm.stopPrank();

        vm.startPrank(alice); // alice is liquidator here
        uint256 amount_to_liquidate = 100e18; // 100$ for example
        core.liquidation(bob, address(weth_mock), amount_to_liquidate);

        vm.stopPrank();
    }
}
