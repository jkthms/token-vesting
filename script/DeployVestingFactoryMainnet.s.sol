// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Script.sol";
import "../test/MockUSDC.sol";
import "../test/MockERC20.sol";
import {MockERC20} from "../test/MockERC20.sol";
import {Vesting} from "../src/Vesting.sol";
import {VestingFactory} from "../src/VestingFactory.sol";
import {Helper} from "./Helper.s.sol";

/**
 * # To load the variables in the .env file
 * source .env
 *
 * # To deploy and verify our contract
 * forge script script/DeployVestingFactoryMainnet.s.sol:DeployVestingFactoryMainnet --rpc-url https://mainnet.infura.io/v3/[KEY] --broadcast --verify -vvvv
 * forge script script/DeployVestingFactoryMainnet.s.sol:DeployVestingFactoryMainnet --rpc-url https://mainnet.infura.io/v3/[KEY] -vvvv
 *
 * # To flattern
 * forge flatten [name]file --output [file]
 */
contract DeployVestingFactoryMainnet is Script, Helper {
    // Goerli
    address private constant treasuryAddress = address(0x83C190dF7BA769E78390C6d93A351EA53258C3eb);
    address private constant deployerAddress = address(0x1511b7A40E8c1b1dcA77804C140c6Cb4c805Ff4A);
    address private constant stfxAddress = address(0x9343e24716659A3551eB10Aff9472A2dcAD5Db2d);

    function run() external {
        vm.startBroadcast(deployer);
        Vesting vestingContract = new Vesting();

        VestingFactory vestingFactory = new VestingFactory(treasuryAddress, address(vestingContract), stfxAddress);

        vm.stopBroadcast();
    }
}
