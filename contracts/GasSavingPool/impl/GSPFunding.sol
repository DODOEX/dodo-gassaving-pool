/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/


pragma solidity 0.8.16;

import {GSPVault} from "./GSPVault.sol";
import {DecimalMath} from "../../lib/DecimalMath.sol";
import {IDODOCallee} from "../../intf/IDODOCallee.sol";

/// @notice this part focus on Lp tokens, mint and burn
contract GSPFunding is GSPVault {
    // ============ Events ============

    event BuyShares(address to, uint256 increaseShares, uint256 totalShares);

    event SellShares(address payer, address to, uint256 decreaseShares, uint256 totalShares);

    // ============ Buy & Sell Shares ============

    /// @notice buy shares [round down], user mint Lp token and deposit tokens
    /// @return shares the amount of lp token
    /// @return baseInput the amount of base token user pay
    /// @return quoteInput the amount of quote token user pay
    function buyShares(address to)
        external
        nonReentrant
        returns (
            uint256 shares,
            uint256 baseInput,
            uint256 quoteInput
        )
    {
        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this)) - _MT_FEE_BASE_;
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this)) - _MT_FEE_QUOTE_;
        uint256 baseReserve = _BASE_RESERVE_;
        uint256 quoteReserve = _QUOTE_RESERVE_;

        baseInput = baseBalance - baseReserve;
        quoteInput = quoteBalance - quoteReserve;
        require(baseInput > 0, "NO_BASE_INPUT");

        // Round down when withdrawing. Therefore, never be a situation occuring balance is 0 but totalsupply is not 0
        // But May Happen，reserve >0 But totalSupply = 0
        if (totalSupply == 0) {
            // case 1. initial supply
            shares = quoteBalance < DecimalMath.mulFloor(baseBalance, _I_)
                ? DecimalMath.divFloor(quoteBalance, _I_)
                : baseBalance;
            _BASE_TARGET_ = uint112(shares);
            _QUOTE_TARGET_ = uint112(DecimalMath.mulFloor(shares, _I_));
        } else if (baseReserve > 0 && quoteReserve > 0) {
            // case 2. normal case
            uint256 baseInputRatio = DecimalMath.divFloor(baseInput, baseReserve);
            uint256 quoteInputRatio = DecimalMath.divFloor(quoteInput, quoteReserve);
            uint256 mintRatio = quoteInputRatio < baseInputRatio ? quoteInputRatio : baseInputRatio;
            shares = DecimalMath.mulFloor(totalSupply, mintRatio);

            _BASE_TARGET_ = uint112(uint256(_BASE_TARGET_) + (DecimalMath.mulFloor(uint256(_BASE_TARGET_), mintRatio)));
            _QUOTE_TARGET_ = uint112(uint256(_QUOTE_TARGET_) + (DecimalMath.mulFloor(uint256(_QUOTE_TARGET_), mintRatio)));
        }
        _mint(to, shares);
        _setReserve(baseBalance, quoteBalance);
        emit BuyShares(to, shares, _SHARES_[to]);
    }

    /// @notice sell shares [round down], user burn their lp and withdraw their tokens
    /// @param shareAmount the amount of lp tokens
    /// @param to the one who receive tokens
    /// @param baseMinAmount base token mininum amount returned back to users
    /// @param quoteMinAmount quote token mininum amount returned back to users
    /// @param data not neccessary
    /// @param deadline deadline
    function sellShares(
        uint256 shareAmount,
        address to,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        bytes calldata data,
        uint256 deadline
    ) external nonReentrant returns (uint256 baseAmount, uint256 quoteAmount) {
        require(deadline >= block.timestamp, "TIME_EXPIRED");
        require(shareAmount <= _SHARES_[msg.sender], "DLP_NOT_ENOUGH");

        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this)) - _MT_FEE_BASE_;
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this)) - _MT_FEE_QUOTE_;
        uint256 totalShares = totalSupply;

        baseAmount = baseBalance * shareAmount / totalShares;
        quoteAmount = quoteBalance * shareAmount / totalShares;
        

        _BASE_TARGET_ = uint112(uint256(_BASE_TARGET_) - DecimalMath._divCeil((uint256(_BASE_TARGET_) * (shareAmount)), totalShares));
        _QUOTE_TARGET_ = uint112(uint256(_QUOTE_TARGET_) - DecimalMath._divCeil((uint256(_QUOTE_TARGET_) * (shareAmount)), totalShares));
        
        require(
            baseAmount >= baseMinAmount && quoteAmount >= quoteMinAmount,
            "WITHDRAW_NOT_ENOUGH"
        );

        _burn(msg.sender, shareAmount);
        _transferBaseOut(to, baseAmount);
        _transferQuoteOut(to, quoteAmount);
        _sync();

        if (data.length > 0) {
            //Same as DVM 
            IDODOCallee(to).DVMSellShareCall(
                msg.sender,
                shareAmount,
                baseAmount,
                quoteAmount,
                data
            );
        }

        emit SellShares(msg.sender, to, shareAmount, _SHARES_[msg.sender]);
    }
}
