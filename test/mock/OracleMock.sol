// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import {IOracle} from "../../contracts/GasSavingPool/intf/IOracle.sol";

contract OracleMock is IOracle{
    uint256 public _PRICE_ = 1e18;

    function setPrice(uint256 price) external {
        _PRICE_ = price;
    }

    function prices(address base) external override view returns (uint256) {
        return _PRICE_;
    }
}