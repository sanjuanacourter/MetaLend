const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GovernanceDAO", function () {
  let governanceDAO;
  let metaLendToken;
  let timelock;
  let owner;
  let voter1;
  let voter2;
  let voter3;

  beforeEach(async function () {
    [owner, voter1, voter2, voter3] = await ethers.getSigners();

    // Deploy MetaLendToken
    const MetaLendToken = await ethers.getContractFactory("MetaLendToken");
    metaLendToken = await MetaLendToken.deploy();
    await metaLendToken.deployed();

    // Deploy TimelockController
    const TimelockController = await ethers.getContractFactory("TimelockController");
    timelock = await TimelockController.deploy(3600, [owner.address], [owner.address]);
    await timelock.deployed();

    // Deploy GovernanceDAO
    const GovernanceDAO = await ethers.getContractFactory("GovernanceDAO");
    governanceDAO = await GovernanceDAO.deploy(
      metaLendToken.address,
      timelock.address,
      owner.address
    );
    await governanceDAO.deployed();

    // Distribute tokens to voters
    await metaLendToken.transfer(voter1.address, ethers.utils.parseEther("2000000")); // 2M tokens
    await metaLendToken.transfer(voter2.address, ethers.utils.parseEther("1500000")); // 1.5M tokens
    await metaLendToken.transfer(voter3.address, ethers.utils.parseEther("1000000")); // 1M tokens

    // Delegate voting power
    await metaLendToken.connect(voter1).delegate(voter1.address);
    await metaLendToken.connect(voter2).delegate(voter2.address);
    await metaLendToken.connect(voter3).delegate(voter3.address);
  });

  describe("Deployment", function () {
    it("Should set the correct token address", async function () {
      expect(await governanceDAO.token()).to.equal(metaLendToken.address);
    });

    it("Should set the correct timelock address", async function () {
      expect(await governanceDAO.timelock()).to.equal(timelock.address);
    });

    it("Should initialize with correct parameters", async function () {
      expect(await governanceDAO.getProposalThreshold()).to.equal(ethers.utils.parseEther("1000000"));
      expect(await governanceDAO.getQuorumVotes()).to.equal(ethers.utils.parseEther("10000000"));
      expect(await governanceDAO.getVotingDelay()).to.equal(86400); // 1 day
      expect(await governanceDAO.getVotingPeriod()).to.equal(604800); // 7 days
    });
  });

  describe("Proposal Creation", function () {
    it("Should allow creating proposals with sufficient voting power", async function () {
      const title = "Test Proposal";
      const description = "This is a test proposal";
      const data = "0x";

      await expect(governanceDAO.connect(voter1).propose(
        0, // PARAMETER_CHANGE
        title,
        description,
        data
      )).to.emit(governanceDAO, "ProposalCreated")
        .withArgs(1, voter1.address, 0, title);

      const proposal = await governanceDAO.getProposal(1);
      expect(proposal.proposer).to.equal(voter1.address);
      expect(proposal.proposalType).to.equal(0);
      expect(proposal.title).to.equal(title);
      expect(proposal.description).to.equal(description);
    });

    it("Should reject proposals with insufficient voting power", async function () {
      const title = "Test Proposal";
      const description = "This is a test proposal";
      const data = "0x";

      await expect(
        governanceDAO.connect(voter3).propose(
          0, // PARAMETER_CHANGE
          title,
          description,
          data
        )
      ).to.be.revertedWith("Insufficient voting power");
    });

    it("Should reject invalid proposal types", async function () {
      const title = "Test Proposal";
      const description = "This is a test proposal";
      const data = "0x";

      await expect(
        governanceDAO.connect(voter1).propose(
          7, // Invalid proposal type
          title,
          description,
          data
        )
      ).to.be.revertedWith("Invalid proposal type");
    });
  });

  describe("Voting", function () {
    let proposalId;

    beforeEach(async function () {
      // Create a proposal
      const title = "Test Proposal";
      const description = "This is a test proposal";
      const data = "0x";

      const tx = await governanceDAO.connect(voter1).propose(
        0, // PARAMETER_CHANGE
        title,
        description,
        data
      );
      const receipt = await tx.wait();
      proposalId = receipt.events[0].args.proposalId;

      // Fast forward past voting delay
      await ethers.provider.send("evm_increaseTime", [86401]); // Just over 1 day
      await ethers.provider.send("evm_mine");
    });

    it("Should allow voting on active proposals", async function () {
      await expect(governanceDAO.connect(voter1).castVote(proposalId, 1)) // For
        .to.emit(governanceDAO, "VoteCast")
        .withArgs(voter1.address, proposalId, 1, await governanceDAO.getVotingPower(voter1.address), "");

      const proposal = await governanceDAO.getProposal(proposalId);
      expect(proposal.forVotes).to.equal(await governanceDAO.getVotingPower(voter1.address));
    });

    it("Should allow voting with reason", async function () {
      const reason = "I support this proposal";
      
      await expect(governanceDAO.connect(voter1).castVoteWithReason(proposalId, 1, reason))
        .to.emit(governanceDAO, "VoteCast")
        .withArgs(voter1.address, proposalId, 1, await governanceDAO.getVotingPower(voter1.address), reason);
    });

    it("Should reject voting before voting period starts", async function () {
      // Create new proposal
      const title = "Test Proposal 2";
      const description = "This is a test proposal 2";
      const data = "0x";

      const tx = await governanceDAO.connect(voter1).propose(
        0, // PARAMETER_CHANGE
        title,
        description,
        data
      );
      const receipt = await tx.wait();
      const newProposalId = receipt.events[0].args.proposalId;

      await expect(
        governanceDAO.connect(voter1).castVote(newProposalId, 1)
      ).to.be.revertedWith("Voting not started");
    });

    it("Should reject voting after voting period ends", async function () {
      // Fast forward past voting period
      await ethers.provider.send("evm_increaseTime", [604801]); // Just over 7 days
      await ethers.provider.send("evm_mine");

      await expect(
        governanceDAO.connect(voter1).castVote(proposalId, 1)
      ).to.be.revertedWith("Voting ended");
    });

    it("Should reject duplicate voting", async function () {
      await governanceDAO.connect(voter1).castVote(proposalId, 1);

      await expect(
        governanceDAO.connect(voter1).castVote(proposalId, 0)
      ).to.be.revertedWith("Already voted");
    });

    it("Should reject voting with invalid support value", async function () {
      await expect(
        governanceDAO.connect(voter1).castVote(proposalId, 3)
      ).to.be.revertedWith("Invalid vote");
    });
  });

  describe("Proposal Execution", function () {
    let proposalId;

    beforeEach(async function () {
      // Create a proposal
      const title = "Test Proposal";
      const description = "This is a test proposal";
      const data = "0x";

      const tx = await governanceDAO.connect(voter1).propose(
        0, // PARAMETER_CHANGE
        title,
        description,
        data
      );
      const receipt = await tx.wait();
      proposalId = receipt.events[0].args.proposalId;

      // Fast forward past voting delay
      await ethers.provider.send("evm_increaseTime", [86401]);
      await ethers.provider.send("evm_mine");

      // Vote on proposal
      await governanceDAO.connect(voter1).castVote(proposalId, 1); // For
      await governanceDAO.connect(voter2).castVote(proposalId, 1); // For

      // Fast forward past voting period
      await ethers.provider.send("evm_increaseTime", [604801]);
      await ethers.provider.send("evm_mine");
    });

    it("Should execute successful proposals", async function () {
      const proposalState = await governanceDAO.getProposalState(proposalId);
      expect(proposalState).to.equal(4); // SUCCEEDED

      await expect(governanceDAO.execute(proposalId))
        .to.emit(governanceDAO, "ProposalExecuted")
        .withArgs(proposalId);

      const proposal = await governanceDAO.getProposal(proposalId);
      expect(proposal.status).to.equal(5); // EXECUTED
    });

    it("Should reject execution of non-succeeded proposals", async function () {
      // Create a defeated proposal
      const title = "Defeated Proposal";
      const description = "This proposal will be defeated";
      const data = "0x";

      const tx = await governanceDAO.connect(voter1).propose(
        0, // PARAMETER_CHANGE
        title,
        description,
        data
      );
      const receipt = await tx.wait();
      const defeatedProposalId = receipt.events[0].args.proposalId;

      // Fast forward past voting delay
      await ethers.provider.send("evm_increaseTime", [86401]);
      await ethers.provider.send("evm_mine");

      // Vote against proposal
      await governanceDAO.connect(voter1).castVote(defeatedProposalId, 0); // Against
      await governanceDAO.connect(voter2).castVote(defeatedProposalId, 0); // Against

      // Fast forward past voting period
      await ethers.provider.send("evm_increaseTime", [604801]);
      await ethers.provider.send("evm_mine");

      await expect(
        governanceDAO.execute(defeatedProposalId)
      ).to.be.revertedWith("Proposal not succeeded");
    });
  });

  describe("Proposal Cancellation", function () {
    let proposalId;

    beforeEach(async function () {
      // Create a proposal
      const title = "Test Proposal";
      const description = "This is a test proposal";
      const data = "0x";

      const tx = await governanceDAO.connect(voter1).propose(
        0, // PARAMETER_CHANGE
        title,
        description,
        data
      );
      const receipt = await tx.wait();
      proposalId = receipt.events[0].args.proposalId;
    });

    it("Should allow proposer to cancel proposal", async function () {
      await expect(governanceDAO.connect(voter1).cancel(proposalId))
        .to.emit(governanceDAO, "ProposalCancelled")
        .withArgs(proposalId);

      const proposal = await governanceDAO.getProposal(proposalId);
      expect(proposal.status).to.equal(2); // CANCELLED
    });

    it("Should allow owner to cancel proposal", async function () {
      await expect(governanceDAO.connect(owner).cancel(proposalId))
        .to.emit(governanceDAO, "ProposalCancelled")
        .withArgs(proposalId);
    });

    it("Should reject cancellation by non-proposer and non-owner", async function () {
      await expect(
        governanceDAO.connect(voter2).cancel(proposalId)
      ).to.be.revertedWith("Not proposer or owner");
    });

    it("Should reject cancellation of non-pending proposals", async function () {
      // Fast forward past voting delay
      await ethers.provider.send("evm_increaseTime", [86401]);
      await ethers.provider.send("evm_mine");

      await expect(
        governanceDAO.connect(voter1).cancel(proposalId)
      ).to.be.revertedWith("Cannot cancel");
    });
  });

  describe("Voting Power Management", function () {
    it("Should return correct voting power", async function () {
      const votingPower = await governanceDAO.getVotingPower(voter1.address);
      expect(votingPower).to.equal(ethers.utils.parseEther("2000000"));
    });

    it("Should track voting history", async function () {
      // Create and vote on proposal
      const title = "Test Proposal";
      const description = "This is a test proposal";
      const data = "0x";

      const tx = await governanceDAO.connect(voter1).propose(
        0, // PARAMETER_CHANGE
        title,
        description,
        data
      );
      const receipt = await tx.wait();
      const proposalId = receipt.events[0].args.proposalId;

      // Fast forward past voting delay
      await ethers.provider.send("evm_increaseTime", [86401]);
      await ethers.provider.send("evm_mine");

      await governanceDAO.connect(voter1).castVote(proposalId, 1);

      expect(await governanceDAO.hasVoted(proposalId, voter1.address)).to.be.true;
      expect(await governanceDAO.hasVoted(proposalId, voter2.address)).to.be.false;
    });
  });

  describe("Parameter Management", function () {
    it("Should allow owner to update parameters", async function () {
      await governanceDAO.setProposalThreshold(ethers.utils.parseEther("2000000"));
      expect(await governanceDAO.getProposalThreshold()).to.equal(ethers.utils.parseEther("2000000"));

      await governanceDAO.setQuorumVotes(ethers.utils.parseEther("15000000"));
      expect(await governanceDAO.getQuorumVotes()).to.equal(ethers.utils.parseEther("15000000"));

      await governanceDAO.setVotingDelay(172800); // 2 days
      expect(await governanceDAO.getVotingDelay()).to.equal(172800);

      await governanceDAO.setVotingPeriod(1209600); // 14 days
      expect(await governanceDAO.getVotingPeriod()).to.equal(1209600);
    });

    it("Should reject parameter updates from non-owner", async function () {
      await expect(
        governanceDAO.connect(voter1).setProposalThreshold(ethers.utils.parseEther("2000000"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Proposal Queries", function () {
    beforeEach(async function () {
      // Create multiple proposals of different types
      const proposals = [
        { type: 0, title: "Parameter Change", description: "Change protocol parameters" },
        { type: 1, title: "Asset Support", description: "Add new asset support" },
        { type: 2, title: "Collateral Manager", description: "Update collateral manager" }
      ];

      for (let i = 0; i < proposals.length; i++) {
        await governanceDAO.connect(voter1).propose(
          proposals[i].type,
          proposals[i].title,
          proposals[i].description,
          "0x"
        );
      }
    });

    it("Should return correct proposal count", async function () {
      expect(await governanceDAO.getProposalCount()).to.equal(3);
    });

    it("Should return proposals by type", async function () {
      const parameterChangeProposals = await governanceDAO.getProposalsByType(0);
      expect(parameterChangeProposals.length).to.equal(1);
      expect(parameterChangeProposals[0]).to.equal(1);

      const assetSupportProposals = await governanceDAO.getProposalsByType(1);
      expect(assetSupportProposals.length).to.equal(1);
      expect(assetSupportProposals[0]).to.equal(2);
    });
  });
});
