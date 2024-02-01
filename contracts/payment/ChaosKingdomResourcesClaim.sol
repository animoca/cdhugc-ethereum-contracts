// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ContractOwnershipStorage} from "@animoca/ethereum-contracts/contracts/access/libraries/ContractOwnershipStorage.sol";
import {ContractOwnership} from "@animoca/ethereum-contracts/contracts/access/ContractOwnership.sol";
import {IERC20SafeTransfers} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20SafeTransfers.sol";
import {IERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20Receiver.sol";
import {ERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Receiver.sol";
import {IERC1155Mintable} from "@animoca/ethereum-contracts/contracts/token/ERC1155/interfaces/IERC1155Mintable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {TokenRecovery} from "@animoca/ethereum-contracts/contracts/security/TokenRecovery.sol";

contract ChaosKingdomResourcesClaim is ContractOwnership, ERC20Receiver, TokenRecovery {
    using MerkleProof for bytes32[];
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    mapping(bytes32 => bool) public roots;
    mapping(bytes32 => bool) public claimed;

    IERC1155Mintable public immutable REWARD_CONTRACT;
    IERC20SafeTransfers public immutable FEE_CONTRACT;

    address public revenueWallet;

    event RevenueWalletUpdated(address revenueWallet);

    event MerkleRootAdded(bytes32 indexed root);

    event MerkleRootDeprecated(bytes32 indexed root);

    event PayoutClaimed(bytes32 indexed root, bytes32 indexed epochId, uint256 fee, address indexed recipient, uint256[] ids, uint256[] values);

    error InvalidRevenueWallet(address receivedContract);

    error MerkleRootAlreadyExists(bytes32 merkleRoot);

    error InvalidMerkleRoot(bytes32 merkleRoot);

    error AlreadyClaimed(address recipient, uint256[] ids, uint256[] values, uint256 fee, bytes32 epochId);

    error InvalidProof(address recipient, uint256[] ids, uint256[] values, uint256 fee, bytes32 epochId);

    error InvalidFeeContract(address receivedContract, address expectedContract);

    constructor(IERC20SafeTransfers feeContract, IERC1155Mintable rewardContract, address _revenueWallet) ContractOwnership(msg.sender) {
        FEE_CONTRACT = feeContract;
        REWARD_CONTRACT = rewardContract;
        revenueWallet = _revenueWallet;
    }

    function setRevenueWallet(address newRevenueWallet) public {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        if (newRevenueWallet == address(0)) revert InvalidRevenueWallet(newRevenueWallet);

        revenueWallet = newRevenueWallet;
        emit RevenueWalletUpdated(newRevenueWallet);
    }

    function onERC20Received(address operator, address from, uint256 value, bytes calldata data) external override returns (bytes4 magicValue) {
        if (address(FEE_CONTRACT) != msg.sender) revert InvalidFeeContract(msg.sender, address(FEE_CONTRACT));

        (bytes32 merkleRoot, bytes32 epochId, bytes32[] memory proof, uint256[] memory _ids, uint256[] memory _values) = abi.decode(
            data,
            (bytes32, bytes32, bytes32[], uint256[], uint256[])
        );

        if (!roots[merkleRoot]) revert InvalidMerkleRoot(merkleRoot);

        bytes32 leaf = keccak256(abi.encodePacked(from, _ids, _values, value, epochId));

        if (claimed[leaf]) revert AlreadyClaimed(from, _ids, _values, value, epochId);
        if (!proof.verify(merkleRoot, leaf)) revert InvalidProof(from, _ids, _values, value, epochId);

        REWARD_CONTRACT.safeBatchMint(from, _ids, _values, "");
        claimed[leaf] = true;
        emit PayoutClaimed(merkleRoot, epochId, value, from, _ids, _values);

        FEE_CONTRACT.safeTransfer(revenueWallet, value, "");

        return IERC20Receiver.onERC20Received.selector;
    }

    function addMerkleRoot(bytes32 merkleRoot) public {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        if (roots[merkleRoot]) revert MerkleRootAlreadyExists(merkleRoot);

        roots[merkleRoot] = true;
        emit MerkleRootAdded(merkleRoot);
    }

    function deprecateMerkleRoot(bytes32 merkleRoot) public {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        if (!roots[merkleRoot]) revert InvalidMerkleRoot(merkleRoot);

        roots[merkleRoot] = false;
        emit MerkleRootDeprecated(merkleRoot);
    }
}