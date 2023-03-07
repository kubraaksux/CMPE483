pragma solidity ^0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";


/*
* @title MyGov
* @dev GovernentToken
* @custom:dev-run-script /Users/kubraaksu/Desktop/MyGov/untitled folder
*/


contract MyGov {
    // ERC20 standard variables
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Additional variables
    mapping(address => bool) public myGovMembers;
    
    mapping(uint => Survey) public surveys;
    address[] public proposers;
    mapping(uint => Proposal) public proposals;
    uint public proposalCount;
    
    uint public surveyCount;
    address public owner;
    uint public etherBalance;
    address[] public fundedProjects;

    // Events
    event ProposalSubmitted(address proposer, uint proposalId);
    event SurveySubmitted(address proposer, uint surveyId);
    event SurveyTaken(address taker, uint surveyId);
    event ProposalVoted(address voter, uint proposalId, bool choice);
    event ProposalFunded(address proposer, uint proposalId);
    event PaymentWithdrawn(address proposer, uint proposalId);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed from, address indexed to, uint256 value);
    

    // Structs
    struct Proposal {
        address proposer;
        string ipfsHash;
        uint voteDeadline;
        uint[] paymentAmounts;
        uint[] paySchedule;
        bool funded;
        mapping(address => bool) votes;
    }

    struct ProposalWithoutMapping {
        address proposer;
        string ipfsHash;
        uint voteDeadline;
        uint[] paymentAmounts;
        uint[] paySchedule;
        bool funded;
    }

   struct Survey {
        address proposer;
        string ipfsHash;
        uint surveyDeadline;
        uint numChoices;
        uint atmostChoice;
        mapping(address => uint[]) answers;
    }

    struct SurveyWithoutMapping {
        address proposer;
        string ipfsHash;
        uint surveyDeadline;
        uint numChoices;
        uint atmostChoice;
        bool funded;
    }

    // Functions

    // ERC20 standard functions
    function myTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function myBlanceOf(address _owner) public view returns (uint256) {
        return balanceOf[_owner];
    }

    function myAllowance(address _owner, address _spender) public view returns (uint256) {
        return allowance[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) public {
        require(balanceOf[msg.sender] >= _value && _value > 0);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
    }

    function approve(address _spender, uint256 _value) public {
        require(_spender != address(0));
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public {
        require(_to != address(0));
        require(balanceOf[_from] >= _value && allowance[_from][msg.sender] >= _value);
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
    }
    function delegateVoteTo(address memberaddr,uint projectid) public {
        require(myGovMembers[msg.sender]);
        Proposal storage proposal = proposals[projectid];
        require(proposal.votes[msg.sender] == false);
        proposal.votes[memberaddr] = true;
    }

    function donateEther() public payable {
        etherBalance += msg.value;
    }

    function donateMyGovToken(uint amount) public {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
    }

    function voteForProjectProposal(uint projectid,bool choice) public {
        require(myGovMembers[msg.sender]);
        Proposal storage proposal = proposals[projectid];
        require(proposal.votes[msg.sender] == false);
        proposal.votes[msg.sender] = choice;
        emit ProposalVoted(msg.sender, projectid, choice);
    }

    function createProposal(address proposer, string memory ipfsHash, uint voteDeadline, uint[] memory paymentAmounts, uint[] memory paySchedule) internal returns (Proposal storage) {
        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.proposer = proposer;
        proposal.ipfsHash = ipfsHash;
        proposal.voteDeadline = voteDeadline;
        proposal.paymentAmounts = paymentAmounts;
        proposal.paySchedule = paySchedule;
        proposal.funded = false;
        emit ProposalSubmitted(proposer, proposalCount);
        return proposal;
    }
    
    function submitProjectProposal(string memory ipfsHash, uint votedeadline, uint[] memory paymentamounts, uint[] memory paySchedule) public payable {
        require(balanceOf[msg.sender] >= 5 && msg.value >= 0.1 ether);
        balanceOf[msg.sender] -= 5;
        totalSupply -= 5;
        etherBalance += msg.value;
        createProposal(msg.sender, ipfsHash, votedeadline, paymentamounts, paySchedule);
    }

    function createSurvey(string memory ipfsHash,uint surveydeadline,uint numchoices, uint atmostchoice) internal returns(Survey storage) {
        surveyCount++;
        Survey storage survey = surveys[surveyCount];
        survey.proposer = msg.sender;
        survey.ipfsHash = ipfsHash;
        survey.surveyDeadline = surveydeadline;
        survey.numChoices = numchoices;
        survey.atmostChoice = atmostchoice;
        emit SurveySubmitted(msg.sender, surveyCount);
        return survey;
    }

   function submitSurvey(string memory ipfsHash, uint surveydeadline, uint numchoices, uint atmostchoice) public {
        require(balanceOf[msg.sender] >= 5);
        balanceOf[msg.sender] -= 5;
        totalSupply -= 5;
        createSurvey(ipfsHash, surveydeadline, numchoices, atmostchoice);
    }


    function takeSurvey(uint surveyid,uint[] memory choices) public {
        Survey storage survey = surveys[surveyid];
        require(survey.surveyDeadline > block.timestamp);
        require(choices.length <= survey.atmostChoice);
        for (uint i = 0; i < choices.length; i++) {
            require(choices[i] <= survey.numChoices);
        }
        survey.answers[msg.sender] = choices;
        emit SurveyTaken(msg.sender, surveyid);
    }

    function votesCount() public view returns (uint count) {
        return proposers.length;
    }

    function reserveProjectGrant(uint projectid) public {
        require(myGovMembers[msg.sender]);
        Proposal storage proposal = proposals[projectid];
        require(proposal.funded == false);
        require(etherBalance >= proposal.paymentAmounts[0]);
        uint yesVotes = 0;
        uint noVotes = 0;
        for (uint i = 0; i < votesCount(); i++) {
            if (proposal.votes[proposers[i]]) {
                yesVotes++;
            } else {
                noVotes++;
            }
        }
        require(yesVotes > noVotes);
        proposal.funded = true;
        etherBalance -= proposal.paymentAmounts[0];
        proposal.paySchedule[0] = block.timestamp;
        emit ProposalFunded(proposal.proposer, projectid);
    }

    function withdrawProjectPayment(uint projectid) public {
        require(myGovMembers[msg.sender]);
        Proposal storage proposal = proposals[projectid];
        require(proposal.funded == true);
        require(proposal.proposer == msg.sender);
        uint yesVotes = 0;
        for(uint i = 0; i < votesCount(); i++){
            if(proposal.votes[proposers[i]]){
                yesVotes++;
            }
        }
        require(yesVotes > 0);
        require(yesVotes >= votesCount() / 100);
        uint paymentAmount = 0;
        uint paymentIndex = 0;
        for(uint i = 0; i < proposal.paySchedule.length; i++){
            if(proposal.paySchedule[i] == 0){
                paymentAmount = proposal.paymentAmounts[i];
                paymentIndex = i;
                break;
            }
        }
        require(etherBalance >= paymentAmount);
        etherBalance -= paymentAmount;
        proposal.paySchedule[paymentIndex] = block.timestamp;
        emit PaymentWithdrawn(proposal.proposer, projectid);
    }
    
    
    // mapping(address => bool) surveyAnswers;

    function getSurveyAnswers(uint surveyid) public view returns(uint[] memory answers) {
        Survey storage survey = surveys[surveyid];
        answers = survey.answers[msg.sender];
    }

    function getSurveyAnswersByAddress(uint surveyid, address user) public view returns(uint[] memory answers) {
        Survey storage survey = surveys[surveyid];
        answers = survey.answers[user];
    }

    function getSurveyAnswersCount(uint surveyid) public view returns(uint count) {
        Survey storage survey = surveys[surveyid];
        count = survey.answers[msg.sender].length;
    }

    function getSurveyAnswersCountByAddress(uint surveyid, address user) public view returns(uint count) {
        Survey storage survey = surveys[surveyid];
        count = survey.answers[user].length;
    }

    function getSurveyInfo(uint surveyid) public view returns(string memory ipfshash,uint surveydeadline,uint numchoices, uint atmostchoice) {
        Survey storage survey = surveys[surveyid];
        return (survey.ipfsHash, survey.surveyDeadline, survey.numChoices, survey.atmostChoice);
    }

    function getSurveyOwner(uint surveyid) public view returns(address surveyowner) {
        Survey storage survey = surveys[surveyid];
        surveyowner = survey.proposer;
    }

    function getSurveyResults(uint surveyid) public view returns(uint[] memory results) {
        Survey storage survey = surveys[surveyid];
        results = new uint[](survey.numChoices);
        for (uint i = 0; i < survey.numChoices; i++) {
            results[i] = 0;
        }
        for (uint i = 0; i < votesCount(); i++) {
            for (uint j = 0; j < survey.answers[proposers[i]].length; j++) {
                results[survey.answers[proposers[i]][j]]++;
            }
        }
        return results;
    }

    function getIsProjectFunded(uint projectid) public view returns(bool funded) {
        Proposal storage proposal = proposals[projectid];
        funded = proposal.funded;
    }

    function getProjectNextPayment(uint projectid) public view returns(int next) {
        Proposal storage proposal = proposals[projectid];
        for (uint i = 0; i < proposal.paySchedule.length; i++) {
            if (proposal.paySchedule[i] == 0) {
                next = int(i);
                return next;
            }
        }
        next = -1;
        return next;
    }   

    function getProjectOwner(uint projectid) public view returns(address projectowner) {
        Proposal storage proposal = proposals[projectid];
        projectowner = proposal.proposer;
    }

    function getProjectInfo(uint activityid) public view returns(string memory ipfshash,uint votedeadline,uint[] memory paymentamounts, uint[] memory payschedule) {
        Proposal storage proposal = proposals[activityid];
        return (proposal.ipfsHash, proposal.voteDeadline, proposal.paymentAmounts, proposal.paySchedule);
    }

    function getNoOfProjectProposals() public view returns(uint numproposals) {
        numproposals = proposalCount;
    }

    function getNoOfFundedProjects () public view returns(uint numfunded) {
        numfunded = fundedProjects.length;
    }

    function getEtherReceivedByProject (uint projectid) public view returns(uint amount) {
        Proposal storage proposal = proposals[projectid];
        amount = proposal.paymentAmounts[0];
    }

    function getEtherBalance() public view returns(uint amount) {
        amount = etherBalance;
    }

    function getEtherBalanceOf(address user) public view returns(uint amount) {
        amount = balanceOf[user];
    }

    function getNoOfSurveys() public view returns(uint numsurveys) {
        numsurveys = surveyCount;
    }


} 



















    







   












    







