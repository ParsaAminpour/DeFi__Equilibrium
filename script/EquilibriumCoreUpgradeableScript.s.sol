// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../src/Equilibrium.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {EquilibriumCore} from "../src/EquilibriumCore.sol";
import {EquilibriumCoreUpgradeable} from "../src/EquilibriumCoreUpgradeable.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {InstanceEquilibriumCore} from "../src/InstanceEquilibriumCore.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract EquilibriumCoreUpgradeableScript is Script {
    function run() external returns (EquilibriumCoreUpgradeable, Equilibrium) {
        uint256 private_key = vm.envUint("PRIVATE_KEY");
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

        EquilibriumCoreUpgradeable core_upgradeable = new EquilibriumCoreUpgradeable();
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(core_upgradeable), ""); 
        
        EquilibriumCoreUpgradeable(address(proxy)).initialize(weth_address, wbtc_address, sepolia_weth_price_feed, sepolia_wbtc_price_feed);

        Equilibrium token = Equilibrium(EquilibriumCoreUpgradeable(address(proxy)).getEquilibriumTokenAddress()); 

        vm.stopBroadcast();
        
        console.log("The new EquilibriumCoreUpgradeable address is: ", address(EquilibriumCoreUpgradeable(address(proxy))));
        console.log("The Equilibrium token address is: ", address(token));
        console.log("the proxy address is ", address(proxy));

        return (core_upgradeable, token);
    }

    // if you decide to upgrade EquilibriumCoreUpgradeable to a _new_equilibrium_core contract's address.
    // function upgrade_equilibrium_core(address proxy_address, address _new_equilibrium_core) public returns(address proxy_address){
    //     vm.startBroadcast();
    //     EquilibriumCoreUpgradeable core_upgrade_proxy = EquilibriumCoreUpgradeable(payable(proxy_address));
    //     core_upgrade_proxy.upgradeTo(address(_new_equilibrium_core));
    //     vm.stopBroadcast();

    //     proxy_address = address(core_upgrade_proxy);
    // }
}