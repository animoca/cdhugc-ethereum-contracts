const {ethers} = require('hardhat');
const {expect} = require('chai');
const {MerkleTree} = require('merkletreejs');
const keccak256 = require('keccak256');
const {deployContract} = require('@animoca/ethereum-contract-helpers/src/test/deploy');
const {loadFixture} = require('@animoca/ethereum-contract-helpers/src/test/fixtures');
const {
  getTokenMetadataResolverWithBaseURIAddress,
  getOperatorFilterRegistryAddress,
  getForwarderRegistryAddress,
} = require('@animoca/ethereum-contracts/test/helpers/registries');

describe('ChaosKingdomResourcesClaim', function () {
  before(async function () {
    [deployer, claimer1, claimer2, claimer3, claimer4, other] = await ethers.getSigners();
  });

  const fixture = async function () {
    const metadataResolverAddress = await getTokenMetadataResolverWithBaseURIAddress();
    const forwarderRegistryAddress = await getForwarderRegistryAddress();
    const filterRegistryAddress = await getOperatorFilterRegistryAddress();

    this.rewardContract = await deployContract('ChaosKingdomResources', metadataResolverAddress, filterRegistryAddress, forwarderRegistryAddress);
    this.feeContract = await deployContract('ERC20MintBurn', '', '', 18, forwarderRegistryAddress);

    const rewardsContractAddress = await this.rewardContract.getAddress();
    const feeContractAddress = await this.feeContract.getAddress();

    this.contract = await deployContract('ChaosKingdomResourcesClaim', feeContractAddress, rewardsContractAddress);
    await this.rewardContract.grantRole(await this.rewardContract.MINTER_ROLE(), await this.contract.getAddress());
  };

  beforeEach(async function () {
    await loadFixture(fixture, this);
  });

  context('constructor', function () {
    it('deployer is the contract owner', async function () {
      expect(await this.contract.owner()).to.equal(deployer.address);
    });
  });

  context('addMerkleRoot(bytes32, uint256)', function () {
    it('reverts if not sent by the contract owner', async function () {
      await expect(this.contract.connect(other).addMerkleRoot(ethers.ZeroHash))
        .to.be.revertedWithCustomError(this.contract, 'NotContractOwner')
        .withArgs(other.address);
    });
    it('reverts if merkle root already exist', async function () {
      const root = ethers.ZeroHash;
      await this.contract.addMerkleRoot(root);
      await expect(this.contract.addMerkleRoot(root)).to.be.revertedWithCustomError(this.contract, 'MerkleRootAlreadyExists').withArgs(root);
    });
    it('roots contains newly added root', async function () {
      const root = ethers.ZeroHash;
      await this.contract.addMerkleRoot(root);
      const rootIsExist = await this.contract.roots(root);
      expect(rootIsExist).to.equal(true);
    });

    it('emits a MerkleRootAdded event', async function () {
      const root = ethers.ZeroHash;
      await expect(this.contract.addMerkleRoot(root)).to.emit(this.contract, 'MerkleRootAdded').withArgs(root);
    });
  });

  context('deprecateMerkleRoot(bytes32)', function () {
    it('reverts if not sent by the contract owner', async function () {
      await expect(this.contract.connect(other).deprecateMerkleRoot(ethers.ZeroHash))
        .to.be.revertedWithCustomError(this.contract, 'NotContractOwner')
        .withArgs(other.address);
    });
    it('reverts if merkle root does not exist', async function () {
      const root = ethers.ZeroHash;
      await expect(this.contract.deprecateMerkleRoot(root)).to.be.revertedWithCustomError(this.contract, 'InvalidMerkleRoot').withArgs(root);
    });
    it('root is removed from roots', async function () {
      const root = ethers.ZeroHash;
      await this.contract.addMerkleRoot(root);
      await this.contract.deprecateMerkleRoot(root);
      const rootIsExist = await this.contract.roots(root);
      expect(rootIsExist).to.equal(false);
    });

    it('emits a MerkleRootDeprecated event', async function () {
      const root = ethers.ZeroHash;
      await this.contract.addMerkleRoot(root);
      await expect(this.contract.deprecateMerkleRoot(root)).to.emit(this.contract, 'MerkleRootDeprecated').withArgs(root);
    });
  });

  context('onERC20Received(address,address,uint256,bytes)', function () {
    context('with a merkle root set', function () {
      beforeEach(async function () {
        this.epochId = ethers.zeroPadValue('0x9a794a09cf7b4fb99e2e3d4aeac42eab', 32);

        this.elements = [
          {
            claimer: claimer1.address,
            tokenIds: [1],
            amounts: [1],
            costs: 10,
          },
          {
            claimer: claimer2.address,
            tokenIds: [2],
            amounts: [2],
            costs: 20,
          },
          {
            claimer: claimer3.address,
            tokenIds: [3],
            amounts: [3],
            costs: 30,
          },
          {
            claimer: claimer4.address,
            tokenIds: [4],
            amounts: [4],
            costs: 40,
          },
        ];
        this.leaves = this.elements.map((el) =>
          ethers.solidityPacked(
            ['address', 'uint256[]', 'uint256[]', 'uint256', 'bytes32'],
            [el.claimer, el.tokenIds, el.amounts, el.costs, this.epochId]
          )
        );
        this.tree = new MerkleTree(this.leaves, keccak256, {hashLeaves: true, sortPairs: true});
        this.root = this.tree.getHexRoot();
        await this.contract.addMerkleRoot(this.root);

        this.feeContract.grantRole(await this.feeContract.MINTER_ROLE(), deployer.address);
        await this.feeContract.mint(claimer1.address, 100);

        this.elements[0].proof = this.tree.getHexProof(keccak256(this.leaves[0]));
        this.elements[0].data = ethers.AbiCoder.defaultAbiCoder().encode(
          ['bytes32', 'bytes32', 'bytes32[]', 'uint256[]', 'uint256[]'],
          [this.root, this.epochId, this.elements[0].proof, this.elements[0].tokenIds, this.elements[0].amounts]
        );
      });
      it('reverts with InvalidFeeContract if token transferred is not from feeContract', async function () {
        const anotherContract = await deployContract('ERC20MintBurn', '', '', 18, await getForwarderRegistryAddress());
        await anotherContract.grantRole(await anotherContract.MINTER_ROLE(), deployer.address);
        await anotherContract.mint(claimer1.address, 10);

        await expect(anotherContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, ethers.ZeroHash))
          .to.revertedWithCustomError(this.contract, 'InvalidFeeContract')
          .withArgs(await anotherContract.getAddress(), await this.feeContract.getAddress());
      });
      it('reverts with InvalidMerkleRoot if the merkle root does not exist', async function () {
        const mockRoot = ethers.ZeroHash;
        const data = ethers.AbiCoder.defaultAbiCoder().encode(
          ['bytes32', 'bytes32', 'bytes32[]', 'uint256[]', 'uint256[]'],
          [mockRoot, this.epochId, this.elements[0].proof, this.elements[0].tokenIds, this.elements[0].amounts]
        );

        await expect(this.feeContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, data))
          .to.revertedWithCustomError(this.contract, 'InvalidMerkleRoot')
          .withArgs(ethers.ZeroHash);
      });
      it('reverts with AlreadyClaimed if the leaf is claimed twice', async function () {
        await this.feeContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, this.elements[0].data);

        await expect(this.feeContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, this.elements[0].data))
          .to.revertedWithCustomError(this.contract, 'AlreadyClaimed')
          .withArgs(this.elements[0].claimer, this.elements[0].tokenIds, this.elements[0].amounts, this.elements[0].costs, this.epochId);
      });
      it('reverts with InvalidProof if the proof can not be verified', async function () {
        const leafOneProof = this.tree.getHexProof(keccak256(this.leaves[1]));
        const data = ethers.AbiCoder.defaultAbiCoder().encode(
          ['bytes32', 'bytes32', 'bytes32[]', 'uint256[]', 'uint256[]'],
          [this.root, this.epochId, leafOneProof, this.elements[0].tokenIds, this.elements[0].amounts]
        );

        await expect(this.feeContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, data))
          .to.revertedWithCustomError(this.contract, 'InvalidProof')
          .withArgs(this.elements[0].claimer, this.elements[0].tokenIds, this.elements[0].amounts, this.elements[0].costs, this.epochId);
      });
      it('emits a PayoutClaimed event', async function () {
        await expect(this.feeContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, this.elements[0].data))
          .to.emit(this.contract, 'PayoutClaimed')
          .withArgs(this.root, this.epochId, this.elements[0].costs, this.elements[0].claimer, this.elements[0].tokenIds, this.elements[0].amounts);
      });
      it('emit TransferBatch event', async function () {
        await expect(this.feeContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, this.elements[0].data))
          .to.emit(this.rewardContract, 'TransferBatch')
          .withArgs(
            await this.contract.getAddress(),
            ethers.ZeroAddress,
            this.elements[0].claimer,
            this.elements[0].tokenIds,
            this.elements[0].amounts
          );
      });
      it('mints the reward', async function () {
        await this.feeContract.connect(claimer1).safeTransfer(await this.contract.getAddress(), 10, this.elements[0].data);

        await expect(this.rewardContract.balanceOf(this.elements[0].claimer, this.elements[0].tokenIds[0])).to.eventually.equal(
          this.elements[0].amounts[0]
        );
      });
    });
  });
});
