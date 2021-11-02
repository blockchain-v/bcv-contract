// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


/// Remark: VNFD templates are not stored in the contract, as this would be very space inefficient.
/// VNFD templates should be created via frontend -> API -> tacker. In the frontend, the VNFD ID will
/// be available to call the deployVNF function on this contract. Also, the correlation IDs (contained
/// in the vnfs mapping) are to be stored by the API, and provided to the frontend. From there, the IDs
/// can be used to call the deleteVNF function on this contract.
contract VNFDeployment {

	/* --- MEMBERS --- */

	/// creator of the contract
	address public creator;

	/// VNF id counter
	uint private nextVnfId = 0;

	/// Contains the registered users
	mapping (address => bool) private users;

	/// Keeps track of a user's instantiated VNFs, such that only the creator of a VNF can delete it.
	/// The id used here must be stored by the event listening agent, such that it can correlate the
	/// ids with tacker's ids.
	mapping (address => mapping(uint => bool)) private vnfs;

	/* --- CONSTRUCTOR --- */
	constructor(){
		creator = msg.sender;
	}

	/* --- EVENTS --- */

	/// Event which signals to backend to register a user. The signed address enabled the backend to
	/// verify if the registering user is who he claims to be.
	/// @param user address of the user to be registered.
	/// @param signedAddress signature of the user's address, must be checked by the backend
	event Register(address user, string signedAddress);

	/// Event which signals to the backend to unregister a user
	/// @param user address of the registered user.
	event Unregister(address user);


	/// Event which signals to the backend to deploy a VNF according to the specified VNFD.
	/// @param creator address of the user triggering the VNF deployment
	/// @param vnfId // todo
	/// @param vnfdId identifier of the VNF descriptor (VNFD), which is
	/// the template to be used to create a VNF instance (obtained from tacker).
	/// @param parameters instantiation parameters according to the VNFD.
	event DeployVNF(address creator, uint vnfId, string vnfdId, string parameters);

	/// Event which signals the deletion of a VNF to the backend.
	/// @param creator address of the user triggering the VNF deletion.
	/// Must be the same user that triggered the VNF deployment.
	event DeleteVNF(address creator, uint vnfId);

  /// TODO
	event ModifyVNF(address creator, string vnfId, string parameters);

	/* --- FUNCTIONS --- */

	/// Registers the sender of a transaction as a user
	/// @param signedAddress signature of the user's address
	/// TODO: admin could register users
	function register(string memory signedAddress) public {
		address user = msg.sender;

		users[user] = true;

		emit Register(user, signedAddress);
	}

	/// Unregisters the sender of a transaction as a user
	function unregister() public {
		address user = msg.sender;

		users[user] = false; // soft delete (delete from map?), can be used to disable malicious users, maybe use separate delete function to ban users
		// delete users[user]; // TODO: discuss with Eder

		emit Unregister(user);
	}

	/// Deploys a VNF by emitting a deployment event.
	/// @param vnfdId identifier of the VNF descriptor (VNFD), which is
	/// the template to be used to create a VNF instance.
	/// @param parameters instantiation parameters according to the VNFD template.
	function deployVNF(string memory vnfdId, string memory parameters) public {
		address user = msg.sender;

		require(users[user], "User not registered.");

		uint vnfId = createVNFId();

		vnfs[user][vnfId] = true; // TODO: potentially store VNFs of a user as an array to make them visible

		emit DeployVNF(user, vnfId, vnfdId, parameters);
	}

	/// Deletes a VNF by emitting a deletion event.
	/// @param vnfId identifier of the VNF instance to be terminated.
	function deleteVNF(uint vnfId) public {
		address user = msg.sender;

		require(users[user], "User not registered.");

		require(vnfs[user][vnfId], "VNF must exist and can only be deleted by its creator");

		vnfs[user][vnfId] = false; // soft delete
		// delete vnfs[user][vnfId]; // TODO: discuss with Eder
		emit DeleteVNF(user, vnfId);
	}

	/// Creates a new VNF id for keeping track of VNF instantiations
	function createVNFId() private returns (uint) {
		return nextVnfId++; // TODO: may be better to use some sort of UUID or GUID
	}
}
