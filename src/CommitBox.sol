// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29;

import { Ownable } from "solady/src/auth/Ownable.sol";

contract CommitBox is Ownable {
    event NewCommitment(uint256 id, address token, uint96 amount, uint48 deadline, uint48 resolveTime, string text);
    event Success(uint256 id, address resolver);
    event Failed(uint256 id, address resolver);

    error BadConfig();
    error Early();
    error AlreadyResolved();

    address public receiver;

    struct Commitment {
        // new slot
        address token;
        uint96 amount;
        // new slot
        uint48 deadline;
        uint48 resolveTime;
        bool resolved;
        // new slot(s)
        string text;
    }

    Commitment[] public commitments;
    mapping(address => uint256[] ids) public userCommitments;
    mapping(uint256 id => mapping(address resolver => bool yes)) isResolver;

    function listUserCommitments(
        address user,
        uint256 start,
        uint256 end
    )
        external
        view
        returns (Commitment[] memory subset)
    {
        uint256[] storage fullList = userCommitments[user];

        require(start <= end, BadConfig());
        require(start < fullList.length, BadConfig());

        if (end >= fullList.length) end = fullList.length - 1;

        uint256 range = end - start;
        subset = new Commitment[](range + 1);

        for (uint256 i = 0; i <= range; ++i) {
            subset[i] = commitments[fullList[i + start]];
        }
    }

    constructor() {
        _initializeOwner(msg.sender);
    }

    function commit(
        address token,
        uint96 amount,
        uint48 deadline,
        uint48 resolveTime,
        string memory text,
        address[] memory resolvers
    )
        external
        returns (uint256)
    {
        emit NewCommitment(commitments.length, token, amount, deadline, resolveTime, text);
        commitments.push(
            Commitment({
                token: token,
                amount: amount,
                deadline: deadline,
                resolveTime: resolveTime,
                resolved: false,
                text: text
            })
        );
    }

    function resolve(uint256 id, bool happened) external {
        Commitment storage c = commitments[id];
        require(block.timestamp >= c.deadline, Early());
        require(isResolver[id][msg.sender], Unauthorized());
        require(!c.resolved, AlreadyResolved());

        if (happened) {
            c.resolved = true;
        } else {
            c.resolved = false;
        }
    }
}
