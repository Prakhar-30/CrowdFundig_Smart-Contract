//SPDX-License-Identifier:GPL-3.0

pragma solidity >0.5.0 <=0.9.9;

struct fund {
    address fundsLocation;
    string fundname;
    uint target;
    uint deadline;
    uint min_contri;
}

struct Contribution {
    address Contributor;
    uint ammount_contributed;
}

contract Crowdfund {

    address public manager;
    mapping (uint => fund) public FundingFor;
    mapping (uint => Contribution[]) public Fundings;
    mapping (address => uint) public Collected_Ammount;
    mapping(uint => mapping(address => bool)) public votesForFund;

    uint FundID;
    
    constructor() {
        manager = msg.sender;
    }

    function CreateFund(address fundsLocation, string memory fundname, uint target, uint deadline, uint min_contri) public {
        require(msg.sender == manager, "only managers can create the requirements of fund");
        require(deadline > block.timestamp, "only future fund requirements can be created");
        require(min_contri > 0.005 ether, "contribution too low, minimum of 0.005 ethers are required");
        require(fundsLocation != manager, "manager cannot add their accounts in crowd funding");
        
        FundingFor[FundID++] = fund(fundsLocation, fundname, target, deadline, min_contri);
    }

    function contribute(uint id) payable external {
        require(block.timestamp < FundingFor[id].deadline, "the deadline has already passed");
        require(msg.value >= FundingFor[id].min_contri, "the amount to contribute is too low (contribution amount should be greater than the minimum contribution of the requirement)");
        Fundings[id].push(Contribution(msg.sender, msg.value));
        Collected_Ammount[FundingFor[id].fundsLocation] += msg.value;
    }

    function returnPayments(uint id) public {
        require(msg.sender == manager, "only manager can initiate the refund protocol");
        require(Collected_Ammount[FundingFor[id].fundsLocation] >= FundingFor[id].target, "Target needs to be met");
        require(FundingFor[id].deadline < block.timestamp, "The deadline still has to be met first");

        // uint amount_to_be_refunded = Collected_Ammount[FundingFor[id].fundsLocation];
        Collected_Ammount[FundingFor[id].fundsLocation] = 0;
        for (uint i = 0; i < Fundings[id].length; i++) {
            Contribution storage contrib = Fundings[id][i];
            address contributor = contrib.Contributor;
            uint amount = contrib.ammount_contributed;
            (bool sent, ) = contributor.call{value: amount}("");
            require(sent, "Transfer failed");
        }
    }

    function voting(uint id, bool vote) public {
        require(Fundings[id].length > 0, "No contributions made for this fund");
        bool isContributor = false;
        for (uint j = 0; j < Fundings[id].length; j++) {
            if (Fundings[id][j].Contributor == msg.sender) {
                isContributor = true;
                break;
            }
        }
        require(isContributor, "Only contributors can vote");
        votesForFund[id][msg.sender] = vote;
    }

    function PermissionToSendOrRefund(uint id) public {
        require(msg.sender == manager, "Only manager can initiate the refund protocol");
        require(block.timestamp > FundingFor[id].deadline, "The deadline still has to be met first");

        uint collected = Collected_Ammount[FundingFor[id].fundsLocation];
        require(collected >= FundingFor[id].target, "Funding target requirements not met");

        uint votesForRefund = 0;
        uint totalVotes = 0;
        for (uint j = 0; j < Fundings[id].length; j++) {
            address contributor = Fundings[id][j].Contributor;
            if (votesForFund[id][contributor]) {
                votesForRefund++;
            }
            totalVotes++;
        }

        if (votesForRefund > totalVotes / 2) {
            returnPayments(id);
        } else {
            (bool sent, ) = FundingFor[id].fundsLocation.call{value: Collected_Ammount[FundingFor[id].fundsLocation]}("");
            require(sent, "Transfer failed");
            Collected_Ammount[FundingFor[id].fundsLocation] = 0;
        }
    }
}
