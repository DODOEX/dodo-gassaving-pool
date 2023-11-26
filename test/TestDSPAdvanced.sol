// SPDX-License-Identifier: MIT

pragma solidity ^0.7.5;
pragma abicoder v2;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../scripts/Deploy.s.sol";
import {DeployDSP} from "../scripts/DeployDSP.s.sol";
import {DSPAdvanced} from "../contracts/DSPAdvanced/impl/DSPAdvanced.sol";
import {DSP} from "../contracts/DODOStablePool/impl/DSP.sol";
import {PMMPricing} from "../contracts/lib/PMMPricing.sol";
import {SafeMath} from "../contracts/lib/SafeMath.sol";
import {IERC20} from "../contracts/intf/IERC20.sol";


contract TestDSPAdvanced is Test {
    using SafeMath for uint256;
    // DAI - USDC
    DSPAdvanced dspAdvanced; 
    DSP dsp;

    address constant USDC_WHALE = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;
    address constant DAI_WHALE = 0x25B313158Ce11080524DcA0fD01141EeD5f94b81;
    address USER = vm.addr(1);

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC20 private dai = IERC20(DAI);
    IERC20 private usdc = IERC20(USDC);

    // test params
    address constant MAINTAINER = 0x95C4F5b83aA70810D4f142d58e5F7242Bd891CB0;
    uint256 constant BASE_RESERVE = 10e18; // 10 DAI
    uint256 constant QUOTE_RESERVE = 10e6; // 10 USDC
    uint256 constant BASE_INPUT = 1e18; // 1 DAI
    uint256 constant QUOTE_INPUT = 2e6; // 2 USDC


    function setUp() public {
        // Deploy and Init DSPAdvanced
        Deploy deploy = new Deploy();
        dspAdvanced = deploy.run();
        DeployDSP deployDSP = new DeployDSP();
        dsp = deployDSP.run();
    }

    function test_BuyShareAndSellShares() public {
        // check PMMState
        dspAdvanced.getPMMState();
        dsp.getPMMState();

        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, 4 * BASE_RESERVE);
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, 4 * QUOTE_RESERVE);
        vm.stopPrank();

        vm.startPrank(USER);
        dai.transfer(address(dspAdvanced), BASE_RESERVE);
        usdc.transfer(address(dspAdvanced), QUOTE_RESERVE);
        (uint256 shares1, uint256 baseInput1, uint256 quoteInput1) = dspAdvanced.buyShares(USER);
        dai.transfer(address(dsp), BASE_RESERVE);
        usdc.transfer(address(dsp), QUOTE_RESERVE);
        (uint256 shares2, uint256 baseInput2, uint256 quoteInput2) = dsp.buyShares(USER);
        console.log("Buy shares: share, baseInput, quoteInput");
        console.log("dspAdvanced:   ", shares1, baseInput1, quoteInput1);
        console.log("total shares:  ", dspAdvanced.balanceOf(USER));
        console.log("dsp:           ", shares2, baseInput2, quoteInput2);
        console.log("total shares:  ", dsp.balanceOf(USER));
        dai.transfer(address(dspAdvanced), BASE_RESERVE);
        usdc.transfer(address(dspAdvanced), QUOTE_RESERVE);
        (shares1, baseInput1, quoteInput1) = dspAdvanced.buyShares(USER);
        dai.transfer(address(dsp), BASE_RESERVE);
        usdc.transfer(address(dsp), QUOTE_RESERVE);
        (shares2, baseInput2, quoteInput2) = dsp.buyShares(USER);
        console.log("Buy shares: share, baseInput, quoteInput");
        console.log("dspAdvanced:   ", shares1, baseInput1, quoteInput1);
        console.log("total shares:  ", dspAdvanced.balanceOf(USER));
        console.log("dsp:           ", shares2, baseInput2, quoteInput2);
        console.log("total shares:  ", dsp.balanceOf(USER));
        
        // burn shares
        (uint256 baseAmount1, uint256 quoteAmount1) = dspAdvanced.sellShares(dspAdvanced.balanceOf(USER).div(2), USER, 0, 0, "", block.timestamp);
        (uint256 baseAmount2, uint256 quoteAmount2) = dsp.sellShares(dsp.balanceOf(USER).div(2), USER, 0, 0, "", block.timestamp);
        vm.stopPrank();
        console.log("Sell shares: baseAmount, quoteAmount");
        console.log("dspAdvanced:   ", baseAmount1, quoteAmount1);
        console.log("total shares:  ", dspAdvanced.balanceOf(USER));
        console.log("dsp:           ", baseAmount2, quoteAmount2);
        console.log("total shares:  ", dsp.balanceOf(USER));

        (baseAmount1, quoteAmount1) = dspAdvanced.sellShares(dspAdvanced.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        (baseAmount2, quoteAmount2) = dsp.sellShares(dsp.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        vm.stopPrank();
        console.log("Sell shares: baseAmount, quoteAmount");
        console.log("dspAdvanced:   ", baseAmount1, quoteAmount1);
        console.log("total shares:  ", dspAdvanced.balanceOf(USER));
        console.log("dsp:           ", baseAmount2, quoteAmount2);
        console.log("total shares:  ", dsp.balanceOf(USER));
    }

    function test_CompareTwoPool() public {
        // check PMMState
        dspAdvanced.getPMMState();
        dsp.getPMMState();

        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, 2 * (BASE_RESERVE + BASE_INPUT));
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, 2 * (QUOTE_RESERVE + QUOTE_INPUT));
        vm.stopPrank();

        vm.startPrank(USER);
        dai.transfer(address(dspAdvanced), BASE_RESERVE);
        usdc.transfer(address(dspAdvanced), QUOTE_RESERVE);
        (uint256 shares1, uint256 baseInput1, uint256 quoteInput1) = dspAdvanced.buyShares(USER);
        dai.transfer(address(dsp), BASE_RESERVE);
        usdc.transfer(address(dsp), QUOTE_RESERVE);
        (uint256 shares2, uint256 baseInput2, uint256 quoteInput2) = dsp.buyShares(USER);
        vm.stopPrank();
        console.log("Buy shares: share, baseInput, quoteInput");
        console.log("dspAdvanced:   ", shares1, baseInput1, quoteInput1);
        console.log("dsp:           ", shares2, baseInput2, quoteInput2);

        // sellbase and sellquote
        vm.startPrank(USER);
        dai.transfer(address(dspAdvanced), BASE_INPUT);
        uint256 receiveQuoteAmount1 = dspAdvanced.sellBase(USER);
        dai.transfer(address(dsp), BASE_INPUT);
        uint256 receiveQuoteAmount2 = dsp.sellBase(USER);
        console.log("Sell Base: receiveQuoteAmount");
        console.log("dspAdvanced:   ", receiveQuoteAmount1);
        console.log("dsp:           ", receiveQuoteAmount2);

        usdc.transfer(address(dspAdvanced), QUOTE_INPUT);
        uint256 receiveBaseAmount1 = dspAdvanced.sellQuote(USER);
        usdc.transfer(address(dsp), QUOTE_INPUT);
        uint256 receiveBaseAmount2 = dsp.sellQuote(USER);
        console.log("Sell Quote: receiveBaseAmount");
        console.log("dspAdvanced:   ", receiveBaseAmount1);
        console.log("dsp:           ", receiveBaseAmount2);
        vm.stopPrank();


        // check baseReserve, quoteReserve
        (uint256 baseReserve1, uint256 quoteReserve1) = dspAdvanced.getVaultReserve();
        (uint256 baseReserve2, uint256 quoteReserve2) = dsp.getVaultReserve();
        console.log("Check reserve: baseReserve, quoteReserve");
        console.log("dspAdvanced:   ", baseReserve1, quoteReserve1);
        console.log("mtFee:         ", dspAdvanced._MT_FEE_BASE_(), dspAdvanced._MT_FEE_QUOTE_());
        console.log("dsp:           ", baseReserve2, quoteReserve2);

        // query price

        // burn shares
        vm.startPrank(USER);
        (uint256 baseAmount1, uint256 quoteAmount1) = dspAdvanced.sellShares(dspAdvanced.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        (uint256 baseAmount2, uint256 quoteAmount2) = dsp.sellShares(dsp.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        vm.stopPrank();
        console.log("Sell shares: baseAmount, quoteAmount");
        console.log("dspAdvanced:   ", baseAmount1, quoteAmount1);
        console.log("dsp:           ", baseAmount2, quoteAmount2);
    } 
}
