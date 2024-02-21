// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../src/Equilibrium.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {EquilibriumCore} from "../src/EquilibriumCore.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {InstanceEquilibriumCore} from "../src/InstanceEquilibriumCore.sol";

contract EquilibriumCoreScript is Script {
    using Strings for string;

    function setUp() public {}

    function toString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
         
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
         
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
         
        return string(str);
    }

    function run() external returns (EquilibriumCore, Equilibrium) {
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

        EquilibriumCore core =
            new EquilibriumCore(weth_address, wbtc_address, sepolia_weth_price_feed, sepolia_wbtc_price_feed);

        Equilibrium token = Equilibrium(core.getEquilibriumTokenAddress());

        vm.stopBroadcast();

        // Writing deployed address into the ../deployed_addresses.txt file.
        address core_address = address(core);
        address core_token_address = address(token);

        console.log("core address is: ", toString(core_address));
        console.log("core token address is: ", toString(core_token_address));

        string memory address_log_file_path = "./deployed_addresses.txt";

        // string[] memory commands = new string[](1);
        // commands[0] = "ls";

        // bytes memory res = vm.ffi(commands);
        // console.log(string(res));
        // assert(vm.exists(address_log_file_path));
        // assert(vm.isFile(address_log_file_path));

        // vm.writeFile(address_log_file_path, toString(core_address));
        // vm.writeFile(address_log_file_path, toString(core_token_address));

        return (core, token);
    }
}
