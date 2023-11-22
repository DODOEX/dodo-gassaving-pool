// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

import {Deploy} from "../scripts/Deploy.s.sol";

import {DSP} from "../contracts/DSPAdvanced/impl/DSP.sol"; 
import {IDSP} from "../contracts/DSPAdvanced/intf/IDSP.sol";
import {IERC20} from "../contracts/intf/IERC20.sol";


contract StableSwap is Script {

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC20 private dai = IERC20(DAI);
    IERC20 private usdc = IERC20(USDC);

    address constant USDC_WHALE = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;
    address constant DAI_WHALE = 0x25B313158Ce11080524DcA0fD01141EeD5f94b81;
    address LP = vm.addr(1);

    Deploy deploy = new Deploy();
    IDSP constant dsp = IDSP(0x3058EF90929cb8180174D74C507176ccA6835D73); // DAI-USDT
    DSP dspAdvanced = deploy.run(); // DAI-USDC

    function addLiquidity() external {
        // provide liquidity to DSPAdvanced
        (uint256 baseReserve, uint256 quoteReserve) = dsp.getVaultReserve();

        // whales send tokens to LP
        vm.startPrank(DAI_WHALE);
        dai.transfer(LP, baseReserve);
        vm.stopPrank();

        vm.startPrank(USDC_WHALE);
        usdc.transfer(LP, quoteReserve);
        vm.stopPrank();

        // LP provide liquidity to DSPAdvanced
        vm.startPrank(LP);
        dai.transfer(address(dspAdvanced), baseReserve);
        usdc.transfer(address(dspAdvanced), quoteReserve);
        dspAdvanced.buyShares(msg.sender);
        vm.stopPrank();
        
        console.log("baseReserve: %s", dspAdvanced._BASE_RESERVE_());
        console.log("quoteReserve: %s", dspAdvanced._QUOTE_RESERVE_());
    }


    function dsp_sellBase(address tokenIn, uint256 amount, address to) external returns (uint256) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenIn).transfer(address(dsp), amount);
        return dsp.sellBase(to);
    }

    function dspAdvanced_sellBase(address tokenIn, uint256 amount, address to) external returns (uint256) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenIn).transfer(address(dspAdvanced), amount);
        return dspAdvanced.sellBase(to);
    }
}