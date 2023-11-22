// SPDX-License-Identifier: MIT

pragma solidity 0.6.10;

import {Test, console} from "forge-std/Test.sol";

import {StableSwap} from "../scripts/StableSwap.s.sol";

import {Deploy} from "../scripts/Deploy.s.sol";
import {DSP} from "../contracts/DSPAdvanced/impl/DSP.sol";
import {IDSP} from "../contracts/DSPAdvanced/intf/IDSP.sol";
import {IERC20} from "../contracts/intf/IERC20.sol";

contract TestGasFee is Test {
    StableSwap stableSwap;
    address constant USDC_WHALE = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;
    address constant DAI_WHALE = 0x25B313158Ce11080524DcA0fD01141EeD5f94b81;

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    IERC20 private dai = IERC20(DAI);

    uint256 constant AMOUNT_IN = 1e18;

    function setUp() public {
       stableSwap = new StableSwap();
    }

    function test_GasFee() public {
        stableSwap.addLiquidity();

        vm.startPrank(DAI_WHALE);
        dai.approve(address(stableSwap), type(uint256).max);
        uint256 amountOut1 = stableSwap.dsp_sellBase(DAI, AMOUNT_IN, address(this));
        dai.approve(address(stableSwap), type(uint256).max);
        uint256 amountOut2 = stableSwap.dspAdvanced_sellBase(DAI, AMOUNT_IN, address(this));
        vm.stopPrank();

        console.log("DSP: receive USDT amount", amountOut1);
        console.log("DSPAdvanced: receive USDC amount", amountOut2);
    }
    
}