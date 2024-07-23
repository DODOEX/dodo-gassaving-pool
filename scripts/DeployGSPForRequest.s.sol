// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "forge-std/Script.sol";

import {GSP} from "../contracts/GasSavingPool/impl/GSP.sol";
import {SolvOracleAdapter} from "../contracts/GasSavingPool/adapter/SolvOracleAdapter.sol";


// for broadcast deploy
contract DeployGSP is Script {

    GSP public gsp;
    SolvOracleAdapter public solvAdapter;

    // Init params
    address constant MAINTAINER = 0xcaa42F09AF66A8BAE3A7445a7f63DAD97c11638b;
    address constant ADMIN = 0x1Dc662D3D7De14a57CD369e3a9E774f8F80d4214; // todo change
    address constant BASE_TOKEN_ADDRESS = 0x1346b618dC92810EC74163e4c27004c921D446a5; // bsc, solv btc bbn
    address constant QUOTE_TOKEN_ADDRESS = 0x4aae823a6a0b376De6A78e74eCC5b079d38cBCf7; // bsc solvBTC
    uint256 constant LP_FEE_RATE = 0;
    uint256 constant MT_FEE_RATE = 300000000000000;
    //uint256 constant I = 1000000;
    uint256 constant K = 1000000000000000;
    bool constant IS_OPEN_TWAP = false;

    function run() external returns (GSP){
        // Deploy GSP Oracle
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(privateKey);
        vm.startBroadcast(deployerAddress);
        gsp = new GSP();
        solvAdapter = new SolvOracleAdapter();

        // init GSP
        gsp.init(
            MAINTAINER,
            MAINTAINER,
            BASE_TOKEN_ADDRESS,
            QUOTE_TOKEN_ADDRESS,
            LP_FEE_RATE,
            MT_FEE_RATE,
            K,
            address(solvAdapter),
            IS_OPEN_TWAP
        );

        vm.stopBroadcast();
        return gsp;
    }

    function testSuccess() public {}
}
