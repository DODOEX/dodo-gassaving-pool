// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;
pragma abicoder v2;

import {Test, console} from "forge-std/Test.sol";
import {DeployGSP} from "../scripts/DeployGSP.s.sol";
import {DeployDSP} from "../scripts/DeployDSP.s.sol";
import {GSP} from "../contracts/GasSavingPool/impl/GSP.sol";
import {DSP} from "../contracts/DODOStablePool/impl/DSP.sol";
import {PMMPricing} from "../contracts/lib/PMMPricing.sol";
import {SafeMath} from "../contracts/lib/SafeMath.sol";
import {IERC20} from "../contracts/intf/IERC20.sol";


contract TestGasSavingPool is Test {
    using SafeMath for uint256;
    // DAI - USDC
    GSP gsp; 
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
        // Deploy and Init 
        DeployGSP deployGSP = new DeployGSP();
        gsp = deployGSP.run();
        DeployDSP deployDSP = new DeployDSP();
        dsp = deployDSP.run();
    }


    function test_BuySharesAndSellShares() public {
        uint256 loop = 2;
        // check PMMState
        gsp.getPMMState();
        dsp.getPMMState();

        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, 4 * BASE_RESERVE);
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, 4 * QUOTE_RESERVE);
        vm.stopPrank();
        
        vm.startPrank(USER);
        uint256 shares1; 
        uint256 baseInput1;
        uint256 quoteInput1;
        uint256 shares2; 
        uint256 baseInput2;
        uint256 quoteInput2;
        // buy shares
        for (uint256 i = 0; i < loop; i++) {
            dai.transfer(address(gsp), BASE_RESERVE);
            usdc.transfer(address(gsp), QUOTE_RESERVE);
            (shares1, baseInput1, quoteInput1) = gsp.buyShares(USER);
            dai.transfer(address(dsp), BASE_RESERVE);
            usdc.transfer(address(dsp), QUOTE_RESERVE);
            (shares2, baseInput2, quoteInput2) = dsp.buyShares(USER);
            assertEq(shares1, shares2, "gsp shares != dsp shares");
            assertEq(baseInput1, baseInput2, "gsp baseInput != dsp baseInput");
            assertEq(quoteInput1, quoteInput2, "gsp quoteInput != dsp quoteInput");
            assertEq(gsp.balanceOf(USER), dsp.balanceOf(USER), "gsp total shares != dsp total shares");
        }
        // sell shares
        (uint256 baseAmount1, uint256 quoteAmount1) = gsp.sellShares(gsp.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        (uint256 baseAmount2, uint256 quoteAmount2) = dsp.sellShares(dsp.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        assertEq(baseAmount1, baseAmount2, "gsp baseAmount != dsp baseAmount");
        assertEq(quoteAmount1, quoteAmount2, "gsp quoteAmount != dsp quoteAmount");
        assertEq(gsp.balanceOf(USER), dsp.balanceOf(USER), "gsp total shares != dsp total shares");
    }


    function test_SellBase() public {
        uint256 loop = 2;
        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, 2 * (BASE_RESERVE + loop * BASE_INPUT));
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, 2 * QUOTE_RESERVE);
        vm.stopPrank();

        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        (uint256 shares1, uint256 baseInput1, uint256 quoteInput1) = gsp.buyShares(USER);
        dai.transfer(address(dsp), BASE_RESERVE);
        usdc.transfer(address(dsp), QUOTE_RESERVE);
        (uint256 shares2, uint256 baseInput2, uint256 quoteInput2) = dsp.buyShares(USER);
        assertEq(shares1, shares2, "gsp shares != dsp shares");
        assertEq(baseInput1, baseInput2, "gsp baseInput != dsp baseInput");
        assertEq(quoteInput1, quoteInput2, "gsp quoteInput != dsp quoteInput");

        uint256 receiveQuoteAmount1;
        uint256 receiveQuoteAmount2;
        uint256 baseReserve1;
        uint256 quoteReserve1;
        uint256 baseReserve2;
        uint256 quoteReserve2;
        uint256 mtFee1;
        uint256 mtFee2;
        // sell base
        uint256 mtFeeBefore = usdc.balanceOf(MAINTAINER);
        for (uint i = 0; i < 2; i++) {
            dai.transfer(address(gsp), BASE_INPUT);
            receiveQuoteAmount1 = gsp.sellBase(USER);
            dai.transfer(address(dsp), BASE_INPUT);
            receiveQuoteAmount2 = dsp.sellBase(USER);
            assertEq(receiveQuoteAmount1, receiveQuoteAmount2, "gsp receiveQuoteAmount != dsp receiveQuoteAmount");

            // check baseReserve, quoteReserve
            (baseReserve1, quoteReserve1) = gsp.getVaultReserve();
            (baseReserve2, quoteReserve2) = dsp.getVaultReserve();
            assertEq(baseReserve1, baseReserve2, "gsp baseReserve != dsp baseReserve");
            assertEq(quoteReserve1, quoteReserve2, "gsp quoteReserve != dsp quoteReserve");

            // check mtFee
            mtFee1 = gsp._MT_FEE_QUOTE_();
            uint256 mtFeeAfter = usdc.balanceOf(MAINTAINER);
            mtFee2 = mtFeeAfter.sub(mtFeeBefore);
            assertEq(mtFee1, mtFee2, "gsp mtFee != dsp mtFee");
        }  
    }


    function test_SellQuote() public {
        uint256 loop = 2;
        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, 2 * BASE_RESERVE);
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, 2 * (QUOTE_RESERVE + loop * QUOTE_INPUT));
        vm.stopPrank();

        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        (uint256 shares1, uint256 baseInput1, uint256 quoteInput1) = gsp.buyShares(USER);
        dai.transfer(address(dsp), BASE_RESERVE);
        usdc.transfer(address(dsp), QUOTE_RESERVE);
        (uint256 shares2, uint256 baseInput2, uint256 quoteInput2) = dsp.buyShares(USER);
        assertEq(shares1, shares2, "gsp shares != dsp shares");
        assertEq(baseInput1, baseInput2, "gsp baseInput != dsp baseInput");
        assertEq(quoteInput1, quoteInput2, "gsp quoteInput != dsp quoteInput");

        uint256 receiveBaseAmount1;
        uint256 receiveBaseAmount2;
        uint256 baseReserve1;
        uint256 quoteReserve1;
        uint256 baseReserve2;
        uint256 quoteReserve2;
        uint256 mtFee1;
        uint256 mtFee2;
        // sell quote
        uint256 mtFeeBefore = dai.balanceOf(MAINTAINER);
        for (uint i = 0; i < 2; i++) {
            usdc.transfer(address(gsp), QUOTE_INPUT);
            receiveBaseAmount1 = gsp.sellQuote(USER);
            usdc.transfer(address(dsp), QUOTE_INPUT);
            receiveBaseAmount2 = dsp.sellQuote(USER);
            assertEq(receiveBaseAmount1, receiveBaseAmount2, "gsp receiveBaseAmount != dsp receiveBaseAmount");

            // check baseReserve, quoteReserve
            (baseReserve1, quoteReserve1) = gsp.getVaultReserve();
            (baseReserve2, quoteReserve2) = dsp.getVaultReserve();
            assertEq(baseReserve1, baseReserve2, "gsp baseReserve != dsp baseReserve");
            assertEq(quoteReserve1, quoteReserve2, "gsp quoteReserve != dsp quoteReserve");

            // check mtFee
            mtFee1 = gsp._MT_FEE_BASE_();
            uint256 mtFeeAfter = dai.balanceOf(MAINTAINER);
            mtFee2 = mtFeeAfter.sub(mtFeeBefore);
            assertEq(mtFee1, mtFee2, "gsp mtFee != dsp mtFee");
        }  
    }


    function test_CompareTwoPools() public {
        // check PMMState
        gsp.getPMMState();
        dsp.getPMMState();

        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, 2 * (BASE_RESERVE + BASE_INPUT));
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, 2 * (QUOTE_RESERVE + QUOTE_INPUT));
        vm.stopPrank();

        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        (uint256 shares1, uint256 baseInput1, uint256 quoteInput1) = gsp.buyShares(USER);
        dai.transfer(address(dsp), BASE_RESERVE);
        usdc.transfer(address(dsp), QUOTE_RESERVE);
        (uint256 shares2, uint256 baseInput2, uint256 quoteInput2) = dsp.buyShares(USER);
        vm.stopPrank();
        assertEq(shares1, shares2, "gsp shares != dsp shares");
        assertEq(baseInput1, baseInput2, "gsp baseInput != dsp baseInput");
        assertEq(quoteInput1, quoteInput2, "gsp quoteInput != dsp quoteInput");

        // sellbase and sellquote
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_INPUT);
        uint256 receiveQuoteAmount1 = gsp.sellBase(USER);
        dai.transfer(address(dsp), BASE_INPUT);
        uint256 receiveQuoteAmount2 = dsp.sellBase(USER);
        assertEq(receiveQuoteAmount1, receiveQuoteAmount2, "gsp receiveQuoteAmount != dsp receiveQuoteAmount");

        usdc.transfer(address(gsp), QUOTE_INPUT);
        uint256 receiveBaseAmount1 = gsp.sellQuote(USER);
        usdc.transfer(address(dsp), QUOTE_INPUT);
        uint256 receiveBaseAmount2 = dsp.sellQuote(USER);
        assertEq(receiveBaseAmount1, receiveBaseAmount2, "gsp receiveBaseAmount != dsp receiveBaseAmount");
        vm.stopPrank();

        // check baseReserve, quoteReserve
        (uint256 baseReserve1, uint256 quoteReserve1) = gsp.getVaultReserve();
        (uint256 baseReserve2, uint256 quoteReserve2) = dsp.getVaultReserve();
        assertEq(baseReserve1, baseReserve2, "gsp baseReserve != dsp baseReserve");
        assertEq(quoteReserve1, quoteReserve2, "gsp quoteReserve != dsp quoteReserve");

        // burn shares
        vm.startPrank(USER);
        (uint256 baseAmount1, uint256 quoteAmount1) = gsp.sellShares(gsp.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        (uint256 baseAmount2, uint256 quoteAmount2) = dsp.sellShares(dsp.balanceOf(USER), USER, 0, 0, "", block.timestamp);
        vm.stopPrank();
        assertEq(baseAmount1, baseAmount2, "gsp baseAmount != dsp baseAmount");
        assertEq(quoteAmount1, quoteAmount2, "gsp quoteAmount != dsp quoteAmount");
    } 


    function test_Flashloan() public {
        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, 2 * (BASE_RESERVE + BASE_INPUT));
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, 2 * QUOTE_RESERVE);
        vm.stopPrank();

        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        (uint256 shares1, uint256 baseInput1, uint256 quoteInput1) = gsp.buyShares(USER);
        dai.transfer(address(dsp), BASE_RESERVE);
        usdc.transfer(address(dsp), QUOTE_RESERVE);
        (uint256 shares2, uint256 baseInput2, uint256 quoteInput2) = dsp.buyShares(USER);
        assertEq(shares1, shares2, "gsp shares != dsp shares");
        assertEq(baseInput1, baseInput2, "gsp baseInput != dsp baseInput");
        assertEq(quoteInput1, quoteInput2, "gsp quoteInput != dsp quoteInput");

        // flashloan
        (uint256 amountQuote1, , ,) = gsp.querySellBase(USER, BASE_INPUT);
        (uint256 amountQuote2, , ,) = dsp.querySellBase(USER, BASE_INPUT);
        assertEq(amountQuote1, amountQuote2, "amountQuote1 != amountQuote2");

        uint256 quoteBalanceBefore = usdc.balanceOf(USER);
        dai.transfer(address(gsp), BASE_INPUT);
        dai.transfer(address(dsp), BASE_INPUT);
        gsp.flashLoan(0, amountQuote1, USER, "");
        dsp.flashLoan(0, amountQuote2, USER, "");
        uint256 quoteBalanceAfter = usdc.balanceOf(USER);
        assertEq(quoteBalanceBefore + amountQuote1 + amountQuote2, quoteBalanceAfter, "Flashloan failed");
        vm.stopPrank();
    }
}
