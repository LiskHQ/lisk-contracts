// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

interface IL2LiskToken {
    error ECDSAInvalidSignature();
    error ECDSAInvalidSignatureLength(uint256 length);
    error ECDSAInvalidSignatureS(bytes32 s);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidSpender(address spender);
    error ERC2612ExpiredSignature(uint256 deadline);
    error ERC2612InvalidSigner(address signer, address owner);
    error InvalidAccountNonce(address account, uint256 currentNonce);
    error InvalidShortString();
    error StringTooLong(string str);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BridgeAddressChanged(address indexed oldBridgeAddr, address indexed newBridgeAddr);
    event Burn(address indexed account, uint256 amount);
    event EIP712DomainChanged();
    event Mint(address indexed account, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function BRIDGE() external view returns (address);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function REMOTE_TOKEN() external view returns (address);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function bridge() external view returns (address);
    function burn(address from, uint256 amount) external;
    function decimals() external view returns (uint8);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function initialize(address bridgeAddr) external;
    function mint(address to, uint256 amount) external;
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;
    function remoteToken() external view returns (address);
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
