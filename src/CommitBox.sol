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

    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public receiver;

    // One commitment takes up >3 slots
    struct Commitment {
        // new slot (160 + 96 = 256)
        address token;
        uint96 amount;
        // new slot (160 + 40 + 40 + 8 = 248)
        address user;
        uint40 deadline;
        // after claimTime, it becomes impossible to resolve & the original user can
        // collect their funds
        uint40 claimTime;
        uint8 bitmap;
        // new slot (160)
        address resolver;
        // new slot(s)
        string text;
    }

    Commitment[] public commitments;
    mapping(address user => uint256[] ids) public userCommitments;
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

    constructor(address _owner, address _receiver) {
        _initializeOwner(_owner);
        emit ReceiverChange(receiver, _receiver);
        receiver = _receiver;
    }

    function commitETH(
        uint40 deadline,
        uint40 claimTime,
        string memory text,
        address resolver
    )
        external
        payable
        returns (uint256)
    {
        return _commit(ETH, uint96(msg.value), deadline, claimTime, text, resolver);
    }

    function commit(
        address token,
        uint96 amount,
        uint40 deadline,
        uint40 claimTime,
        string memory text,
        address resolver
    )
        external
        returns (uint256)
    {
        token.safeTransferFrom(msg.sender, address(this), amount);
        return _commit(token, amount, deadline, claimTime, text, resolver);
    }

    function _commit(
        address token,
        uint96 amount,
        uint40 deadline,
        uint40 claimTime,
        string memory text,
        address resolver
    )
        internal
        returns (uint256)
    {
        require(claimTime >= deadline, BadConfig());

        uint256 id = commitments.length;
        emit NewCommitment(id, token, amount, deadline, claimTime, text);
        commitments.push(
            Commitment({
                token: token,
                amount: amount,
                user: msg.sender,
                deadline: deadline,
                claimTime: claimTime,
                bitmap: 0,
                resolver: resolver,
                text: text
            })
        );
        userCommitments[msg.sender].push(id);
        return id;
    }

    function resolve(uint256 id, bool happened) external {
        Commitment storage c = commitments[id];

        require(c.resolver == msg.sender, Unauthorized());
        require(!c.bitmap.get(RESOLVED), AlreadyResolved());

        emit Resolved(id, msg.sender, happened);
        c.bitmap = c.bitmap.set(RESOLVED);

        address target = happened ? c.user : receiver;

        // Resolver can only burn the tokens after the deadline
        // but allow an early exit if the task is completed early
        if (happened) {
            c.bitmap = c.bitmap.set(SUCCESS);
        } else {
            require(block.timestamp >= c.deadline && block.timestamp <= c.claimTime, Early());
        }

        _send(c.token, target, c.amount);
    }

    function claim(uint256 id) external {
        Commitment storage c = commitments[id];
        require(block.timestamp >= c.claimTime, Early());
        require(!c.bitmap.get(RESOLVED), AlreadyResolved());
        require(c.user == msg.sender || isResolver[id][msg.sender], Unauthorized());

        emit Resolved(id, msg.sender, true);

        c.bitmap = c.bitmap.set(RESOLVED).set(SUCCESS);

        _send(c.token, c.user, c.amount);
    }

    function _send(address token, address user, uint256 amount) internal {
        if (token == ETH) {
            payable(user).transfer(amount);
        } else {
            token.safeTransfer(user, amount);
        }
    }
}
