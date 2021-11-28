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
		uint deploymentId;
		string vnfdId;
		string vnfId;
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
	uint private nextDeploymentId = 1;

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

	// Event which signals to the frontend that a user has been registered.
	/// @param user address of the user that has been registered.
	/// @param success Indicates whether the registration of the user was successful.
	event RegistrationStatus(address user, bool success);

	// Event which signals to the frontend that a user has been unregistered.
	/// @param user address of the user that has been unregistered.
	/// @param success Indicates whether the unregistration of the user was successful.
	event UnregistrationStatus(address user, bool success);

	// Event which signals to the backend to deploy a VNF according to the specified VNFD.
	/// @param creator address of the user triggering the VNF deployment
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param vnfdId identifier of the VNF descriptor (VNFD), which is
	/// the template to be used to create a VNF instance (obtained from tacker).
	/// @param parameters instantiation parameters according to the VNFD.
	event DeployVNF(address creator, uint deploymentId, string vnfdId, string parameters);

	// Event which signals the deletion of a VNF to the backend.
	// Must be called by the same user that triggered the VNF deployment.
	/// @param creator address of the user triggering the VNF deletion.
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param vnfId VNF identifier as specified by the backend.
	event DeleteVNF(address creator, uint deploymentId, string vnfId);

	// TODO
	event ModifyVNF(address creator, string vnfId, string parameters);

	// Event which signals the VNF's deployment status to the frontend.
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param user User owning the VNF
	/// @param success Indicates whether the creation of a VNF was successful.
	/// @param vnfId VNF identifier specified by the backend.
	event DeploymentStatus(uint deploymentId, address user, bool success, string vnfId);

	// Event which signals the status of a VNF deletion to the frontend.
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param user User owning the VNF
	/// @param success Indicates whether the deletion of the VNF was successful.
	event DeletionStatus(uint deploymentId, address user, bool success);

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

		emit Register(user, signedAddress);
	}

	// Enables the backend to signal the status of user registration.
	/// @param user User to be registered.
	/// @param success Indicates whether the user was registered correctly.
	function reportRegistration(address user, bool success) public {
		require(msg.sender == backend, "Only the backend is allowed to call this function.");

		if(success){
			users[user] = true;
		}

		emit RegistrationStatus(user, success);
	}

	// Unregisters the sender of a transaction as a user
	function unregisterUser() public {
		address user = msg.sender;

		emit Unregister(user);
	}

	// Enables the backend to signal the status of user unregistration.
	/// @param user User to be unregistered
	/// @param success Indicates whether the user was unregistered correctly.
	function reportUnregistration(address user, bool success) public {
		require(msg.sender == backend, "Only the backend is allowed to call this function.");

		if(success){
			users[user] = false; // soft delete can be used to disable malicious users, maybe use separate delete function to ban users
		}

		emit UnregistrationStatus(user, success);
	}

	// Deploys a VNF by emitting a deployment event.
	/// @param vnfdId identifier of the VNF descriptor (VNFD), which is
	/// the template to be used to create a VNF instance.
	/// @param parameters instantiation parameters according to the VNFD template.
	function deployVNF(string memory vnfdId, string memory parameters) public {
		address user = msg.sender;

		require(users[user], "User not registered.");

		uint deploymentId = createDeploymentId();

		VNF memory vnf = VNF(deploymentId, vnfdId, "", user, parameters, false, false);

		addVnf(vnf, user);

		emit DeployVNF(user, deploymentId, vnfdId, parameters);
	}

	// Deletes a VNF by emitting a deletion event.
	/// @param deploymentId identifier of the VNF instance to be terminated.
	function deleteVNF(uint deploymentId) public {
		address user = msg.sender;

		require(users[user], "User not registered.");

		uint index = findVnfIndex(deploymentId, user);

		require(vnfs[user][index].owner == user, "VNF must exist and can only be deleted by its owner");

		emit DeleteVNF(user, deploymentId, vnfs[user][index].vnfId);
	}


	// Enables the backend to signal the status of VNF deletion.
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param user User owning the VNF
	/// @param success Indicates whether the VNF was instantiated correctly.
	function reportDeletion(uint deploymentId, address user, bool success) public {
		require(msg.sender == backend, "Only the backend is allowed to call this function.");

		if(success){
			removeVnf(deploymentId, user);
		}

		emit DeletionStatus(deploymentId, user, success);
	}

	// Enables the backend to signal the status of VNF instantiation
	// by handing over the VNF resource identifier of the backend.
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param user User owning the VNF
	/// @param success Indicates whether the VNF was instantiated correctly.
	/// @param vnfId VNF identifier specified by the backend.
	function reportDeployment(uint deploymentId, address user, bool success, string calldata vnfId) external {
		require(msg.sender == backend, "Only the backend is allowed to call this function.");

		uint index = findVnfIndex(deploymentId, user);

		require(vnfs[user][index].deploymentId > 0, "VNF must exist in order to be activated.");

		if(success){
			// add vnfId to existing VNF record
			vnfs[user][index].vnfId = vnfId;
			vnfs[user][index].isDeployed = true;
		} else {
			// remove vnfId from registered VNF list
			removeVnf(deploymentId, user);
		}

		emit DeploymentStatus(deploymentId, user, success, vnfId);
	}

	/// Returns all the VNFs of the calling user
	function getVnfs(address user) public view returns (VNF[] memory) {
		require(msg.sender == backend, "Only the backend is allowed to call this function.");

		return vnfs[user];
	}

	/// Returns the details of one specific VNF
	/// @param deploymentId VNF identifier as specified in this contract.
	function getVnfDetails(uint deploymentId) public view returns (VNF memory){
		address user = msg.sender;

		require(users[user], "User not registered");

		uint index = findVnfIndex(deploymentId, user);

		VNF memory vnf = vnfs[user][index];

		require(vnf.owner == user, "User can only view own VNFs");

		return vnf;
	}

	/* --- PRIVATE FUNCTIONS --- */

	// Creates a new VNF id for keeping track of VNF instantiations
	function createDeploymentId() private returns (uint) {
		return nextDeploymentId++;
	}

	// Returns the VNF index from the vnf array using its ID
	// Reverts in case nothing is found
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param owner User owning the VNF.
	function findVnfIndex(uint deploymentId, address owner) private view returns (uint){
		uint length = vnfs[owner].length;

		for(uint i = 0; i < length; i++){
			if(vnfs[owner][i].deploymentId == deploymentId && !vnfs[owner][i].isDeleted){
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
	/// @param deploymentId VNF identifier as specified in this contract.
	/// @param owner User owning the VNF.
	function removeVnf(uint deploymentId, address owner) private {
		uint index = findVnfIndex(deploymentId, owner);

		vnfs[owner][index].isDeleted = true;
	}
}
