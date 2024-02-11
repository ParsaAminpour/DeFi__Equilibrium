// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Equilibrium} from "../src/Equilibrium.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {EquilibriumCore} from "../src/EquilibriumCore.sol";

contract EquilibriumEngineTest is Test {
    address public bob; // The main role.
    address public alice;
    address public jack;

    EquilibriumCore public core;

    // Fetched from AAVE documents. (https://docs.aave.com/developers/deployed-contracts/v3-testnet-addresses)

    address private constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    address private constant WBTC = 0x29f2D40B0605204364af54EC677bD022dA425d03;

    // Fetched from official Chainlink website (https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1#sepolia-testnet)
    address private constant WETH_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address private constant WBTC_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    function setUp() public {
        core = new EquilibriumCore(WETH, WBTC, WETH_PRICE_FEED, WBTC_PRICE_FEED);

        bob = makeAddr("bob");
        alice = makeAddr("alice");
        jack = makeAddr("jack");
    }

    function testCollateralAddresses() public {
        (address weth, address wbtc) = core.getSupportedTokenAddress();

        assertEq(weth, WETH);
        assertEq(wbtc, WBTC);
    }

    function testPriceFeedInserted() public {
        (address weth_feed, address wbtc_feed) = core.getCollateralTokenSupportedPriceFeedAddresses();
        assertEq(weth_feed, WETH_PRICE_FEED);
        assertEq(wbtc_feed, WBTC_PRICE_FEED);
    }

    function testEquilibriumCoreContractOwnership() public {
        assertEq(core.owner(), address(this));
    }

    function testEquilibriumTokenContractOwnership() public {
        address equilibium_token_address = core.getEquilibriumTokenAddress();
        assertEq(
            Equilibrium(equilibium_token_address).owner(), address(core));
    }


}
