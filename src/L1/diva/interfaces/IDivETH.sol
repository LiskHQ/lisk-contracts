// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDivETH is IERC20 {
    function getEthByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByEth(uint256 _ethAmount) external view returns (uint256);

    function totalSupply() external view returns (uint256);
    
    function balanceOf() external view returns (uint256);

    function getTotalEther() external view returns (uint256);
    
    function getDepositedEther() external view returns (uint256);
    
    function getBeaconChainEther() external view returns (uint256);
    
    function getBufferedEther() external view returns (uint256);
    
    function getWithdrawCredentials() external view returns(address);

    function submit() external payable returns (uint256);
    
    function submitFor(address _forUser) external payable returns (uint256);


     function depositToDepositContract(
        uint _valueToDeposit,
        bytes32 _deposit_data_root,
        bytes calldata _pubKey,
        bytes calldata _signature,
        bytes calldata _withdrawalCredentials
    ) external ;
}
