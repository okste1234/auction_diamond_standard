pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RCXToken is ERC20 {
    address DIAMOND;

    constructor(address _diamond) ERC20("RCXToken", "RCX") {
        DIAMOND = _diamond;
        mint(_diamond, 6_00e32);
    }

    function mint(address _to, uint256 _amount) public {
        // require(msg.sender == DIAMOND, "RCXToken: Only Diamond can mint");
        _mint(_to, _amount);
    }
}
