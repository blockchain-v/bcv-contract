// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2; // needed if we set solc version to ^0.6.0 in truffle-config, included in higher versions by default

// Remark: VNFD templates are not stored in the contract, as this would be very space inefficient.
// VNFD templates should be created via frontend -> API -> tacker. In the frontend, the VNFD ID will
// be available to call the deployVNF function on this contract. Also, the correlation IDs (contained
// in the vnfs mapping) are to be stored by the API, and provided to the frontend. From there, the IDs
// can be used to call the deleteVNF function on this contract.
contract VNFDeployment {

	/* --- STRUCTS --- */
	struct VNF {
		uint id;
		string vnfdId;
		string encryptedId;
		address owner;
		string parameters;
		bool isDeployed;
		bool isDeleted;
	}

	/* --- MEMBERS --- */

	// creator of the contract
	address public creator;

	// account of the backend
	address public backend;

	// VNF id counter
	uint private nextVnfId = 1;

	// Contains the registered users
	mapping (address => bool) private users;

	// Keeps track of a registered VNFs, such that only the owner of a VNF can delete it.
	// The id used here must be stored by the event listening agent, such that it can correlate the
	// ids with tacker's ids.
	mapping (address => VNF[]) private vnfs;

	/* --- CONSTRUCTOR --- */
	constructor() public {
		creator = msg.sender;
	}

	/* --- EVENTS --- */

	// Event which signals to backend to register a user. The signed address enabled the backend to
	// verify if the registering user is who he claims to be.
	/// @param user address of the user to be registered.
	/// @param signedAddress signature of the user's address, must be checked by the backend
	event Register(address user, string signedAddress);

	// Event which signals to the backend to unregister a user
	/// @param user address of the registered user.
	event Unregister(address user);


	// Event which signals to the backend to deploy a VNF according to the specified VNFD.
	/// @param creator address of the user triggering the VNF deployment
	/// @param vnfId VNF identifier as specified in this contract.
	/// @param vnfdId identifier of the VNF descriptor (VNFD), which is
	/// the template to be used to create a VNF instance (obtained from tacker).
	/// @param parameters instantiation parameters according to the VNFD.
	event DeployVNF(address creator, uint vnfId, string vnfdId, string parameters);

	// Event which signals the deletion of a VNF to the backend.
	// Must be called by the same user that triggered the VNF deployment.
	/// @param creator address of the user triggering the VNF deletion.
	event DeleteVNF(address creator, uint vnfId);

	// TODO
	event ModifyVNF(address creator, string vnfId, string parameters);

	// Event which signals the VNF's deployment status to the frontend.
	/// @param vnfId VNF identifier as specified in this contract.
	/// @param user User owning the VNF
	/// @param success Indicates whether the creation of a VNF was successful.
	/// @param vnfIdEncrypted Encrypted VNF identifier (can only be decrypted by the user).
	event DeploymentStatus(uint vnfId, address user, bool success, string vnfIdEncrypted);

	/* --- PUBLIC FUNCTIONS --- */

	/// Allows the creator of this contract to register the backend account, which is needed for confirming VNF
	/// instantiation.
	/// @param backendAddress Account address of the backend
	function registerBackend(address backendAddress) public {
		address user = msg.sender;

		require(user == creator, "Only the creator of this contract is allowed to register the backend account.");

		backend = backendAddress;
	}

	// Registers the sender of a transaction as a user
	/// @param signedAddress signature of the user's address
	// TODO: admin could register users
	function registerUser(string memory signedAddress) public {
		address user = msg.sender;

		users[user] = true;

		emit Register(user, signedAddress);
	}

	// Unregisters the sender of a transaction as a user
	function unregisterUser() public {
		address user = msg.sender;

		users[user] = false; // soft delete can be used to disable malicious users, maybe use separate delete function to ban users

		emit Unregister(user);
	}

	// Deploys a VNF by emitting a deployment event.
	/// @param vnfdId identifier of the VNF descriptor (VNFD), which is
	/// the template to be used to create a VNF instance.
	/// @param parameters instantiation parameters according to the VNFD template.
	function deployVNF(string memory vnfdId, string memory parameters) public {
		address user = msg.sender;

		require(users[user], "User not registered.");

		uint vnfId = createVNFId();

		VNF memory vnf = VNF(vnfId, vnfdId, "", user, parameters, false, false);

		//vnfs[vnfId] = vnf;
		addVnf(vnf, user);

		emit DeployVNF(user, vnfId, vnfdId, parameters);
	}

	// Deletes a VNF by emitting a deletion event.
	/// @param vnfId identifier of the VNF instance to be terminated.
	function deleteVNF(uint vnfId) public {
		address user = msg.sender;

		require(users[user], "User not registered.");

		uint index = findVnfIndex(vnfId, user);

		require(vnfs[user][index].owner == user, "VNF must exist and can only be deleted by its owner");

		removeVnf(vnfId, user);

		emit DeleteVNF(user, vnfId);
	}

	// Enables the backend to signal the status of VNF instantiation
	// by handing over the VNF resource identifier in an encrypted form.
	/// @param vnfId VNF identifier as specified in this contract.
	/// @param user User owning the VNF
	/// @param success Indicates whether the VNF was instantiated correctly.
	/// @param vnfIdEncrypted Encrypted VNF identifier (can only be decrypted by the user).
	function reportDeployment(uint vnfId, address user, bool success, string calldata vnfIdEncrypted) external {
		require(msg.sender == backend, "Only the backend is allowed to call this function.");

		uint index = findVnfIndex(vnfId, user);

		require(vnfs[user][index].id > 0, "VNF must exist in order to be activated.");

		if(success){
			// add vnfIdEncrypted to existing VNF record
			vnfs[user][index].encryptedId = vnfIdEncrypted;
			vnfs[user][index].isDeployed = true;
		} else {
			// remove vnfId from registered VNF list
			removeVnf(vnfId, user);
		}

		emit DeploymentStatus(vnfId, user, success, vnfIdEncrypted);
	}

	// DEV
	/// Returns all the VNFs of the calling user
	function getVnfs() public view returns (VNF[] memory) {
		address user = msg.sender;

		require(users[user], "User not registered.");

		return vnfs[user];
	}

	// DEV
	/// Returns the details of one specific VNF
	/// @param vnfId VNF identifier as specified in this contract.
	function getVnfDetails(uint vnfId) public view returns (VNF memory){
		address user = msg.sender;

		require(users[user], "User not registered");

		uint index = findVnfIndex(vnfId, user);

		VNF memory vnf = vnfs[user][index];

		require(vnf.owner == user, "User can only view own VNFs");

		return vnf;
	}

	/* --- PRIVATE FUNCTIONS --- */

	// Creates a new VNF id for keeping track of VNF instantiations
	function createVNFId() private returns (uint) {
		return nextVnfId++;
	}

	// Returns the VNF index from the vnf array using its ID
	// Reverts in case nothing is found
	/// @param vnfId VNF identifier as specified in this contract.
	/// @param owner User owning the VNF.
	function findVnfIndex(uint vnfId, address owner) private view returns (uint){
		uint length = vnfs[owner].length;

		for(uint i = 0; i < length; i++){
			if(vnfs[owner][i].id == vnfId && !vnfs[owner][i].isDeleted){
				return i;
			}
		}

		revert("No VNF found for the specified address");
	}

	// Helper function to manage the vnfs array (add)
	/// @param vnf VNF to be added.
	/// @param owner User owning the VNF.
	function addVnf(VNF memory vnf, address owner) private {
		vnfs[owner].push(vnf);
	}

	// Helper function to manage the vnfs array (delete)
	/// @param vnfId VNF identifier as specified in this contract.
	/// @param owner User owning the VNF.
	function removeVnf(uint vnfId, address owner) private {
		uint index = findVnfIndex(vnfId, owner);

		vnfs[owner][index].isDeleted = true;
	}
}
