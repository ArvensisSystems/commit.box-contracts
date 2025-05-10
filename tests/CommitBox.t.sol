// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { Test } from "forge-std/src/Test.sol";

import { MockERC20 } from "src/mock/MockERC20.sol";
import { CommitBox, Ownable } from "src/CommitBox.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract CommitBoxTest is Test {
    CommitBox internal box;
    MockERC20 internal token;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.
        box = new CommitBox(address(this), address(0x31313));
        token = new MockERC20();
    }

    function testListCommitments(uint256 iterations) external {
        iterations = bound(iterations, 1, 100);
        token.mint(address(this), 1 ether * iterations);
        address[] memory x = new address[](1);
        x[0] = address(0x222);

        token.approve(address(box), 1 ether * iterations);

        for (uint256 i = 0; i < iterations; i++) {
            box.commit(
                address(token),
                1 ether,
                uint40(block.timestamp + 1 weeks + i),
                uint40(block.timestamp + 1 weeks + i + 1),
                "nya",
                x
            );
        }

        CommitBox.Commitment[] memory list = box.listUserCommitments(address(this), 0, iterations);

        for (uint256 i = 0; i < list.length; i++) {
            assertEq(list[i].token, address(token));
            assertEq(list[i].amount, 1 ether);
            assertEq(list[i].deadline, block.timestamp + 1 weeks + i);
            assertEq(list[i].claimTime, block.timestamp + 1 weeks + i + 1);
        }
    }

    function testCanResolve() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1 weeks);
        vm.prank(address(0x222));
        box.resolve(id, true);
        assertEq(token.balanceOf(address(this)), 1 ether);
    }

    function testCannotResolveUnauthorized() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1 weeks);
        vm.prank(address(0x111));
        vm.expectRevert(Ownable.Unauthorized.selector);
        box.resolve(id, true);
    }

    function testCannotResolveFalseEarly() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1 days);
        vm.prank(address(0x222));
        vm.expectRevert(CommitBox.Early.selector);
        box.resolve(id, false);
    }

    function testCanResolveTrueEarly() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1 days);
        vm.prank(address(0x222));
        box.resolve(id, true);
    }

    function testCanClaimAfterClaimTime() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1.5 weeks);
        box.claim(id);
    }

    function testCannotClaimBeforeClaimTime() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1 weeks);
        vm.expectRevert(CommitBox.Early.selector);
        box.claim(id);
    }

    function testCannotResolveAfterClaimTime() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1.5 weeks);
        vm.expectRevert(Ownable.Unauthorized.selector);
        box.resolve(id, false);
    }

    function testCannotResolveTwice() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        vm.startPrank(address(0x222));
        skip(1 weeks);
        box.resolve(id, false);

        vm.expectRevert(CommitBox.AlreadyResolved.selector);
        box.resolve(id, false);
    }

    function testCannotClaimTwice() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1.5 weeks);
        box.claim(id);
        vm.expectRevert(CommitBox.AlreadyResolved.selector);
        box.claim(id);
    }

    function testCannotResolveAndClaim() external {
        token.mint(address(this), 1 ether);
        token.approve(address(box), 1 ether);

        address[] memory x = new address[](1);
        x[0] = address(0x222);

        uint256 id = box.commit(
            address(token), 1 ether, uint40(block.timestamp + 1 weeks), uint40(block.timestamp + 1.5 weeks), "nya", x
        );

        skip(1 weeks);
        vm.prank(address(0x222));
        box.resolve(id, false);
        skip(1 weeks);
        vm.expectRevert(CommitBox.AlreadyResolved.selector);
        box.claim(id);
    }
}
