// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title IOptimismMintableERC20
/// @notice Interface for the OptimismMintableERC20 contract, providing an abstraction layer for custom implementations.
///         Includes functionalities for minting and burning tokens, and querying token and bridge addresses.
interface IOptimismMintableERC20 is IERC165 {
    function remoteToken() external view returns (address);
    function bridge() external returns (address);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

/// @title L2LiskToken
/// @notice L2LiskToken is a standard extension of the base ERC20, ERC20Permit and IOptimismMintableERC20 token
///         contracts designed to allow the StandardBridge contract to mint and burn tokens. This makes it possible to
///         use an L2LiskToken as the L2 representation of an L1LiskToken.
contract L2LiskToken is IOptimismMintableERC20, ERC20, ERC20Permit {
    /// @notice Name of the token.
    string private constant NAME = "Lisk";

    /// @notice Symbol of the token.
    string private constant SYMBOL = "LSK";

    /// @notice Address which deployed this contract. Only this address is able to call initialize() function.
    ///         Using Foundry's forge script when deploying a contract with CREATE2 opcode, the address of the
    ///         deployer is a proxy contract address to have a deterministic deployer address. This offers a
    ///         flexibility that a deployed contract address is calculated only by the hash of the contract's bytecode
    ///         and a salt. Because initialize() function needs to be called by the actual deployer (EOA), we need to
    ///         store the address of the original caller of the constructor (tx.origin) and not msg.sender which is the
    ///         proxy contract address.
    address private immutable initializer;

    /// @notice Address of the corresponding version of this token on the remote chain (on L1).
    address public immutable REMOTE_TOKEN;

    /// @notice Address of the StandardBridge on this (deployed) network.
    address public BRIDGE;

    /// @notice Emitted whenever tokens are minted for an account.
    /// @param account Address of the account tokens are being minted for.
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    /// @param account Address of the account tokens are being burned from.
    /// @param amount  Amount of tokens burned.
    event Burn(address indexed account, uint256 amount);

    /// @notice Emitted whenever the Standard bridge address is changed.
    /// @param oldBridgeAddr Address of the old Standard bridge.
    /// @param newBridgeAddr Address of the new Standard bridge.
    event BridgeAddressChanged(address indexed oldBridgeAddr, address indexed newBridgeAddr);

    /// @notice A modifier that only allows the bridge to call.
    modifier onlyBridge() {
        require(msg.sender == BRIDGE, "L2LiskToken: only bridge can mint or burn");
        _;
    }

    /// @notice Constructs the L2LiskToken contract.
    /// @param remoteTokenAddr Address of the corresponding L1LiskToken.
    constructor(address remoteTokenAddr) ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        require(remoteTokenAddr != address(0), "L2LiskToken: remoteTokenAddr can not be zero");
        REMOTE_TOKEN = remoteTokenAddr;
        initializer = tx.origin;
    }

    /// @notice Initializes the L2LiskToken contract.
    /// @param bridgeAddr      Address of the L2 standard bridge.
    function initialize(address bridgeAddr) public {
        require(msg.sender == initializer, "L2LiskToken: only initializer can initialize this contract");
        require(bridgeAddr != address(0), "L2LiskToken: bridgeAddr can not be zero");
        require(BRIDGE == address(0), "L2LiskToken: already initialized");
        BRIDGE = bridgeAddr;
        emit BridgeAddressChanged(address(0), bridgeAddr);
    }

    /// @notice Mint function callable only by the bridge, to increase the token balance.
    /// @param to     Address receiving the minted tokens.
    /// @param amount Amount of tokens to mint.
    function mint(address to, uint256 amount) external virtual override(IOptimismMintableERC20) onlyBridge {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /// @notice Burn function callable only by the bridge, to decrease the token balance.
    /// @param from   Address from whose tokens are burned.
    /// @param amount Amount of tokens to burn.
    function burn(address from, uint256 amount) external virtual override(IOptimismMintableERC20) onlyBridge {
        _burn(from, amount);
        emit Burn(from, amount);
    }

    /// @notice Checks if a given interface is supported by the contract.
    /// @param interfaceId ID of the interface being queried.
    /// @return True if the interface is supported, false otherwise.
    function supportsInterface(bytes4 interfaceId) external pure virtual returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the L2LiskToken (this contract).
        bytes4 iface2 = type(IOptimismMintableERC20).interfaceId;
        return interfaceId == iface1 || interfaceId == iface2;
    }

    /// @notice Legacy getter for REMOTE_TOKEN.
    /// @return Address of the corresponding L1LiskToken on the remote chain.
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @notice Legacy getter for BRIDGE.
    /// @return Address of the L2 standard bridge.
    function bridge() public view returns (address) {
        return BRIDGE;
    }
}
