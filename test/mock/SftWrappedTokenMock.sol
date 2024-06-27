// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

contract SftWrappedTokenMock {
    uint256 public _PRICE_ = 1e18;
    
    function getValueByShares(uint256 shares) external view returns (uint256 value) {
        return _PRICE_;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}