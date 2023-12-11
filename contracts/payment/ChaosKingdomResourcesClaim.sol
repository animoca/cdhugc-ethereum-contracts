// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ContractOwnershipStorage} from "@animoca/ethereum-contracts/contracts/access/libraries/ContractOwnershipStorage.sol";
import {ContractOwnership} from "@animoca/ethereum-contracts/contracts/access/ContractOwnership.sol";
import {IERC20} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20.sol";
import {ERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Receiver.sol";
import {IERC1155Mintable} from "@animoca/ethereum-contracts/contracts/token/ERC1155/interfaces/IERC1155Mintable.sol";
import {ForwarderRegistryContext} from "@animoca/ethereum-contracts/contracts/metatx/ForwarderRegistryContext.sol";
import {ForwarderRegistryContextBase} from "@animoca/ethereum-contracts/contracts/metatx/base/ForwarderRegistryContextBase.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";

contract ChaosKingdomResourcesClaim is ContractOwnership, ERC20Receiver, ForwarderRegistryContext {
    using MerkleProof for bytes32[];
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    mapping(bytes32 => bool) public roots;
    mapping(bytes32 => bool) public claimed;

    IERC1155Mintable public immutable REWARD_CONTRACT;
    IERC20 public immutable FEE_CONTRACT;
    bytes4 private constant MAGIC_VALUE = 0x4fc35859; // bytes4(keccak256("onERC20Received(address,address,uint256,bytes)"))

    event MerkleRootAdded(bytes32 root);

    event MerkleRootDeprecated(bytes32 root);

    event PayoutClaimed(bytes32 indexed root, bytes32 epochId, uint256 fee, address indexed recipient, uint256[] ids, uint256[] values);

    error MerkleRootAlreadyExists(bytes32 merkleRoot);

    error MerkleRootDoesNotExist(bytes32 merkleRoot);

    error AlreadyClaimed(address recipient, uint256[] ids, uint256[] values, uint256 fee, bytes32 epochId);

    error InvalidProof(address recipient, uint256[] ids, uint256[] values, uint256 fee, bytes32 epochId);

    error FeeContractMismatch(address sender, address expectedContract);

    constructor(
        IERC20 feeContract,
        IERC1155Mintable rewardContract,
        IForwarderRegistry forwarderRegistry
    ) ContractOwnership(msg.sender) ForwarderRegistryContext(forwarderRegistry) {
        FEE_CONTRACT = feeContract;
        REWARD_CONTRACT = rewardContract;
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }

    // TODO: separate info claim function
    function onERC20Received(address operator, address from, uint256 value, bytes calldata data) external override returns (bytes4 magicValue) {
        if (address(FEE_CONTRACT) != msg.sender) revert FeeContractMismatch(msg.sender, address(FEE_CONTRACT));

        uint256 fee = value;

        (uint256[] memory ids, uint256[] memory values) = _processClaimData(from, data, fee);

        REWARD_CONTRACT.safeBatchMint(from, ids, values, "");

        return MAGIC_VALUE;
    }

    function _processClaimData(
        address recipient,
        bytes calldata claimData,
        uint256 fee
    ) internal returns (uint256[] memory ids, uint256[] memory values) {
        (bytes32 merkleRoot, bytes32 epochId, bytes32[] memory proof, uint256[] memory _ids, uint256[] memory _values) = abi.decode(
            claimData,
            (bytes32, bytes32, bytes32[], uint256[], uint256[])
        );
        if (!roots[merkleRoot]) revert MerkleRootDoesNotExist(merkleRoot);

        bytes32 leaf = keccak256(abi.encodePacked(recipient, _ids, _values, fee, epochId));

        if (claimed[leaf]) revert AlreadyClaimed(recipient, _ids, _values, fee, epochId);
        if (!proof.verify(merkleRoot, leaf)) revert InvalidProof(recipient, _ids, _values, fee, epochId);

        claimed[leaf] = true;

        emit PayoutClaimed(merkleRoot, epochId, fee, recipient, _ids, _values);

        return (_ids, _values);
    }

    function claim(address recipient, bytes calldata claimData, uint256 fee) external {
        (uint256[] memory ids, uint256[] memory values) = _processClaimData(recipient, claimData, fee);

        FEE_CONTRACT.transferFrom(recipient, address(this), fee);
        REWARD_CONTRACT.safeBatchMint(recipient, ids, values, "");
    }

    function addMerkleRoot(bytes32 merkleRoot) public {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        if (roots[merkleRoot]) revert MerkleRootAlreadyExists(merkleRoot);

        roots[merkleRoot] = true;
        emit MerkleRootAdded(merkleRoot);
    }

    function deprecateMerkleRoot(bytes32 merkleRoot) public {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        if (!roots[merkleRoot]) revert MerkleRootDoesNotExist(merkleRoot);

        roots[merkleRoot] = false;
        emit MerkleRootDeprecated(merkleRoot);
    }
}
