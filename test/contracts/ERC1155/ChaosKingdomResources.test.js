const {runBehaviorTests} = require('@animoca/ethereum-contract-helpers/src/test/run');
const {
  getForwarderRegistryAddress,
  getTokenMetadataResolverWithBaseURIAddress,
  getOperatorFilterRegistryAddress,
} = require('@animoca/ethereum-contracts/test/helpers/registries');
const {behavesLikeERC1155} = require('@animoca/ethereum-contracts/test/behaviors');

const name = 'ERC1155';
const symbol = 'ERC1155';

const config = {
  immutable: {
    name: 'ChaosKingdomResourcesMock',
    ctorArguments: ['name', 'symbol', 'metadataResolver', 'filterRegistry', 'forwarderRegistry'],
    testMsgData: true,
  },
  defaultArguments: {
    forwarderRegistry: getForwarderRegistryAddress,
    metadataResolver: getTokenMetadataResolverWithBaseURIAddress,
    filterRegistry: getOperatorFilterRegistryAddress,
    name,
    symbol,
  },
};

runBehaviorTests('ChaosKingdomResources', config, function (deployFn) {
  const implementation = {
    name,
    symbol,
    errors: {
      // ERC1155
      SelfApprovalForAll: {custom: true, error: 'ERC1155SelfApprovalForAll', args: ['account']},
      TransferToAddressZero: {custom: true, error: 'ERC1155TransferToAddressZero'},
      NonApproved: {custom: true, error: 'ERC1155NonApproved', args: ['sender', 'owner']},
      InsufficientBalance: {custom: true, error: 'ERC1155InsufficientBalance', args: ['owner', 'id', 'balance', 'value']},
      BalanceOverflow: {custom: true, error: 'ERC1155BalanceOverflow', args: ['recipient', 'id', 'balance', 'value']},
      SafeTransferRejected: {custom: true, error: 'ERC1155SafeTransferRejected', args: ['recipient', 'id', 'value']},
      SafeBatchTransferRejected: {custom: true, error: 'ERC1155SafeBatchTransferRejected', args: ['recipient', 'ids', 'values']},
      BalanceOfAddressZero: {custom: true, error: 'ERC1155BalanceOfAddressZero'},

      // ERC1155Mintable
      MintToAddressZero: {custom: true, error: 'ERC1155MintToAddressZero'},

      // ERC2981
      IncorrectRoyaltyReceiver: {custom: true, error: 'ERC2981IncorrectRoyaltyReceiver'},
      IncorrectRoyaltyPercentage: {custom: true, error: 'ERC2981IncorrectRoyaltyPercentage', args: ['percentage']},

      // OperatorFilterer
      OperatorNotAllowed: {custom: true, error: 'OperatorNotAllowed', args: ['operator']},

      // Misc
      InconsistentArrayLengths: {custom: true, error: 'InconsistentArrayLengths'},
      NotMinter: {custom: true, error: 'NotRoleHolder', args: ['role', 'account']},
      NotContractOwner: {custom: true, error: 'NotContractOwner', args: ['account']},
    },
    features: {
      MetadataResolver: true,
      WithOperatorFilterer: true,
      ERC2981: true,
    },
    interfaces: {
      NameSymbolMetadata: true,
      ERC1155: true,
      ERC1155Mintable: true,
      ERC1155Deliverable: true,
      ERC1155Burnable: true,
      ERC1155MetadataURI: true,
    },
    methods: {
      'safeMint(address,uint256,uint256,bytes)': async function (contract, to, id, value, data, signer) {
        return contract.connect(signer).safeMint(to, id, value, data);
      },
      'safeBatchMint(address,uint256[],uint256[],bytes)': async function (contract, to, ids, values, data, signer) {
        return contract.connect(signer).safeBatchMint(to, ids, values, data);
      },
      'burnFrom(address,uint256,uint256)': async function (contract, from, id, value, signer) {
        return contract.connect(signer).burnFrom(from, id, value);
      },
      'batchBurnFrom(address,uint256[],uint256[])': async function (contract, from, ids, values, signer) {
        return contract.connect(signer).batchBurnFrom(from, ids, values);
      },
    },
    deploy: async function (deployer, args = {}) {
      const contract = await deployFn({name, symbol, ...args});
      await contract.grantRole(await contract.MINTER_ROLE(), deployer.address);
      return contract;
    },
    mint: async function (contract, to, id, value) {
      return contract.safeMint(to, id, value, '0x');
    },
    tokenMetadata: async function (contract, id) {
      return contract.tokenURI(id);
    },
  };

  behavesLikeERC1155(implementation);
});
