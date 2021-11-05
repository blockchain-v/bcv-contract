var VNFDeployment = artifacts.require("VNFDeployment");

module.exports = function(deployer) {
	deployer.deploy(VNFDeployment);
};