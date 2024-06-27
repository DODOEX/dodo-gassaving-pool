/*
    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0
*/

pragma solidity 0.8.16;

interface IOracle {
    function prices(address base) external view returns (uint256);
}

interface ISftWrappedToken {
    function getValueByShares(uint256 shares) external view returns (uint256 value);
    function underlyingAsset() external view returns (address);
}

interface IERC20 {
    function decimals() external view returns(uint8);
}

contract SolvOracleAdapter is IOracle {

    function prices(address base) external view override returns (uint256 price) {
        uint256 shares = 1e18;
        uint256 value = ISftWrappedToken(base).getValueByShares(shares);
        price = value / 1;
        (uint256 decimalCorrect, bool multiplyOrNot) = getDecimalCorrect(base);
        if(decimalCorrect > 0) {
            price = multiplyOrNot ? price * (10 ** decimalCorrect) : price / (10 ** decimalCorrect);
        }
    }

    function getDecimalCorrect(address base) public view returns (uint256 decimalCorrect, bool multiplyOrNot) {
        address underlyingAsset = ISftWrappedToken(base).underlyingAsset();
        uint256 decimals = IERC20(underlyingAsset).decimals();

        if(18 > decimals) {
            decimalCorrect = 18 - decimals;
            multiplyOrNot = true;
        } else if(18 == decimals) {
            decimalCorrect = 0;
            multiplyOrNot = true;
        } else if(18 < decimals) {
            decimalCorrect = decimals - 18;
            multiplyOrNot = false;
        }
    }

    function getUnderlyingAsset(address base) public view returns(address asset, uint256 dec) {
        asset = ISftWrappedToken(base).underlyingAsset();
        dec = IERC20(asset).decimals();
    }
}