// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../src/Equilibrium.sol";
import {EquilibriumCore} from "../src/EquilibriumCore.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {InstanceEquilibriumCore} from "../src/InstanceEquilibriumCore.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

// NOTE: These test units are only available and useable in local test networl / anvil network.

contract EquilibriumCoreTest is Test {
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
        assertEq(Equilibrium(equilibium_token_address).owner(), address(core));
    }

    /*.*.*.*.*.*.*.*.*.**.*.*.*.*.*.*.*.*.*    
    /     Internal & Private Function     /
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

    function testFailMintEquilibriumByZeroAmount() public {
        vm.startPrank(bob);
        // vm.expectRevert(core.EquilibriumCore__amountShouldNotBeZero.selector);
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

    /////////////////////////////////////////////////////////////////////////////////
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

    function testwithdrawCollateral() public {
        vm.startPrank(bob);
        address token_to_deposit = address(weth_mock);
        uint256 amount_to_deposit = 10e18;

        weth_mock.approve(address(core), amount_to_deposit);

        core.depositCollateralAndMintEquilibrium(token_to_deposit, amount_to_deposit);
        vm.stopPrank();

        uint256 hf = core.get_health_factor(bob, address(weth_mock));
        if (hf > 1e18) {
            console.log("It's ok");
        } else {
            console.log("It's not ok");
        }

        vm.startPrank(bob);
        uint256 balance_before = IERC20(weth_mock).balanceOf(bob);

        core.withdrawCollateral(address(weth_mock), amount_to_deposit);

        // checking state variable
        uint256 expected_balance_in_state_variable = 0;
        uint256 state_variable_balance = core.getUserCollateralDepositedAmount(bob, address(weth_mock));
        assertEq(expected_balance_in_state_variable, state_variable_balance);

        // checking the balance from the token's own state variable
        uint256 expect_balance_in_weth_token = balance_before + amount_to_deposit;
        uint256 state_variable_balance_in_weth = IERC20(weth_mock).balanceOf(bob);
        assertEq(expect_balance_in_weth_token, state_variable_balance_in_weth);

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
}
