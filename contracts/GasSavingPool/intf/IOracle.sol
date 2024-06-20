/*

    Copyright 2021 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

interface IOracle {
    function prices(address base) external returns (uint256);
}
