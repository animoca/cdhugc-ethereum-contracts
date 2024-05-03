// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ContractOwnershipStorage} from "@animoca/ethereum-contracts/contracts/access/libraries/ContractOwnershipStorage.sol";
import {ContractOwnership} from "@animoca/ethereum-contracts/contracts/access/ContractOwnership.sol";
import {IERC20} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20.sol";
import {IERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20Receiver.sol";
import {ERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Receiver.sol";
import {IERC1155Mintable} from "@animoca/ethereum-contracts/contracts/token/ERC1155/interfaces/IERC1155Mintable.sol";
import {TokenRecovery} from "@animoca/ethereum-contracts/contracts/security/TokenRecovery.sol";
import {PayoutWalletStorage} from "@animoca/ethereum-contracts/contracts/payment/libraries/PayoutWalletStorage.sol";
import {PayoutWallet} from "@animoca/ethereum-contracts/contracts/payment/PayoutWallet.sol";

contract ChaosKingdomResourcesClaim is ContractOwnership, ERC20Receiver, TokenRecovery, PayoutWallet {
    using MerkleProof for bytes32[];
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;
    using PayoutWalletStorage for PayoutWalletStorage.Layout;

    mapping(bytes32 => bool) public roots;
    mapping(bytes32 => bool) public claimed;

    IERC1155Mintable public immutable REWARD_CONTRACT;
    IERC20 public immutable FEE_CONTRACT;

    event MerkleRootAdded(bytes32 indexed root);

    event MerkleRootDeprecated(bytes32 indexed root);

    event PayoutClaimed(bytes32 indexed root, bytes32 indexed epochId, uint256 fee, address indexed recipient, uint256[] ids, uint256[] values);

    error MerkleRootAlreadyExists(bytes32 merkleRoot);

    error InvalidMerkleRoot(bytes32 merkleRoot);

    error AlreadyClaimed(address recipient, uint256[] ids, uint256[] values, uint256 fee, bytes32 epochId);

    error InvalidProof(address recipient, uint256[] ids, uint256[] values, uint256 fee, bytes32 epochId);

    error InvalidFeeContract(address receivedContract, address expectedContract);

    constructor(
        IERC20 feeContract,
        IERC1155Mintable rewardContract,
        address payable payoutWallet
    ) ContractOwnership(msg.sender) PayoutWallet(payoutWallet) {
        FEE_CONTRACT = feeContract;
        REWARD_CONTRACT = rewardContract;
    }

    function onERC20Received(address, address, uint256 value, bytes calldata data) external override returns (bytes4 magicValue) {
        if (address(FEE_CONTRACT) != msg.sender) revert InvalidFeeContract(msg.sender, address(FEE_CONTRACT));

        (bytes32 merkleRoot, bytes32 epochId, bytes32[] memory proof, address recipient, uint256[] memory ids, uint256[] memory values) = abi.decode(
            data,
            (bytes32, bytes32, bytes32[], address, uint256[], uint256[])
        );

        if (!roots[merkleRoot]) revert InvalidMerkleRoot(merkleRoot);

        bytes32 leaf = keccak256(abi.encodePacked(recipient, ids, values, value, epochId));

        if (!proof.verify(merkleRoot, leaf)) revert InvalidProof(recipient, ids, values, value, epochId);
        if (claimed[leaf]) revert AlreadyClaimed(recipient, ids, values, value, epochId);

        address payable payoutWallet = PayoutWalletStorage.layout().payoutWallet();
        FEE_CONTRACT.transfer(payoutWallet, value);
        claimed[leaf] = true;
        emit PayoutClaimed(merkleRoot, epochId, value, recipient, ids, values);
        REWARD_CONTRACT.safeBatchMint(recipient, ids, values, "");

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
