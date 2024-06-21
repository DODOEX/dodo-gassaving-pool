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

    function prices(address base) external view override returns (uint256 price) {
        uint256 shares = 1e18;
        uint256 value = ISftWrappedToken(base).getValueByShares(shares);
        price = value / 1;
    }
}