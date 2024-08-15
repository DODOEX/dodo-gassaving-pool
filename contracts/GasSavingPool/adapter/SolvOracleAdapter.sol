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
    function getOracleDecimals() external view returns (uint8);
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
        uint256 decimals = uint256(ISftWrappedToken(base).getOracleDecimals());

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
}