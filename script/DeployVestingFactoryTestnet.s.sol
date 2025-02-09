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
 * forge script script/DeployVestingTestnet.s.sol:DeployVestingTestnet --rpc-url $GOERLI_RPC_URL --broadcast --verifier-url $VERIFIER_URL -vvvv
 *  --verifier-url
 *
 * # To flattern
 * forge flatten [name]file --output [file]
 */
contract DeployVestingFactoryTestnet is Script, Helper {
    // Goerli
    address private constant treasuryAddress = address(0x7b43F3b0193558131824D0D8fC789C1163507DCb);
    address private constant deployerAddress = address(0xB724495eBc10812e4C0F79A1c16C54a76B0B8936);

    function run() external {
        vm.startBroadcast(deployer);

        MockERC20 testToken = new MockERC20();

        Vesting vestingContract = new Vesting();

        VestingFactory vestingFactory =
            new VestingFactory(treasuryAddress, address(vestingContract), address(testToken));

        testToken.mint(address(treasuryAddress), 1e27);

        vm.stopBroadcast();
    }
}
