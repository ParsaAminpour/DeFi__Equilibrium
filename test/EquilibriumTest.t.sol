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

contract EquilibriumTest is Test {
    address not_core_address = makeAddr("not_core");
    address random_user = makeAddr("random_user");
   

    uint256 public constant INIT_TOKEN_BALANCE = 100e18;
    uint8 public constant DECIMALS = 8;
    // inital answers
    int256 public constant INIT_ETH_USD_PRICE = 2000e8;
    int256 public constant INIT_BTC_USD_PRICE = 5000e8;

    EquilibriumCore public core;
    Equilibrium public core_token;

    ERC20Mock public weth_mock;
    ERC20Mock public wbtc_mock;

    MockV3Aggregator public weth_feed;
    MockV3Aggregator public wbtc_feed;

    function setUp() public {
        weth_mock = new ERC20Mock("WETH", "WETH", 1000e18);
        wbtc_mock = new ERC20Mock("WBTC", "WBTC", 1000e18);

        weth_feed = new MockV3Aggregator(DECIMALS, INIT_ETH_USD_PRICE);
        wbtc_feed = new MockV3Aggregator(DECIMALS, INIT_BTC_USD_PRICE);

        core = new EquilibriumCore(address(weth_mock), address(wbtc_mock), address(weth_feed), address(wbtc_feed));
        core_token = Equilibrium(core.getEquilibriumTokenAddress());

    }
    
    function testEquilibriumCoreOwnerShip() public {
        console.log(address(core_token));
        assertEq(core_token.get_core_address(), address(core));
    }

    function testFailMintInOwnerShipPurpose() public {
        vm.startPrank(not_core_address);
        core_token.mint(random_user, 1e18);
        vm.stopPrank();
    }

    function testMintInOwnerShipPurpose() public {
        vm.startPrank(address(core));
        core_token.mint(random_user, 1e18);
        vm.stopPrank();
    }

    function testFailBurnInOwnerShipPurpose() public {
        vm.prank(address(core));
        core_token.mint(random_user, 1e18);

        vm.startPrank(not_core_address);
        core_token.burn(random_user, 1e18);
        vm.stopPrank();
    }
}