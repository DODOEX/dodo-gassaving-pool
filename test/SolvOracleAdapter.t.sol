// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import {GSP} from "../contracts/GasSavingPool/impl/GSP.sol";
import {IOracle} from "../contracts/GasSavingPool/intf/IOracle.sol";
import {SftWrappedTokenMock} from "./mock/SftWrappedTokenMock.sol";
import {SolvOracleAdapter} from "../contracts/GasSavingPool/adapter/SolvOracleAdapter.sol";
import {Test} from "forge-std/Test.sol";

contract SolvOracleAdapterTest is Test {
    GSP public gsp;
    IOracle public oracle;
    SftWrappedTokenMock public baseToken;
    SftWrappedTokenMock public quoteToken;
    SolvOracleAdapter public solvOracleAdapter;

    address owner = address(123);

    function setUp() public {
        gsp = new GSP();
        baseToken = new SftWrappedTokenMock();
        solvOracleAdapter = new SolvOracleAdapter();
        oracle = IOracle(address(solvOracleAdapter));
    }

    function testGetPrice() public {
        gsp.init(
            owner,
            owner,
            address(baseToken),
            address(quoteToken),
            0,
            0,
            1e15,
            address(oracle),
            false   
        );

        assertEq(gsp._I_(), 1e18);
    }
}

