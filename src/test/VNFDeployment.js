const VNFDeployment = artifacts.require("VNFDeployment");
const truffleAssert = require("truffle-assertions");

contract("VNFDeployment", accounts => {

  let instance;

  beforeEach('set up of contract', async() => {
    instance = await VNFDeployment.new();
  });

  it("should set the creator of the contract", async() =>{
    // act, assert
    assert.notEqual(await instance.creator(), null);
  });

  it("should set the backend", async() =>{
    // arrange
    const user = accounts[1];

    // act
    await instance.registerBackend(user);

    // assert
    assert.equal(await instance.backend(), user);
  });

  it("should deny deployVNF for unregistered users", async() => {
    // act, assert
    await truffleAssert.reverts(instance.deployVNF("12", "asdf=test"), "User not registered.");
  });

  it("should deny deleteVNF for unregistered users", async() => {
    // act, assert
    await truffleAssert.reverts(instance.deleteVNF(1), "User not registered.");
  });

  it("should deny reportDeployment for unregistered backend", async() => {
    // arrange
    const user = accounts[1];

    // act, assert
    await truffleAssert.reverts(instance.reportDeployment(1, user, true, "someId"), "Only the backend is allowed to call this function.");
  });

  it("should deny reportDeletion for unregistered backend", async() => {
    // arrange
    const user = accounts[1];

    // act, assert
    await truffleAssert.reverts(instance.reportDeletion(1, user, true), "Only the backend is allowed to call this function.");
  });

  it("should deny reportRegistration for unregistered backend", async() => {
    // arrange
    const user = accounts[1];

    // act, assert
    await truffleAssert.reverts(instance.reportRegistration(user, true), "Only the backend is allowed to call this function.");
  });

  it("should emit a Register event", async() =>{
    // act
    const result = await instance.registerUser("xyz");

    // assert
    truffleAssert.eventEmitted(result, "Register", async(e) => {
      return e.user == await instance.creator() && e.signedAddress == "xyz";
    });
  });

  it("should emit a RegistrationStatus event", async() =>{
    // arrange
    await instance.registerBackend(await instance.creator());

    // act
    const result = await instance.reportRegistration(accounts[1], true);

    // assert
    truffleAssert.eventEmitted(result, "RegistrationStatus", e => {
      return e.user == accounts[1] && e.success == true;
    });
  });

  it("should emit a Unregister event", async() => {
    // act
    const result = await instance.unregisterUser();

    // assert
    truffleAssert.eventEmitted(result, "Unregister", async(e) => {
      return e.user == await instance.creator();
    });
  });

  it("should emit a UnegistrationStatus event", async() =>{
    // arrange
    await instance.registerBackend(await instance.creator());

    // act
    const result = await instance.reportUnregistration(accounts[1], true);

    // assert
    truffleAssert.eventEmitted(result, "UnregistrationStatus", e => {
      return e.user == accounts[1] && e.success == true;
    });
  });

  it("should emit a DeployVNF event", async() => {
    // arrange
    const user = await instance.creator();
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);

    const vnfdId = "XYZ";
    const params = "ram=1G,cpu=2,disk=500G";

    // act
    const result = await instance.deployVNF(vnfdId, params);

    // assert
    truffleAssert.eventEmitted(result, "DeployVNF", e => {
      return e.creator === user && e.correlationId == 1 && e.vnfdId == vnfdId && e.parameters == params;
    });
  });

  it("should emit a DeploymentStatus event", async() => {
    // arrange
    const user = await instance.creator();
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);
    const vnfdId = "XYZ";
    const params = "ram=1G,cpu=2,disk=500G";
    await instance.deployVNF(vnfdId, params);
    const correlationId = 1;
    const vnfId = "0xfabababababababab";

    // act
    const result = await instance.reportDeployment(correlationId, user, true, vnfId);

    // assert
    truffleAssert.eventEmitted(result, "DeploymentStatus", e => {
      return e.correlationId == correlationId && e.user == user && e.success == true && e.vnfId == vnfId;
    });
  });

  it("should emit a DeleteVNF event", async() => {
    // arrange
    // const instance = await sc.deployed();
    const user = await instance.creator();
    const vnfId = "ASDF-8291-DFEA";
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);

    const vnfdId = "XYZ";
    const params = "ram=1G,cpu=2,disk=500G";
    await instance.deployVNF(vnfdId, params);
    await instance.reportDeployment(1, user, true, vnfId);

    // act
    const result = await instance.deleteVNF(1);

    // assert
    truffleAssert.eventEmitted(result, "DeleteVNF", e => {
      return e.creator == user && e.correlationId == 1 && e.vnfId == vnfId;
    });
  });

  it("should emit a DeletionStatus event", async() => {
    // arrange
    // const instance = await sc.deployed();
    const user = await instance.creator();
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);
    const vnfdId = "XYZ";
    const params = "ram=1G,cpu=2,disk=500G";
    await instance.deployVNF(vnfdId, params);
    const correlationId = 1;
    const vnfIdEncrypted = "0xfabababababababab";

    // act
    const result = await instance.reportDeletion(correlationId, user, true);

    // assert
    truffleAssert.eventEmitted(result, "DeletionStatus", e => {
      return e.correlationId == correlationId && e.user == user && e.success == true;
    });
  });

})
