// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;
pragma abicoder v2;

import {Test, console} from "forge-std/Test.sol";
import {DeployGSP} from "../scripts/DeployGSP.s.sol";
import {GSP} from "../contracts/GasSavingPool/impl/GSP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "mock/MockERC20.sol";

contract TestGSPVault is Test {
    GSP gsp;
    MockERC20 mockBaseToken;
    MockERC20 mockQuoteToken;

    address USER = vm.addr(1);
    address OTHER = vm.addr(2);
    address constant USDC_WHALE = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;
    address constant DAI_WHALE = 0x25B313158Ce11080524DcA0fD01141EeD5f94b81;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    IERC20 private usdc = IERC20(USDC);
    IERC20 private dai = IERC20(DAI);

    // Init Params
    address constant MAINTAINER = 0x95C4F5b83aA70810D4f142d58e5F7242Bd891CB0;
    address constant ADMIN = address(1);
    uint256 constant LP_FEE_RATE = 0;
    uint256 constant MT_FEE_RATE = 10000000000000;
    uint256 constant I = 1000000;

    // Test Params
    uint256 constant BASE_RESERVE = 1e19; // 10 DAI
    uint256 constant QUOTE_RESERVE = 1e7; // 10 USDC
    uint256 constant BASE_INPUT = 1e18; // 1 DAI
    uint256 constant QUOTE_INPUT = 2e6; // 2 USDC

    function setUp() public {
        // Deploy and Init 
        DeployGSP deployGSP = new DeployGSP();
        gsp = deployGSP.runAdminDiff();

        // Deploy ERC20 Mock
        mockBaseToken = new MockERC20("mockBaseToken", "mockBaseToken", 18);
        mockBaseToken.mint(USER, type(uint256).max);
        mockQuoteToken = new MockERC20("mockQuoteToken", "mockQuoteToken", 18);
        mockQuoteToken.mint(USER, type(uint256).max);
    }

    function testGetVaultReserve() public {
        (uint256 baseReserve, uint256 quoteReserve) = gsp.getVaultReserve();
        assertTrue(baseReserve == 0);
        assertTrue(quoteReserve == 0);
    }

    function testGetUserFeeRate() public {
        (uint256 lpFeeRate, uint256 mtFeeRate) = gsp.getUserFeeRate(msg.sender);
        assertTrue(lpFeeRate == LP_FEE_RATE);
        assertTrue(mtFeeRate == MT_FEE_RATE);
    }

    function testOnlyMaintainerCanAdjustParams() public {
        vm.startPrank(ADMIN);
        // adjust price limit
        gsp.adjustPriceLimit(1e4);
        assertEq(gsp._PRICE_LIMIT_(), 1e4);

        // adjust price
        uint256 priceBefore = gsp._I_();
        assertTrue(priceBefore == I);
        gsp.adjustPrice((1e6 + 1e4));
        uint256 priceAfter = gsp._I_();
        assertTrue(priceAfter == (1e6 + 1e4));
        vm.stopPrank();
       
       // adjust mtfee rate
        uint256 mtFeeRateBefore = gsp._MT_FEE_RATE_();
        assertTrue(mtFeeRateBefore == MT_FEE_RATE);
        vm.prank(MAINTAINER);
        gsp.adjustMtFeeRate(2e13);
        uint256 mtFeeRateAfter = gsp._MT_FEE_RATE_();
        assertTrue(mtFeeRateAfter == 2e13);
    }

    function testSyncSucceed() public {
        GSP gspTest = new GSP();
        gspTest.init(
            MAINTAINER,
            MAINTAINER,
            address(mockBaseToken),
            address(mockQuoteToken),
            0,
            0,
            1000000,
            500000000000000,
            true
        );
        (uint256 baseReserve, uint256 quoteReserve) = gspTest.getVaultReserve();
        assertTrue(baseReserve == 0);
        assertTrue(quoteReserve == 0);
        vm.startPrank(USER);
        mockBaseToken.transfer(address(gspTest), 1e18);
        gspTest.sync();
        (baseReserve, quoteReserve) = gspTest.getVaultReserve();
        assertTrue(baseReserve == 1e18);
    }

    function testSyncOverflow() public {
        GSP gspTest = new GSP();
        gspTest.init(
            MAINTAINER,
            MAINTAINER,
            address(mockBaseToken),
            address(mockQuoteToken),
            0,
            0,
            1000000,
            500000000000000,
            true
        );
        vm.startPrank(USER);
        mockBaseToken.transfer(address(gspTest), type(uint256).max);
        mockQuoteToken.transfer(address(gspTest), type(uint256).max);
        vm.expectRevert("OVERFLOW");
        gspTest.sync();
    }

    function testWithdrawMtFeeTotal() public {
        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, (BASE_RESERVE + BASE_INPUT));
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, QUOTE_RESERVE);
        vm.stopPrank();
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        gsp.buyShares(USER);
        vm.stopPrank();
        // sellbase
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_INPUT);
        gsp.sellBase(USER);
        vm.stopPrank();
        // withdraw mtfee
        vm.startPrank(MAINTAINER);
        uint256 daiBalanceBefore = dai.balanceOf(MAINTAINER);
        uint256 mtFeeBaseBefore = gsp._MT_FEE_BASE_();
        gsp.withdrawMtFeeTotal();
        uint256 mtFeeBaseAfter = gsp._MT_FEE_BASE_();
        uint256 daiBalanceAfter = dai.balanceOf(MAINTAINER);
        assertTrue(mtFeeBaseAfter == 0);
        assertEq(daiBalanceAfter - daiBalanceBefore, mtFeeBaseBefore - mtFeeBaseAfter);
    }

    function testCorrectRState() public {
        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, BASE_RESERVE + BASE_INPUT);
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, QUOTE_RESERVE + QUOTE_INPUT);
        vm.stopPrank();
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        gsp.buyShares(USER);
        // sellbase
        gsp.sellBase(USER);
        gsp.getPMMState();
        vm.stopPrank();
        // set B < B0
        vm.startPrank(address(gsp));
        dai.approve(USER, BASE_INPUT);
        vm.stopPrank();
        vm.startPrank(USER);
        dai.transferFrom(address(gsp), USER, BASE_INPUT);
        gsp.sync();
        gsp.correctRState();
        gsp.getPMMState();
        assertTrue(gsp._BASE_TARGET_() == gsp._BASE_RESERVE_());
        assertTrue(gsp._QUOTE_TARGET_() == gsp._QUOTE_RESERVE_());
        // sellquote
        vm.startPrank(USER);
        gsp.sellQuote(USER);
        gsp.getPMMState();
        vm.stopPrank();
        // set Q < Q0
        vm.startPrank(address(gsp));
        usdc.approve(USER, QUOTE_INPUT);
        vm.stopPrank();
        vm.startPrank(USER);
        usdc.transferFrom(address(gsp), USER, QUOTE_INPUT);
        gsp.sync();
        gsp.correctRState();
        gsp.getPMMState();
        assertTrue(gsp._BASE_TARGET_() == gsp._BASE_RESERVE_());
        assertTrue(gsp._QUOTE_TARGET_() == gsp._QUOTE_RESERVE_());
    }

    function testPermitSucceed() public {
        uint256 userPrivateKey = 1;
        vm.startPrank(USER);
        uint256 value = gsp.balanceOf(USER);
        uint256 deadline = block.timestamp + 100000;
        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    gsp.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            gsp.PERMIT_TYPEHASH(),
                            USER,
                            OTHER,
                            value,
                            gsp.nonces(USER),
                            deadline
                        )
                    )
                )
            );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        gsp.permit(USER, OTHER, value, deadline, v, r, s);
    }

    function testPermitWithInvalidSignature() public {
        uint256 otherPrivateKey = 2;
        vm.startPrank(OTHER);
        uint256 value = gsp.balanceOf(USER);
        uint256 deadline = block.timestamp + 100000;
        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    gsp.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            gsp.PERMIT_TYPEHASH(),
                            USER,
                            OTHER,
                            value,
                            gsp.nonces(USER),
                            deadline
                        )
                    )
                )
            );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherPrivateKey, digest);
        vm.expectRevert("DODO_GSP_LP: INVALID_SIGNATURE");
        gsp.permit(USER, OTHER, value, deadline, v, r, s);
    }

    function testPermitWhenTimeExpired() public {
        uint256 value = gsp.balanceOf(USER);
        uint256 privKey = 1;
        uint256 deadline = block.timestamp - 100000;
        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    gsp.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            gsp.PERMIT_TYPEHASH(),
                            USER,
                            OTHER,
                            value,
                            gsp.nonces(USER),
                            deadline
                        )
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        vm.expectRevert("DODO_GSP_LP: EXPIRED");
        gsp.permit(USER, OTHER, value, deadline, v, r, s);
    }


    function testAdjustPriceLimitIsInvalid() public{
        vm.startPrank(ADMIN);
        vm.expectRevert("INVALID_PRICE_LIMIT");
        gsp.adjustPriceLimit(1e7);
    }
    
    function testAdjustPriceExceedPriceLimit() public{
        vm.startPrank(ADMIN);
        vm.expectRevert("EXCEED_PRICE_LIMIT");
        gsp.adjustPrice((2e6));
    }

    function testAdjustMtFeeRateIsInvalid() public{
        vm.startPrank(MAINTAINER);
        vm.expectRevert("INVALID_MT_FEE_RATE");
        gsp.adjustMtFeeRate(2e19);
    }

    function testTransferSharesWhenBalanceIsNotEnough() public{
        vm.startPrank(USER);
        vm.expectRevert("BALANCE_NOT_ENOUGH");
        gsp.transfer(OTHER, 1e18);
    }

    function testTransferFromSharesWhenBalanceIsNotEnough() public{
        vm.startPrank(OTHER);
        vm.expectRevert("BALANCE_NOT_ENOUGH");
        gsp.transferFrom(USER, OTHER, 1e18);
    }

    function testTransferFromSharesWhenAllowanceIsNotEnough() public{
        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, BASE_RESERVE);
        vm.stopPrank();
        vm.startPrank(USDC_WHALE);
        usdc.transfer(USER, QUOTE_RESERVE);
        vm.stopPrank();
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        usdc.transfer(address(gsp), QUOTE_RESERVE);
        gsp.buyShares(USER);
        vm.stopPrank();

        vm.startPrank(OTHER);
        uint256 amount = gsp.balanceOf(USER);
        vm.expectRevert("ALLOWANCE_NOT_ENOUGH");
        gsp.transferFrom(USER, OTHER, amount);
    }

    function testBuySharesWithOnlyBaseInput() public {
        // buy shares
        vm.startPrank(DAI_WHALE);
        dai.transfer(USER, BASE_RESERVE);
        vm.stopPrank();
        vm.startPrank(USER);
        dai.transfer(address(gsp), BASE_RESERVE);
        vm.expectRevert("ZERO_QUOTE_AMOUNT");
        gsp.buyShares(USER);
    }

    function testShouldNotBeZero() public {
        GSP gspTest = new GSP();
        gspTest.init(
            MAINTAINER,
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
        mockBaseToken.transfer(address(gspTest), 1e19);
        mockQuoteToken.transfer(address(gspTest), 1e19);
        gspTest.buyShares(USER);
        // try to drain quote reserve
        mockBaseToken.transfer(address(gspTest), 5000000000 * gspTest._BASE_RESERVE_());
        vm.expectRevert("DODOMath: should not be 0");
        gspTest.sellBase(USER);
        vm.stopPrank();
    }

    function testIntialQuoteTargetCannotBeZero() external {
        vm.startPrank(USER);
        deal(DAI, USER, 1e5);
        deal(USDC, USER, 1e5);
        // transfer a small value to set Q0 = 0
        dai.transfer(address(gsp), 1e5);
        usdc.transfer(address(gsp), 1e5);
        vm.expectRevert("QUOTE_TARGET_IS_ZERO");
        gsp.buyShares(USER);
    }
}