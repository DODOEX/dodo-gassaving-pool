/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

interface IGSP {
    function init(
        address maintainer,
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        uint256 mtFeeRate,
        uint256 i,
        uint256 k,
        bool isOpenTWAP
    ) external;

    function _BASE_TOKEN_() external view returns (address);

    function _QUOTE_TOKEN_() external view returns (address);

    function _I_() external view returns (uint256);

    function _MT_FEE_RATE_MODEL_() external view returns (address); // Useless, just for compatibility

    function getVaultReserve() external view returns (uint256 baseReserve, uint256 quoteReserve);

    function getUserFeeRate(address user) external view returns (uint256 lpFeeRate, uint256 mtFeeRate);

    function getMtFeeTotal() external view returns (uint256 mtFeeBase, uint256 mtFeeQuote);

    function sellBase(address to) external returns (uint256);

    function sellQuote(address to) external returns (uint256);

    function buyShares(address to) external returns (uint256 shares, uint256 baseInput, uint256 quoteInput);

    function sellShares(uint256 shareAmount, address to, uint256 baseMinAmount, uint256 quoteMinAmount, bytes calldata data, uint256 deadline) external returns (uint256 baseAmount, uint256 quoteAmount);
}
