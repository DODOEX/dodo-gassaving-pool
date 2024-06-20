/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import {IOracle} from "../intf/IOracle.sol";

interface ISftWrappedToken {
    function getValueByShares(uint256 shares) external view returns (uint256 value);
}

contract SolvOracleAdapter is IOracle {
    ISftWrappedToken public sftWrappedToken;

    function prices(address base) external override returns (uint256 price) {
        uint256 shares = 1e18;
        sftWrappedToken = ISftWrappedToken(base);
        uint256 value = sftWrappedToken.getValueByShares(shares);
        price = value / 1;
    }
}