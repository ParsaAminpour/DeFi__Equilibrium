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

    EquilibriumCore public core;
    InstanceEquilibriumCore public core_instance;

    ERC20Mock public weth_mock;
    ERC20Mock public wbtc_mock;

    MockV3Aggregator public weth_feed;
    MockV3Aggregator public wbtc_feed;

    event CollateralAdded(address indexed owner, address indexed tokenAdded, uint256 indexed amount);
    event EquilibriumMinted(address indexed owner, uint256 indexed amount);

    function setUp() public {
        weth_mock = new ERC20Mock("WETH", "WETH", 1000e18);
        wbtc_mock = new ERC20Mock("WBTC", "WBTC", 1000e18);

        weth_feed = new MockV3Aggregator(DECIMALS, INIT_ETH_USD_PRICE);
        wbtc_feed = new MockV3Aggregator(DECIMALS, INIT_BTC_USD_PRICE);

        console.log("weth feed: ", address(weth_feed));
        console.log("wbtc feed: ", address(wbtc_feed));

        core = new EquilibriumCore(address(weth_mock), address(wbtc_mock), address(weth_feed), address(wbtc_feed));
        core_instance =
            new InstanceEquilibriumCore(address(weth_mock), address(wbtc_mock), address(weth_feed), address(wbtc_feed));

        bob = makeAddr("bob");
        alice = makeAddr("alice");
        jack = makeAddr("jack");

        // First off we should add balance amount for Bob
        weth_mock.transfer(bob, 10e18);
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
}
