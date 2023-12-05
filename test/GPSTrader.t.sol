// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;
pragma abicoder v2;

import {Test, console} from "forge-std/Test.sol";
import {DeployGSP} from "../scripts/DeployGSP.s.sol";
import {GSP} from "../contracts/GasSavingPool/impl/GSP.sol";
import {IERC20} from "../contracts/intf/IERC20.sol";

contract TestGSPTrader is Test {
    GSP gsp;

    // Test Params
    address USER = vm.addr(1);
    address constant USDC_WHALE = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;
    address constant DAI_WHALE = 0x25B313158Ce11080524DcA0fD01141EeD5f94b81;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    IERC20 private usdc = IERC20(USDC);
    IERC20 private dai = IERC20(DAI);

    uint256 constant BASE_RESERVE = 1e19; // 10 DAI
    uint256 constant QUOTE_RESERVE = 1e7; // 10 USDC
    uint256 constant BASE_INPUT = 1e18; // 1 DAI
    uint256 constant QUOTE_INPUT = 2e6; // 2 USDC

    function setUp() public {
        // Deploy and Init 
        DeployGSP deployGSP = new DeployGSP();
        gsp = deployGSP.run();

        // transfer some tokens to USER
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, BASE_RESERVE + BASE_INPUT);
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, QUOTE_RESERVE + QUOTE_INPUT);
        vm.stopPrank();

        // User buys shares
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        gsp.buyShares(USER);
        vm.stopPrank();
    }

    function test_RStateChange() public{
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, type(uint112).max);
        vm.stopPrank();
        vm.startPrank(USER);
        dai.transfer(address(gsp), type(uint112).max);
        vm.expectRevert("OVERFLOW");
        gsp.sellBase(USER);
    }

    function test_sellBase() public {
        // User sells base
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_INPUT);
        usdc.transfer(address(gsp), QUOTE_INPUT);
        uint256 baseInput = gsp.getBaseInput();
        uint256 quoteInput = gsp.getQuoteInput();
        gsp.sellBase(USER);
        vm.stopPrank();
        assertEq(baseInput, BASE_INPUT);
        assertEq(quoteInput, QUOTE_INPUT);
        
    }

    function test_flashloanFail() public {
        // flashloan - sellbase
        vm.startPrank(USER);
        vm.expectRevert("FLASH_LOAN_FAILED");
        gsp.flashLoan(1e18, 1e7, USER, "");

        // flashloan - sellquote
        (uint256 amountBase, , ,) = gsp.querySellQuote(USER, QUOTE_INPUT);
        usdc.transfer(address(gsp), QUOTE_INPUT);
        vm.expectRevert("FLASH_LOAN_FAILED");
        gsp.flashLoan(amountBase + 100, 0, USER, "");
        vm.stopPrank();
    }

    function test_flashloanDataIsNotEmpty() public {
        // flashloan - sellbase
        vm.startPrank(USER);
        (uint256 amountQuote, , ,) = gsp.querySellBase(USER, BASE_INPUT);
        dai.transfer(address(gsp), BASE_INPUT);
        vm.expectRevert();
        gsp.flashLoan(0, amountQuote, USER, "Test");
        vm.stopPrank();
    }
}