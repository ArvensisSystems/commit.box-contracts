// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.29;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { LynBitmap8 } from "./LynBitmap.sol";

contract CommitBox is Ownable {
    using SafeTransferLib for address;
    using LynBitmap8 for uint8;

    event NewCommitment(uint256 id, address token, uint96 amount, uint48 deadline, uint48 claimTime, string text);
    event Resolved(uint256 id, address resolver, bool happened);
    event ReceiverChange(address prev, address next);

    error BadConfig();
    error Early();
    error AlreadyResolved();

    uint8 internal constant RESOLVED = 0;
    uint8 internal constant SUCCESS = 1;

    address public receiver;

    struct Commitment {
        // new slot
        address token;
        uint96 amount;
        // new slot
        address user;
        uint40 deadline;
        uint40 claimTime;
        uint8 bitmap;
        // new slot(s)
        string text;
    }

    Commitment[] public commitments;
    mapping(address => uint256[] ids) public userCommitments;
    mapping(uint256 id => mapping(address resolver => bool yes)) public isResolver;

    function setReceiver(address next) public onlyOwner {
        emit ReceiverChange(receiver, next);
        receiver = next;
    }

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
        uint40 deadline,
        uint40 claimTime,
        string memory text,
        address[] memory resolvers
    )
        external
        returns (uint256)
    {
        uint256 id = commitments.length;
        emit NewCommitment(id, token, amount, deadline, claimTime, text);

        require(claimTime >= deadline, BadConfig());

        commitments.push(
            Commitment({
                token: token,
                amount: amount,
                user: msg.sender,
                deadline: deadline,
                claimTime: claimTime,
                bitmap: 0,
                text: text
            })
        );

        token.safeTransferFrom(msg.sender, address(this), amount);

        for (uint256 i = 0; i < resolvers.length; ++i) {
            isResolver[id][resolvers[i]] = true;
        }

        return id;
    }

    function resolve(uint256 id, bool happened) external {
        Commitment storage c = commitments[id];

        require(isResolver[id][msg.sender], Unauthorized());
        require(!c.bitmap.get(RESOLVED), AlreadyResolved());

        emit Resolved(id, msg.sender, happened);

        // Resolver can only burn the tokens after the deadline
        // but allow an early exit if the task is completed early
        if (happened) {
            c.token.safeTransfer(c.user, c.amount);
            c.bitmap.set(SUCCESS);
        } else {
            require(block.timestamp >= c.deadline && block.timestamp <= c.claimTime, Early());
            c.token.safeTransfer(receiver, c.amount);
        }
        c.bitmap.set(RESOLVED);
    }

    function claim(uint256 id) external {
        Commitment storage c = commitments[id];
        require(block.timestamp >= c.claimTime, Early());
        require(!c.bitmap.get(RESOLVED), AlreadyResolved());
        require(c.user == msg.sender || isResolver[id][msg.sender], Unauthorized());

        emit Resolved(id, msg.sender, true);

        c.bitmap.set(RESOLVED);
        c.bitmap.set(SUCCESS);
        c.token.safeTransfer(c.user, c.amount);
    }
}
