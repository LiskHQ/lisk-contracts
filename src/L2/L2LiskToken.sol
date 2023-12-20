// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title IOptimismMintableERC20
/// @notice This interface is available on the OptimismMintableERC20 contract.
///         We declare it as a separate interface so that it can be used in
///         custom implementations of OptimismMintableERC20.
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

    /// @notice Address of the corresponding version of this token on the remote chain (on L1).
    address public immutable REMOTE_TOKEN;

    /// @notice Address of the StandardBridge on this (deployed) network.
    address public immutable BRIDGE;

    /// @notice Emitted whenever tokens are minted for an account.
    /// @param account Address of the account tokens are being minted for.
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    /// @param account Address of the account tokens are being burned from.
    /// @param amount  Amount of tokens burned.
    event Burn(address indexed account, uint256 amount);

    /// @notice A modifier that only allows the bridge to call
    modifier onlyBridge() {
        require(msg.sender == BRIDGE, "L2LiskToken: only bridge can mint or burn");
        _;
    }

    /// @notice Constructs the L2LiskToken contract.
    /// @param bridgeAddr      Address of the L2 standard bridge.
    /// @param remoteTokenAddr Address of the corresponding L1LiskToken.
    constructor(address bridgeAddr, address remoteTokenAddr) ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        REMOTE_TOKEN = remoteTokenAddr;
        BRIDGE = bridgeAddr;
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param to     Address to mint tokens to.
    /// @param amount Amount of tokens to mint.
    function mint(address to, uint256 amount) external virtual override(IOptimismMintableERC20) onlyBridge {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param from   Address to burn tokens from.
    /// @param amount Amount of tokens to burn.
    function burn(address from, uint256 amount) external virtual override(IOptimismMintableERC20) onlyBridge {
        _burn(from, amount);
        emit Burn(from, amount);
    }

    /// @notice ERC165 interface check function.
    /// @param interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
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
