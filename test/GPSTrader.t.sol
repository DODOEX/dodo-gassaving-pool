// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;
pragma abicoder v2;

import {Test, console} from "forge-std/Test.sol";
import {DeployGSP} from "../scripts/DeployGSP.s.sol";
import {GSP} from "../contracts/GasSavingPool/impl/GSP.sol";
import {PMMPricing} from "../contracts/lib/PMMPricing.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "mock/MockERC20.sol";

contract TestGSPTrader is Test {
    GSP gsp;
    MockERC20 mockBaseToken;
    MockERC20 mockQuoteToken;

    // Test Params
    address USER = vm.addr(1);
    address OTHER = vm.addr(2);
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
    address MAINTAINER = 0x95C4F5b83aA70810D4f142d58e5F7242Bd891CB0;

    function setUp() public {
        // Deploy and Init 
        DeployGSP deployGSP = new DeployGSP();
        gsp = deployGSP.run();

        // Deploy ERC20 Mock
        mockBaseToken = new MockERC20("mockBaseToken", "mockBaseToken", 18);
        mockBaseToken.mint(USER, type(uint256).max);
        mockQuoteToken = new MockERC20("mockQuoteToken", "mockQuoteToken", 18);
        mockQuoteToken.mint(USER, type(uint256).max);
    }

    function test_updateTargetOverflow() public {
        GSP gspTest = new GSP();
        gspTest.init(
            MAINTAINER,
            address(mockBaseToken),
            address(mockQuoteToken),
            0,
            0,
            1000000,
            500000000000000,
            false
        );
        vm.startPrank(USER);
        mockBaseToken.transfer(address(gspTest), type(uint112).max);
        mockQuoteToken.transfer(address(gspTest), type(uint112).max);
        gspTest.buyShares(USER);
       
        ( , , , uint256 newBaseTarget) = gspTest.querySellBase(USER, 2e18);
        console.log("newBaseTarget", newBaseTarget);
        console.log("type(uint112).max", type(uint112).max);
        // mockBaseToken.transfer(address(gspTest), type(uint112).max);
        // vm.expectRevert("OVERFLOW");
        // gspTest.sellBase(USER);
        vm.stopPrank();
    }

    function test_sellBase() public {
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

    function test_flashloanSellBaseCaseFail() public {
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

        // flashloan - sellbase
        (uint256 amountQuote, , ,) = gsp.querySellBase(USER, BASE_INPUT);
        dai.transfer(address(gsp), BASE_INPUT);
        vm.expectRevert("FLASH_LOAN_FAILED");
        gsp.flashLoan(0, amountQuote + 1e6, USER, "");
        vm.stopPrank();
    }

    function test_flashloanSellQuoteCaseFail() public {
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

        // flashloan - sellquote
        (uint256 amountBase, , ,) = gsp.querySellQuote(USER, QUOTE_INPUT);
        usdc.transfer(address(gsp), QUOTE_INPUT);
        vm.expectRevert("FLASH_LOAN_FAILED");
        gsp.flashLoan(amountBase + 1e18, 0, USER, "");
    }

    function test_flashloanWithNoInputFail() public {
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

        // no input
        vm.startPrank(USER);
        vm.expectRevert("FLASH_LOAN_FAILED");
        gsp.flashLoan(1e18, 1e7, USER, "");
    }

    function test_flashloanDataIsNotEmpty() public {
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

        // flashloan - sellbase
        vm.startPrank(USER);
        (uint256 amountQuote, , ,) = gsp.querySellBase(USER, BASE_INPUT);
        dai.transfer(address(gsp), BASE_INPUT);
        vm.expectRevert();
        gsp.flashLoan(0, amountQuote, USER, "Test");
        vm.stopPrank();
    }

    function test_sellLargeAmountQuoteAndSellZeroBase() public {
        address hacker = vm.addr(3);
        vm.startPrank(USER);
        uint256 _amount = 99951 * 1e18;

        //  Buy shares with USER, 10 - 10 initiate the pool
        deal(DAI, USER, 10 * 1e18);
        deal(USDC, USER, 10 * 1e6);
        dai.transfer(address(gsp), 10 * 1e18);
        usdc.transfer(address(gsp), 10 * 1e6);
        gsp.buyShares(USER);

        logGspState();
        vm.stopPrank();
        
        vm.startPrank(hacker);
        
        deal(USDC, hacker, _amount);
        logBalance(hacker);
        usdc.transfer(address(gsp), _amount);
        gsp.sellQuote(hacker); // sell large amount of Quote token
        
        logGspState();
        logBalance(hacker);

        vm.expectRevert("TARGET_IS_ZERO");
        gsp.sellBase(hacker); // sell 0 amount of Base token
        
        logGspState();
        logBalance(hacker);
        
        vm.stopPrank();
    }

function logGspState() public view {
        PMMPricing.PMMState memory state = gsp.getPMMState();
        console.log("B0", state.B0);
        console.log("B", state.B);
        console.log("Q0", state.Q0);
        console.log("Q", state.Q);
        console.log("R", uint32(state.R));
        console.log();
    }

    function logBalance(address user) public view {
        console.log("dai balance", dai.balanceOf(user));
        console.log("usdc balance", usdc.balanceOf(user));
        console.log();
    }

    function test_FirstDepositorCanBrickThePool() external {
        address tapir = vm.addr(3);
        address hippo = vm.addr(4);
        deal(DAI, tapir, 1000 * 1e18);
        deal(USDC, tapir, 1000 * 1e6);

        // tapir deposits tiny amounts to grief, important is that tapir deposits 0 quote tokens!
        vm.startPrank(tapir);
        dai.transfer(address(gsp), 1001);
        usdc.transfer(address(gsp), 0);
        gsp.buyShares(tapir);

        console.log("Base target", gsp._BASE_TARGET_());
        console.log("Quote target", gsp._QUOTE_TARGET_());
        console.log("Base reserve", gsp._BASE_RESERVE_());
        console.log("Quote reserve", gsp._QUOTE_RESERVE_());
        console.log("Tapirs shares", gsp.balanceOf(tapir));

        vm.stopPrank();

        deal(DAI, hippo, 2000 * 1e18);
        deal(USDC, hippo, 2000 * 1e6);
        vm.startPrank(hippo);

        // hippo wants to deposits properly, but it will fail because of the minimum mint value!
        dai.transfer(address(gsp), 2000 * 1e18);
        usdc.transfer(address(gsp), 2000 * 1e6);
        vm.expectRevert("MINT_AMOUNT_NOT_ENOUGH");
        gsp.buyShares(hippo);
    }

    function test_StartWithZeroTarget() external {
        address tapir = vm.addr(3);
        address hippo = vm.addr(4);
        deal(DAI, tapir, 10 * 1e18);
        deal(USDC, tapir, 10 * 1e6);
        // tapir deposits tiny amounts to make quote target 0
        vm.startPrank(tapir);
        dai.transfer(address(gsp), 1 * 1e5);
        usdc.transfer(address(gsp), 1 * 1e5);
        gsp.buyShares(tapir);
        logGspState();

        // quote target is indeed 0!
        assertEq(gsp._QUOTE_TARGET_(), 0);

        vm.stopPrank();

        // hippo deposits properly
        deal(DAI, hippo, 1000 * 1e18);
        deal(USDC, hippo, 10000 * 1e6);

        vm.startPrank(hippo);
        dai.transfer(address(gsp), 1000 * 1e18);
        usdc.transfer(address(gsp), 10000 * 1e6);
        gsp.buyShares(hippo);

        // although hippo deposited 1000 USDC as quote tokens, target is still 0 due to multiplication with 0
        assertEq(gsp._QUOTE_TARGET_(), 0);
        logGspState();
        vm.stopPrank();

        deal(DAI, USER, 10 * 1e18);
        vm.startPrank(USER);
        dai.transfer(address(gsp), 10 * 1e18);
        gsp.sellBase(USER);
        logGspState();

    }
}

