// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRWAToken.sol";

/**
 * @title RWAGoverning
 * @dev Governance contract for RWA asset management decisions
 */
contract RWAGoverning is AccessControl {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");

    IRWAToken public immutable rwaToken;
    
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant QUORUM_THRESHOLD = 10; // 10% of total supply
    uint256 public constant APPROVAL_THRESHOLD = 50; // 50% of votes

    enum ProposalStatus { Pending, Active, Succeeded, Defeated, Executed, Cancelled }
    enum ProposalType { ValuationUpdate, CustodianChange, AssetDeactivation, Other }

    struct Proposal {
        uint256 proposalId;
        address proposer;
        ProposalType proposalType;
        string description;
        bytes data; // Encoded function call data
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalStatus status;
        mapping(address => bool) hasVoted;
        mapping(address => Vote) votes;
    }

    enum Vote { None, For, Against, Abstain }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        Vote vote,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    constructor(address rwaTokenAddress) {
        require(rwaTokenAddress != address(0), "RWAGoverning: token cannot be zero address");
        rwaToken = IRWAToken(rwaTokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(VOTER_ROLE, msg.sender);
    }

    /**
     * @dev Create a new proposal
     */
    function createProposal(
        ProposalType proposalType,
        string memory description,
        bytes memory data
    ) external onlyRole(PROPOSER_ROLE) returns (uint256) {
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.proposalId = proposalId;
        proposal.proposer = msg.sender;
        proposal.proposalType = proposalType;
        proposal.description = description;
        proposal.data = data;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        proposal.status = ProposalStatus.Active;

        emit ProposalCreated(proposalId, msg.sender, proposalType, description, proposal.startTime, proposal.endTime);
        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     */
    function castVote(uint256 proposalId, Vote vote) external onlyRole(VOTER_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active, "RWAGoverning: proposal not active");
        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "RWAGoverning: voting period ended");
        require(!proposal.hasVoted[msg.sender], "RWAGoverning: already voted");
        require(vote != Vote.None, "RWAGoverning: invalid vote");

        uint256 weight = rwaToken.balanceOf(msg.sender);
        require(weight > 0, "RWAGoverning: no voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = vote;

        if (vote == Vote.For) {
            proposal.forVotes += weight;
        } else if (vote == Vote.Against) {
            proposal.againstVotes += weight;
        } else if (vote == Vote.Abstain) {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, vote, weight);

        // Check if proposal can be finalized
        _checkProposalStatus(proposalId);
    }

    /**
     * @dev Execute a successful proposal
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Succeeded, "RWAGoverning: proposal not succeeded");
        require(block.timestamp > proposal.endTime, "RWAGoverning: voting period not ended");

        proposal.status = ProposalStatus.Executed;

        // Execute the proposal data (would need to decode and call appropriate contract)
        // This is a simplified version - in production, you'd use a more sophisticated execution mechanism
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancel a proposal
     */
    function cancelProposal(uint256 proposalId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active || proposal.status == ProposalStatus.Pending, "RWAGoverning: cannot cancel");
        
        proposal.status = ProposalStatus.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    /**
     * @dev Get proposal details
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 proposalId_,
        address proposer,
        ProposalType proposalType,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        ProposalStatus status
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposalId,
            proposal.proposer,
            proposal.proposalType,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.status
        );
    }

    /**
     * @dev Check if user has voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    /**
     * @dev Get user's vote
     */
    function getVote(uint256 proposalId, address voter) external view returns (Vote) {
        return proposals[proposalId].votes[voter];
    }

    function _checkProposalStatus(uint256 proposalId) private {
        Proposal storage proposal = proposals[proposalId];
        if (block.timestamp <= proposal.endTime) return;

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalSupply = rwaToken.totalSupply();
        uint256 quorum = (totalSupply * QUORUM_THRESHOLD) / 100;

        if (totalVotes >= quorum) {
            uint256 approvalPercentage = (proposal.forVotes * 100) / totalVotes;
            if (approvalPercentage >= APPROVAL_THRESHOLD) {
                proposal.status = ProposalStatus.Succeeded;
            } else {
                proposal.status = ProposalStatus.Defeated;
            }
        } else {
            proposal.status = ProposalStatus.Defeated;
        }
    }
}
