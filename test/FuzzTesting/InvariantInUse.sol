// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../../src/Equilibrium.sol";
import {EquilibriumCore} from "../../src/EquilibriumCore.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {InstanceEquilibriumCore} from "../../src/InstanceEquilibriumCore.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract InvariantInUse is StdInvariant, Test {
    address bob = makeAddr("bob"); // the interactor user

    uint8 public DECIMALS = 8;
    int256 public INIT_ETH_USD_PRICE = 2000e8;
    int256 public INIT_BTC_USD_PRICE = 5000e8;

    uint256 public MAX_AMOUNT_TO_DEPOSIT = 1000000e18;

    EquilibriumCore public core;
    Equilibrium public core_token;

    ERC20Mock public weth_mock;
    ERC20Mock public wbtc_mock;

    MockV3Aggregator public weth_feed;
    MockV3Aggregator public wbtc_feed;

    constructor(address _core, address _core_token) {
        core = EquilibriumCore(_core);
        core_token = Equilibrium(_core_token);

        (address weth, address wbtc) = core.getSupportedTokenAddress();
        (address wethFeed, address wbtcFeed) = core.getCollateralTokenSupportedPriceFeedAddresses();

        weth_mock = ERC20Mock(weth);
        wbtc_mock = ERC20Mock(wbtc);

        weth_feed = MockV3Aggregator(wethFeed);
        wbtc_feed = MockV3Aggregator(wbtcFeed);
    }

    function _getCollateral(uint256 idx) internal view returns (address) {
        return (idx % 2 == 0 ? address(weth_mock) : address(wbtc_mock));
    }

    function depositCollateralAndMintEquilibrium(uint256 _collateral_idx, uint256 _amount) public {
        ERC20Mock collateral = ERC20Mock(_getCollateral(_collateral_idx));
        _amount = bound(_amount, 1, MAX_AMOUNT_TO_DEPOSIT);

        vm.startPrank(bob);
        collateral.mint(bob, _amount);
        collateral.approve(address(core), _amount);
        core.depositCollateralAndMintEquilibrium(address(collateral), _amount);
        vm.stopPrank();
    }
}
