// SPDX-License-Identifier: MIT

pragma solidity 0.6.10;

import {Test, console} from "forge-std/Test.sol";

import {Deploy} from "../scripts/Deploy.s.sol";
import {DSP} from "../contracts/DSPAdvanced/impl/DSP.sol";
import {IERC20} from "../contracts/intf/IERC20.sol";

contract TestDSPAdvanced is Test {
    DSP dspAdvanced;

    address constant MAINTAINER = 0x95C4F5b83aA70810D4f142d58e5F7242Bd891CB0;
    address USER = vm.addr(1);

    function setUp() public {
        // Deploy and Init DSPAdvanced
        Deploy deploy = new Deploy();
        dspAdvanced = deploy.run();
    }

    // ======== Set MtFeeRate =========

    function testFail_UserCannotChangeMtFeeRate() public {
        uint256 newMtFeeRate = 20000000000000;

        vm.startPrank(USER);
        dspAdvanced.setMtFeeRate(newMtFeeRate);
    }

    function test_OnlyMaintainerCanSetMtFeeRate() public {
        uint256 newMtFeeRate = 20000000000000;

        vm.startPrank(MAINTAINER);
        uint256 mtFeeRateBefore = dspAdvanced._MT_FEE_RATE_();
        console.log("mtFeeRateBefore: %s", mtFeeRateBefore);
        dspAdvanced.setMtFeeRate(newMtFeeRate);
        uint256 mtFeeRateAfter = dspAdvanced._MT_FEE_RATE_();
        console.log("mtFeeRateAfter: %s", mtFeeRateAfter);
        vm.stopPrank();
        assertTrue(mtFeeRateAfter == newMtFeeRate);
    }

    // ======== Set NewPrice =========

    function testFail_UserCannotSetNewPrice() public {
        uint256 newPrice = 1000000000000000000;

        vm.startPrank(USER);
        dspAdvanced.setNewPrice(newPrice);
    }

    function test_OnlyMaintainerCanSetNewPrice() public {
        uint256 newPrice = 1000000000000000000;

        vm.startPrank(MAINTAINER);
        uint256 priceBefore = dspAdvanced._BASE_PRICE_CUMULATIVE_LAST_();
        console.log("priceBefore: %s", priceBefore);
        dspAdvanced.setNewPrice(newPrice);
        uint256 priceAfter = dspAdvanced._BASE_PRICE_CUMULATIVE_LAST_();
        console.log("priceAfter: %s", priceAfter);
        vm.stopPrank();
        assertTrue(priceAfter == newPrice);
    }

    function testFuzz_NewPriceShouldInPriceLimit(uint256 newPrice) public {
        uint256 currentPrice = dspAdvanced._I_();
        vm.startPrank(MAINTAINER);
        dspAdvanced.setNewPrice(newPrice);
        vm.stopPrank();
    }






}
