// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibFuncHelper {
    function calculateIncentive(uint _amount) internal pure returns (uint) {
        return (10 * _amount) / 100;
    }
}
