// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// Invariants:
// protocol must never be insolvent / undercollateralized
// bug_: users cant create stablecoins with a bad health factor
// bug_: a user should only be able to be liquidated if they have a bad health factor

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {InvariantInUse} from "./InvariantInUse.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InvariantInUse} from "./InvariantInUse.sol";
import {Equilibrium} from "../../src/Equilibrium.sol";
import {EquilibriumCore} from "../../src/EquilibriumCore.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {InstanceEquilibriumCore} from "../../src/InstanceEquilibriumCore.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

/*
 * @title InvariantTesting
 * @author ParsaAminpour
 * @ notice this invariant test contract proof that the total collaterals which have been
    deposited at this contract are more that the total Equilibrium minted and this principle will be maintained during the
    contract functions' executions.
*/
contract InvariantTesting is StdInvariant, Test {
    address bob = makeAddr("bob"); // the interactor user

    uint8 public DECIMALS = 8;
    int256 public INIT_ETH_USD_PRICE = 2000e8;
    int256 public INIT_BTC_USD_PRICE = 5000e8;

    EquilibriumCore public core;
    Equilibrium public core_token;
    InvariantInUse public handler;

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

        handler = new InvariantInUse(address(core), address(core_token));   
        targetContract(address(handler));
    }

    function invariant_totalcollateralDepositedShouldBeLessThanTotalEquilibriumMinted() public {
        vm.startPrank(bob);
        uint256 total_equ_minted = core_token.totalSupply();
        
        uint256 total_weth_deposited = weth_mock.balanceOf(address(core));
        uint256 total_wbtc_deposited = wbtc_mock.balanceOf(address(core));
        console.log("total weth: ", total_weth_deposited);
        console.log("total wbtc: ", total_wbtc_deposited);
        
        uint256 weth_deposited_in_usd = core.getUsdValue(address(weth_mock), total_weth_deposited);
        uint256 wbtc_deposited_in_usd = core.getUsdValue(address(wbtc_mock), total_wbtc_deposited);

        console.log("WETH balance: ", weth_deposited_in_usd);
        console.log("WBTC balance: ", wbtc_deposited_in_usd);
        console.log("EQU balance: ", total_equ_minted);
        
        vm.stopPrank();

        assertGe(weth_deposited_in_usd + wbtc_deposited_in_usd, total_equ_minted);
    }
}