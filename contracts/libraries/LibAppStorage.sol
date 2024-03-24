// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAppStorage {
    uint256 constant APY = 120;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    struct UserStake {
        uint256 stakedTime;
        uint256 amount;
        uint256 id;
    }
    struct Layout {
        //ERC20
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        address lastERC20Interactor;
        //STAKING
        address rewardToken;
        uint256 rewardRate;
        mapping(address => UserStake) userDetails;
        address[] stakers;
        uint256 lastStakedTime;
        uint256 stakerCounts;
        uint256 totalStaked;
    }

    function layoutStorage() internal pure returns (Layout storage l) {
        assembly {
            l.slot := 0
        }
    }

    function _transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        Layout storage l = layoutStorage();
        uint256 frombalances = l.balances[msg.sender];
        require(
            frombalances >= _amount,
            "ERC20: Not enough tokens to transfer"
        );
        l.balances[_from] = frombalances - _amount;
        l.balances[_to] += _amount;
        emit Transfer(_from, _to, _amount);
    }
}
