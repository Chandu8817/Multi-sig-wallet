// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {MultiSig} from "../src/MultiSig.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MultiSigTest is Test {
    MultiSig private multiSig;

    using ECDSA for bytes32;

    uint256 privateKey1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 privateKey2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 privateKey3 = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    address owner1;
    address owner2;
    address owner3;
    address[] private owners;
    uint256 private requiredConfirmations;

    function setUp() public {
        owner1 = vm.addr(privateKey1);
        owner2 = vm.addr(privateKey2);
        owner3 = vm.addr(privateKey3);
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        requiredConfirmations = 2;

        multiSig = new MultiSig(owners, requiredConfirmations);
    }

    function testOwners() public view {
        assertEq(multiSig.getOwners().length, owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(multiSig.getOwners()[i], owners[i]);
        }
    }

    function testDeploy() public view {
        assertEq(multiSig.getOwners().length, 3);
        assertEq(multiSig.requiredConfirmations(), requiredConfirmations);
    }

    function testAddOwner() public {
        // 
        address newOwner = address(0x4);

        // Simulate the call as `owner1`
        vm.prank(owner1);
        multiSig.addOwner(newOwner);

        // Verify new owner added
        assertEq(multiSig.getOwners().length, 4);
        assertEq(multiSig.getOwners()[3], newOwner);
    }

    function testRemoveOwner() public {
        // 
        address ownerToRemove = multiSig.getOwners()[2];

        // Simulate the call as `owner1`
        vm.prank(owner1);
        multiSig.removeOwner(ownerToRemove);

        // Verify owner removed
        assertEq(multiSig.getOwners().length, 2);
        assertEq(multiSig.getOwners()[0], owners[0]);
        assertEq(multiSig.getOwners()[1], owners[1]);
    }

    function testChangeRequiredConfirmations() public {
        
        uint256 newRequiredConfirmations = 1;

        // Simulate the call as `owner1`
        vm.prank(owner1);
        multiSig.changeRequiredConfirmations(newRequiredConfirmations);

        // Verify required confirmations changed
        assertEq(multiSig.requiredConfirmations(), newRequiredConfirmations);
    }

    function testcreateTransaction() public {
        
        address to = address(0x5);
        uint256 value = 1 ether;
        bytes memory data = "";

        // Simulate the call as `owner1`
        vm.prank(owner1);
        multiSig.createTransaction(to, value, data);

        // Verify transaction submitted
        assertEq(multiSig.getTransactionCount(), 1);
        (address txTo, uint256 txValue, bytes memory txData, bool executed, uint256 _confirmations) =
            multiSig.getTransaction(0);
        assertEq(txTo, to);
        assertEq(txValue, value);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(_confirmations, 0);
    }

    function testConfirmTransaction() public {
        
        address to = address(0x5);
        uint256 value = 1 ether;
        bytes memory data = "";

        // Create a transaction first
        vm.prank(owner1);
        multiSig.createTransaction(to, value, data);

        // Confirm the transaction as owner1
        vm.prank(owner1);
        multiSig.confirmTransaction(0);

        // Verify transaction confirmed
        (address txTo, uint256 txValue, bytes memory txData, bool executed, uint256 _confirmations) =
            multiSig.getTransaction(0);
        assertEq(_confirmations, 1);
        assertEq(txTo, to);
        assertEq(txValue, value);
        assertEq(txData, data);
        assertFalse(executed);
    }

    function testExecuteTransaction() public {
        
        address to = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc; // Use the test contract as the recipient
        uint256 value = 1 ether;
        bytes memory data = "";
        uint256 balanceBefore = to.balance;
        // Ensure the contract has enough balance to execute the transaction
        vm.deal(address(multiSig), value * 3); // Give this contract enough ether

        // Create a transaction first
        vm.prank(owner1);
        multiSig.createTransaction(to, value, data);

        // Confirm the transaction as owner1
        vm.prank(owner2);
        multiSig.confirmTransaction(0);

        // Confirm the transaction as another owner
        vm.prank(multiSig.getOwners()[2]);
        multiSig.confirmTransaction(0);

        vm.prank(multiSig.getOwners()[0]);
        multiSig.confirmTransaction(0);

        // // Execute the transaction
        vm.prank(owner1);
        multiSig.executeTransaction(0);
        console.log("Transaction executed successfully", balanceBefore, to.balance);

        // Verify transaction executed
        (address txTo, uint256 txValue,, bool executed, uint256 _confirmations) = multiSig.getTransaction(0);
        assertTrue(executed);
        assertEq(_confirmations, 3); // Both owners confirmed
        assertEq(txTo, to);
        assertEq(txValue, value);
    }

    function testNonOwnerCannotCreateTx() public {
        address nonOwner = address(0xdead);
        vm.prank(nonOwner);
        vm.expectRevert();
        multiSig.createTransaction(address(0x1), 1 ether, "");
    }

    function testDoubleConfirmationFails() public {
        
        vm.prank(owner1);
        multiSig.createTransaction(address(0x5), 1 ether, "");

        vm.prank(owner1);
        multiSig.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(); // or expect specific error message
        multiSig.confirmTransaction(0);
    }

    function testCannotExecuteTwice() public {
        
        address to = address(0x5);
        uint256 value = 1 ether;
        vm.deal(address(multiSig), value);

        vm.startPrank(owner1);
        multiSig.createTransaction(to, value, "");
        multiSig.confirmTransaction(0);
        vm.stopPrank();

        vm.prank(multiSig.getOwners()[2]);
        multiSig.confirmTransaction(0);

        vm.prank(owner1);
        multiSig.executeTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(); // Already executed
        multiSig.executeTransaction(0);
    }

    function testCannotExecuteWithoutEnoughConfirmations() public {
        
        address to = address(0x5);
        uint256 value = 1 ether;
        vm.deal(address(multiSig), value);

        vm.prank(owner1);
        multiSig.createTransaction(to, value, "");

        vm.prank(owner1);
        vm.expectRevert(); // Not enough confirmations
        multiSig.executeTransaction(0);
    }

    function testRemovedOwnerCannotSubmitOrConfirm() public {
        address removedOwner = owners[2];
        vm.prank(owners[0]);
        multiSig.removeOwner(removedOwner);

        vm.prank(removedOwner);
        vm.expectRevert();
        multiSig.createTransaction(address(0x5), 1 ether, "");

        vm.prank(owners[0]);
        multiSig.createTransaction(address(0x5), 1 ether, "");

        vm.prank(removedOwner);
        vm.expectRevert();
        multiSig.confirmTransaction(0);
    }

    function testAddSameOwnerTwiceShouldRevert() public {
        address newOwner = address(0x4);
        vm.prank(owners[0]);
        multiSig.addOwner(newOwner);

        vm.prank(owners[0]);
        vm.expectRevert();
        multiSig.addOwner(newOwner);
    }

    function testChangeRequiredConfirmationsBeyondOwnersShouldFail() public {
        vm.prank(owners[0]);
        vm.expectRevert();
        multiSig.changeRequiredConfirmations(4);
    }

    function testConfirmationRemoveAfterOwnerRemoved() public {
        vm.prank(owners[0]);
        multiSig.createTransaction(address(0x9), 1 ether, "");

        vm.prank(owners[2]);
        multiSig.confirmTransaction(0);

        vm.prank(owners[0]);
        multiSig.removeOwner(owners[2]);

        (,,,, uint256 confirmations) = multiSig.getTransaction(0);
        assertEq(confirmations, 0); // confirmation still counted
    }

    function testRemovedOwnerCannotConfirmAfterRemoval() public {
        vm.prank(owners[0]);
        multiSig.removeOwner(owners[2]);

        vm.prank(owners[2]);
        vm.expectRevert();
        multiSig.confirmTransaction(0);
    }

    function testReceiveEtherWithNoData() public {
        vm.deal(address(this), 1 ether);
        (bool sent,) = payable(address(multiSig)).call{value: 1 ether}("");
        require(sent, "Send failed");
        assertEq(address(multiSig).balance, 1 ether);
    }

    function testExecuteTransactionToRevertingContract() public {
        address revertTarget = address(new RevertingContract());
        vm.deal(address(multiSig), 1 ether);

        vm.prank(owners[0]);
        multiSig.createTransaction(revertTarget, 1 ether, "");
        vm.prank(owners[1]);
        multiSig.confirmTransaction(0);

        vm.prank(owners[0]);
        vm.expectRevert("NOT_ENOUGH_CONFIRMATIONS()");
        multiSig.executeTransaction(0);

        (,,, bool executed,) = multiSig.getTransaction(0);
        assertFalse(executed);
    }

    function testMultipleTransactionsIndependentConfirmation() public {
        vm.prank(owners[0]);
        multiSig.createTransaction(address(0x5), 1 ether, "");
        vm.prank(owners[0]);
        multiSig.createTransaction(address(0x6), 2 ether, "");

        vm.prank(owners[1]);
        multiSig.confirmTransaction(1);

        (,,,, uint256 confirmations0) = multiSig.getTransaction(0);
        (,,,, uint256 confirmations1) = multiSig.getTransaction(1);

        assertEq(confirmations0, 0);
        assertEq(confirmations1, 1);
    }

    function testConfirmMoreThanRequired() public {
        vm.prank(owners[0]);
        multiSig.createTransaction(address(0x5), 1 ether, "");
        vm.prank(owners[1]);
        multiSig.confirmTransaction(0);
        vm.prank(owners[2]);
        multiSig.confirmTransaction(0);

        (,,,, uint256 confirmations) = multiSig.getTransaction(0);
        assertEq(confirmations, 2);
    }

    function testEventsEmitted() public {
        vm.recordLogs();
        vm.prank(owners[0]);
        multiSig.createTransaction(address(0x7), 1 ether, "");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertGt(logs.length, 0);
    }

    function testRemoveAllOwnersShouldFail() public {
        vm.prank(owners[0]);
        multiSig.removeOwner(owners[2]);
        vm.prank(owners[0]);
        multiSig.removeOwner(owners[1]);

        vm.prank(owners[0]);

        vm.expectRevert();
        multiSig.removeOwner(owners[0]); // only 1 owner left
    }

    function testCannotAddOwnerIfAlreadyExists() public {
        address existingOwner = owners[1];
        vm.prank(owners[0]);
        vm.expectRevert();
        multiSig.addOwner(existingOwner); // trying to add an existing owner
    }

    function testExecuteWithSignatures() public {
        address to = address(0xBABE);
        uint256 value = 0.5 ether;
        bytes memory data = "";
        uint256 nonce = 1;
        vm.deal(address(multiSig), 1 ether); // Ensure the wallet has enough balance

          // 1) Recreate the signed message and prefix per EIP-191
        bytes32 rawHash = keccak256(
            abi.encodePacked(address(multiSig), to, value, data, nonce)
        );
        bytes32 ethHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash)
        );

        // 2) Sign the prefixed message hash with each owner's private key
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, ethHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, ethHash);

        bytes memory sig1 = abi.encodePacked(r1, s1, v1);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);

        // 3) Recover and sort signatures by address
        bytes[] memory sigs = new bytes[](2);
        address signer1 = ethHash.recover(sig1);
        address signer2 = ethHash.recover(sig2);
        if (signer1 < signer2) {
            sigs[0] = sig1;
            sigs[1] = sig2;
        } else {
            sigs[0] = sig2;
            sigs[1] = sig1;
        }

        // 4) Execute the transaction with signatures
        multiSig.executeWithSignatures(to, value, data, nonce, sigs);

        // 5) Assert balances updated correctly
        assertEq(address(to).balance, value, "Recipient should receive ETH");
        assertEq(address(multiSig).balance, 1 ether - value, "Wallet balance should decrease");
    }
}

contract RevertingContract {
    receive() external payable {
        revert("I always revert");
    }
}
