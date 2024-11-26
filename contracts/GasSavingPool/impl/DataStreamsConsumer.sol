/*
    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0
*/

pragma solidity 0.8.19;

import {Common} from "@chainlink/contracts/src/v0.8/llo-feeds/libraries/Common.sol";
import {StreamsLookupCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/StreamsLookupCompatibleInterface.sol";
import {ILogAutomation, Log} from "@chainlink/contracts/src/v0.8/automation/interfaces/ILogAutomation.sol";
import {IRewardManager} from "@chainlink/contracts/src/v0.8/llo-feeds/interfaces/IRewardManager.sol";
import {IVerifierFeeManager} from "@chainlink/contracts/src/v0.8/llo-feeds/interfaces/IVerifierFeeManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

struct TradeParamsStruct {
    address pool;
    bool isSellBase;
    address recipient;
    uint256 balance;
    uint256 input;
    string baseFeedId;
    string quoteFeedId;
}

interface IVerifierProxy {
    /**
     * @notice Verifies that the data encoded has been signed.
     * correctly by routing to the correct verifier, and bills the user if applicable.
     * @param payload The encoded data to be verified, including the signed
     * report.
     * @param parameterPayload Fee metadata for billing. For the current implementation this is just the abi-encoded fee token ERC-20 address.
     * @return verifierResponse The encoded report from the verifier.
     */
    function verify(
        bytes calldata payload,
        bytes calldata parameterPayload
    ) external payable returns (bytes memory verifierResponse);

    function s_feeManager() external view returns (IVerifierFeeManager);
}

interface IFeeManager {
    /**
     * @notice Calculates the fee and reward associated with verifying a report, including discounts for subscribers.
     * This function assesses the fee and reward for report verification, applying a discount for recognized subscriber addresses.
     * @param subscriber The address attempting to verify the report. A discount is applied if this address
     * is recognized as a subscriber.
     * @param unverifiedReport The report data awaiting verification. The content of this report is used to
     * determine the base fee and reward, before considering subscriber discounts.
     * @param quoteAddress The payment token address used for quoting fees and rewards.
     * @return fee The fee assessed for verifying the report, with subscriber discounts applied where applicable.
     * @return reward The reward allocated to the caller for successfully verifying the report.
     * @return totalDiscount The total discount amount deducted from the fee for subscribers
     */
    function getFeeAndReward(
        address subscriber,
        bytes memory unverifiedReport,
        address quoteAddress
    ) external returns (Common.Asset memory, Common.Asset memory, uint256);

    function i_linkAddress() external view returns (address);

    function i_nativeAddress() external view returns (address);

    function i_rewardManager() external view returns (address);
}


interface IPool {
    function sellBase(TradeParamsStruct memory tradeParams) external;

    function sellQuote(TradeParamsStruct memory tradeParams) external;

    function _BASE_TOKEN_() external view returns (address);

    function _QUOTE_TOKEN_() external view returns (address);

    function adjustPrice(uint256 newPrice) external;
}

contract DataStreamsConsumer is ILogAutomation, StreamsLookupCompatibleInterface, Ownable {

    IVerifierProxy public VERIFIER;
    string[] public feedsHex; // An array of hexadecimal feed IDs.
    mapping(string => bool) private feedIdExists;

    struct ReportV3 {
        bytes32 feedId; // The stream ID the report has data for.
        uint32 validFromTimestamp; // Earliest timestamp for which price is applicable.
        uint32 observationsTimestamp; // Latest timestamp for which price is applicable.
        uint192 nativeFee; // Base cost to validate a transaction using the report, denominated in the chain’s native token (e.g., WETH/ETH).
        uint192 linkFee; // Base cost to validate a transaction using the report, denominated in LINK.
        uint32 expiresAt; // Latest timestamp where the report can be verified onchain.
        int192 price; // DON consensus median price (8 or 18 decimals).
        int192 bid; // Simulated price impact of a buy order up to the X% depth of liquidity utilisation (8 or 18 decimals).
        int192 ask; // Simulated price impact of a sell order up to the X% depth of liquidity utilisation (8 or 18 decimals).
    }

    // ============ Events ============
    event InitiateTrade(
        address pool,
        bool isSellBase,
        address receiver,
        uint256 balance,
        uint256 input,
        string baseFeedId,
        string quoteFeedId
    );

    // ============ Errors ============
    error InvalidFeedId(string feedId);

    constructor(address verifier) {
        VERIFIER = IVerifierProxy(payable(verifier));
    }

    function addFeedId(string[] memory feedIds) external onlyOwner {
        for (uint256 i = 0; i < feedIds.length; i++) {
            if (!feedIdExists[feedIds[i]]) {
                feedsHex.push(feedIds[i]);
                feedIdExists[feedIds[i]] = true;
            }
        }
    }

    function performUpkeep(bytes calldata performData) external {
        // Decode performData
        (bytes[] memory signedReports, bytes memory extraData) = abi.decode(performData, (bytes[], bytes));
        
        // Retrieve parameters
        TradeParamsStruct memory tradeParams = _getTradeParams(extraData);
        bytes memory baseUnverifiedReport = signedReports[_getIdFromFeed(tradeParams.baseFeedId)];
        bytes memory quoteUnverifiedReport = signedReports[_getIdFromFeed(tradeParams.quoteFeedId)];

        // Decode reports
        (, /* bytes32[3] reportContextData */ bytes memory baseReportData) = abi.decode(baseUnverifiedReport, (bytes32[3], bytes));
        (, /* bytes32[3] reportContextData */ bytes memory quoteReportData) = abi.decode(quoteUnverifiedReport, (bytes32[3], bytes));

        // Calculate fees
        _handleFees(baseReportData, quoteReportData);
        
        // Verify reports
        bytes memory baseVerifiedReportData = _verifyReport(baseUnverifiedReport);
        bytes memory quoteVerifiedReportData = _verifyReport(quoteUnverifiedReport);
        ReportV3 memory baseVerifiedReport = abi.decode(baseVerifiedReportData, (ReportV3));
        ReportV3 memory quoteVerifiedReport = abi.decode(quoteVerifiedReportData, (ReportV3));

        // Update prices and execute trade
        _updatePrice(tradeParams.pool, baseVerifiedReport.price, quoteVerifiedReport.price);
        _executeTrade(tradeParams);
    }


    // ============ Helper Functions ============
    function _getTradeParams(bytes memory extraData) internal pure returns (TradeParamsStruct memory tradeParams) {
        Log memory log = abi.decode(extraData, (Log));

        (   
            address pool,
            bool isSellBase,
            address recipient,  
            uint256 balance,
            uint256 input,
            string memory baseFeedId,
            string memory quoteFeedId
        ) = abi.decode(log.data, (address, bool, address, uint256, uint256, string, string));
        tradeParams = TradeParamsStruct(pool, isSellBase, recipient, balance, input, baseFeedId, quoteFeedId);
    }

    function _getIdFromFeed(string memory feedId) internal view returns (uint256 index) {
        string[] storage feeds = feedsHex;
        for (uint256 i = 0; i < feeds.length; i++) {
            if (
                keccak256(abi.encode(feeds[i])) == keccak256(abi.encode(feedId))
            ) {
                index = i;
                break;
            }
            if (i == feeds.length - 1) {
                revert InvalidFeedId(feedId);
            }
        }
        return index;
    }

    // Helper function to approve fees and manage rewards
    function _handleFees(bytes memory baseReportData, bytes memory quoteReportData) internal {
        IFeeManager feeManager = IFeeManager(address(VERIFIER.s_feeManager()));
        IRewardManager rewardManager = IRewardManager(address(feeManager.i_rewardManager()));
        address feeTokenAddress = feeManager.i_linkAddress();

        (Common.Asset memory baseFee, , ) = feeManager.getFeeAndReward(address(this), baseReportData, feeTokenAddress);
        (Common.Asset memory quoteFee, , ) = feeManager.getFeeAndReward(address(this), quoteReportData, feeTokenAddress);

        uint totalFee = baseFee.amount + quoteFee.amount;
        IERC20(feeTokenAddress).approve(address(rewardManager), totalFee);
    }

    // Helper function to verify report data
    function _verifyReport(bytes memory unverifiedReport) internal returns (bytes memory) {
        IFeeManager feeManager = IFeeManager(address(VERIFIER.s_feeManager()));
        address feeTokenAddress = feeManager.i_linkAddress();
        return VERIFIER.verify(unverifiedReport, abi.encode(feeTokenAddress));
    }

    function _updatePrice(address pool, int192 basePrice, int192 quotePrice) internal {
        address baseToken = IPool(pool)._BASE_TOKEN_();
        address quoteToken = IPool(pool)._QUOTE_TOKEN_();
        uint256 baseDecimal = uint256(IERC20Metadata(baseToken).decimals());
        uint256 quoteDecimal = uint256(IERC20Metadata(quoteToken).decimals());
        uint256 newPrice = (uint256(int256(basePrice)) * 10 ** (18 - baseDecimal + quoteDecimal)) / uint256(int256(quotePrice));
        IPool(pool).adjustPrice(newPrice);
    }

    // Helper function to execute trade based on trade parameters
    function _executeTrade(TradeParamsStruct memory tradeParams) internal {
        if (tradeParams.isSellBase) {
            IPool(tradeParams.pool).sellBase(tradeParams);
        } else {
            IPool(tradeParams.pool).sellQuote(tradeParams);
        }
    }

    function checkLog(
        Log calldata log,
        bytes memory /* checkData */
    ) external view override returns (bool /* upkeepNeeded */, bytes memory /* performData */) {
        revert StreamsLookup(
            "feedIDs",
            feedsHex,
            "timestamp",
            log.timestamp,
            abi.encode(log)
        );
    }

    function checkCallback(
        bytes[] memory values,
        bytes memory extraData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return (true, abi.encode(values, extraData));
    }

    function checkErrorHandler(
        uint256 /*errCode*/,
        bytes memory /*extraData*/
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return (true, "0");
    }

    receive() external payable {}
}