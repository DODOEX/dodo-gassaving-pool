// SPDX-License-Identifier: MIT

pragma solidity ^0.7.5;

import {Test, console} from "forge-std/Test.sol";

import {Deploy} from "../scripts/Deploy.s.sol";
import {DSP} from "../contracts/DSPAdvanced/impl/DSP.sol";
import {IDSP} from "../contracts/DSPAdvanced/intf/IDSP.sol";
import {IERC20} from "../contracts/intf/IERC20.sol";


contract TestDSPAdvanced is Test {
    DSP dspAdvanced; // DAI - USDT
    IDSP constant dsp = IDSP(0x3058EF90929cb8180174D74C507176ccA6835D73); // DAI-USDT

    address constant MAINTAINER = 0x95C4F5b83aA70810D4f142d58e5F7242Bd891CB0;

    address constant USDC_WHALE = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;
    address constant DAI_WHALE = 0x25B313158Ce11080524DcA0fD01141EeD5f94b81;
    address USER = vm.addr(1);

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC20 private dai = IERC20(DAI);
    IERC20 private usdc = IERC20(USDC);

    function setUp() public {
        // Deploy and Init DSPAdvanced
        Deploy deploy = new Deploy();
        dspAdvanced = deploy.run();
    }

    function test_ComparedWithDSP() external {
        // provide liquidity to DSPAdvanced
        (uint256 baseReserve, uint256 quoteReserve) = dsp.getVaultReserve();

        // whales send tokens to USER
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, dai.balanceOf(msg.sender));
        vm.stopPrank();

        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, usdc.balanceOf(msg.sender));
        vm.stopPrank();

        // DSPAdvanced and DSP have the same baseReserve and quoteReserve
        vm.startPrank(USER);
        dai.transfer(address(dspAdvanced), baseReserve);
        usdc.transfer(address(dspAdvanced), quoteReserve);
        dspAdvanced.buyShares(msg.sender);

        // Buy shares from DSP
        dsp.buyShares(msg.sender);

        vm.stopPrank();
    }



}
