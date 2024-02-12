// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../src/Equilibrium.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {EquilibriumCore} from "../src/EquilibriumCore.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {InstanceEquilibriumCore} from "../src/InstanceEquilibriumCore.sol";

contract EquilibriumCoreScript is Script {
    function setUp() public {}

    function run() external returns(EquilibriumCore, Equilibrium) {
        uint private_key = vm.envUint("PRIVATE_KEY");
        address weth_address = vm.envAddress("SEPOLIA_WETH_ADDRESS");
        address wbtc_address = vm.envAddress("SEPOLIA_WBTC_ADDRESS");
        address sepolia_weth_price_feed = vm.envAddress("SEPOLIA_WETH_PRICE_FEED");
        address sepolia_wbtc_price_feed = vm.envAddress("SEPOLIA_WBTC_PRICE_FEED");

        // data verification during deployment.
        console.log(weth_address);
        console.log(wbtc_address);
        console.log(sepolia_weth_price_feed);
        console.log(sepolia_wbtc_price_feed);
        console.log(vm.addr(private_key));

        vm.startBroadcast(private_key);

        EquilibriumCore core = new EquilibriumCore(
            weth_address, wbtc_address,
            sepolia_weth_price_feed, sepolia_wbtc_price_feed
        );

        Equilibrium token = Equilibrium(core.getEquilibriumTokenAddress());

        vm.stopBroadcast();

        return (core, token);
    }
}