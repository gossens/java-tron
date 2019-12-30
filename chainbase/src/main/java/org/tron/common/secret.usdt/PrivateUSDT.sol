pragma solidity ^0.4.0;

import "./MerkleTree.sol";
import "./USDTToken.sol";

contract PrivateUSDT {

    USDTToken private usdtToken; // the  ERC-20 token contract

    mapping(bytes32 => bytes32) public nullifiers; // store nullifiers of spent commitments
    mapping(bytes32 => bytes32) public roots; // holds each root we've calculated so that we can pull the one relevant to the prover
    bytes32 public latestRoot; // holds the index for the latest root so that the prover can provide it later and this contract can look up the relevant root


    function PrivateUSDT(address _USDToken) {
        _owner = msg.sender;
        usdtToken = USDTToken(_USDToken);
    }

    struct SpendDescription {
        bytes32[] value_commitment;
        bytes32 anchor;
        bytes32 nullifier;
        bytes[] rk;
        bytes32[] spend_auth_sig;
        bytes32[] proof;
    }

    struct OutputDescription {
        bytes32[] value_commitment;
        bytes32[] note_commitment;
        bytes32[] epk;
        bytes32 [] proof;
        bytes32[] c_enc;
        bytes32[] c_out;
    }

    address verifyProofContract = address(0x1000F);

    function computeMessageHash(uint256[] memory inputs) internal pure returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(inputs));
        return hash;
    }

    function mint(uint128 value, OutputDescription calldata outputDescription, bytes32[] calldata bindingSignature) external {
        require(value > 0, "Mint negative value.");
        bytes32 signHash = computeMessageHash(Concatenate(address(this), msg.sender, value, outputDescription));
        bool result = verifyProofContract.call(abi.encode(Mint, null, outputDescription, bindingSignature, value, signHash));
        require(result, "The proof and signature have not been verified by the contract");
        // Finally, transfer the fTokens from the sender to this contract
        usdtToken.transferFrom(msg.sender, address(this), value);
    }


    function transfer(SpendDescription calldata spendDescription, OutputDescription[] calldata outputDescription, byte32[] calldata bindingSignature) external {
        require(roots[spendDescription.anchor] == spendDescription.anchor, "The input root has never been the root of the Merkle Tree");
        require(nullifiers[spendDescription.nullifier] == 0, "The commitment being spent (commitmentF) has already been nullified!");
        require(outputDescription[0].note_commitment != outputDescription[1].note_commitment, "The new commitments (commitmentE and commitmentF) must be different!");

        bytes32 signHash = computeMessageHash(Concatenate(address(this), msg.sender, spendDescription, outputDescription));
        result = verifyProofContract.call(abi.encode(TRANSFER, spendDescription, outputDescription, bindingSignature, valueBalance, signHash));
        require(result, "The proof has not been verified by the contract");

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = _commitmentE;
        leaves[1] = _commitmentF;

        latestRoot = insertLeaves(leaves); // recalculate the root of the merkleTree as it's now different
        roots[latestRoot] = latestRoot; // and save the new root to the list of roots

        emit Transfer(_nullifierC, _nullifierD);
    }


    function burn(SpendDescription calldata spendDescription, uint256 payTo, uint128 value, bytes32[] calldata binding_signature) external {
        require(value > 0, "Mint negative value.");
        require(roots[spendDescription.anchor] == spendDescription.anchor, "The input root has never been the root of the Merkle Tree");
        require(nullifiers[spendDescription.nullifier] == 0, "The commitment being spent (commitmentF) has already been nullified!");

        bytes32 signHash = computeMessageHash(Concatenate(address(this), msg.sender, spendDescription, payTo, value));
        bool result = verifyProofContract.call(abi.encode(transferType, spendDescription, outputDescription, bindingSignature, valueBalance, signHash));
        require(result, "The proof and signature have not been verified by the contract");

        //Finally, transfer the fungible tokens from this contract to the nominated address
        address payToAddress = address(payTo);
        usdtToken.transfer(payToAddress, value);

        emit Burn(_nullifier);
    }

}
