// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MultiSigWallet.sol";

contract Foundation  is MultiSigWallet{
    address public  _token;

    address private immutable owner;

    bool private _initialize;

    event Released(address user,uint256 amount);

    constructor() {
         owner = msg.sender;
    }

    function initialize(
        address[] memory _owners,
        address token
    ) external {
        require(msg.sender == owner,"only owner");
        require(!_initialize,"already initialize");

        uint256 _required = _owners.length/2;

        MultiSigWallet_initialize(_owners, _required);

       _token = token;

       _initialize = true;
    }

    function release(address _beneficiary,uint256 _amount) public onlyWallet {
        uint256 value = IERC20(_token).balanceOf(address(this));
            
        require(_amount <= value,"amount lt balanceOf");

        IERC20(_token).transfer(_beneficiary, _amount);

        emit Released(_beneficiary,_amount);
    }
}