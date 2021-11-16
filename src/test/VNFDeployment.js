const VNFDeployment = artifacts.require("VNFDeployment");

contract("VNFDeployment", accounts => {
  it("should set the creator of the contract", async() =>{
    // arrange
    const instance = await VNFDeployment.deployed();

    // act, assert
    assert.notEqual(await instance.creator(), null);
  });

  it("should set the backend", async() =>{
    // arrange
    const user = accounts[1];
    const instance = await VNFDeployment.deployed();

    // act
    await instance.registerBackend(user);

    // assert
    assert.equal(await instance.backend(), user);
  });

  it("should emit a Register event", async() =>{
    // arrange
    const instance = await VNFDeployment.deployed()

    // act
    const result = (await instance.registerUser("xyz")).logs[0];

    // assert
    assert.equal(result.event, "Register");
    assert.equal(result.args["user"], await instance.creator());
    assert.equal(result.args["signedAddress"], "xyz");
  });

  it("should emit a RegistrationStatus event", async() =>{
    // arrange
    const instance = await VNFDeployment.deployed();
    await instance.registerBackend(await instance.creator());

    // act
    const result = (await instance.reportRegistration(accounts[1], true)).logs[0];

    // assert
    assert.equal(result.event, "RegistrationStatus");
    assert.equal(result.args["user"], accounts[1]);
    assert.equal(result.args["success"], true);
  });

  it("should emit a Unregister event", async() => {
    // arrange
    const instance = await VNFDeployment.deployed()

    // act
    const result = (await instance.unregisterUser()).logs[0];

    // assert
    assert.equal(result.event, "Unregister");
    assert.equal(result.args["user"], await instance.creator());
  });

  it("should emit a UnegistrationStatus event", async() =>{
    // arrange
    const instance = await VNFDeployment.deployed();
    await instance.registerBackend(await instance.creator());

    // act
    const result = (await instance.reportUnregistration(accounts[1], true)).logs[0];

    // assert
    assert.equal(result.event, "UnregistrationStatus");
    assert.equal(result.args["user"], accounts[1]);
    assert.equal(result.args["success"], true);
  });

  it("should emit a DeployVNF event", async() => {
    // arrange
    const instance = await VNFDeployment.deployed();
    const user = await instance.creator();
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);

    const vnfdId = "1";
    const params = "ram=1G,cpu=2,disk=500G";

    // act
    const result = (await instance.deployVNF(vnfdId, params)).logs[0];

    // assert
    assert.equal(result.event, "DeployVNF");
    assert.equal(result.args["creator"], user);
    assert.equal(result.args["vnfId"], 1);
    assert.equal(result.args["vnfdId"], vnfdId);
    assert.equal(result.args["parameters"], params);
  });

  it("should emit a DeploymentStatus event", async() => {
    // arrange
    const instance = await VNFDeployment.deployed();
    const user = await instance.creator();
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);
    const vnfdId = "1";
    const params = "ram=1G,cpu=2,disk=500G";
    await instance.deployVNF(vnfdId, params);
    const vnfId = 1;
    const vnfIdEncrypted = "0xfabababababababab";

    // act
    const result = (await instance.reportDeployment(vnfId, user, true, vnfIdEncrypted)).logs[0];

    // assert
    assert.equal(result.event, "DeploymentStatus");
    assert.equal(result.args["vnfId"], vnfId);
    assert.equal(result.args["user"], user);
    assert.equal(result.args["success"], true);
    assert.equal(result.args["vnfIdEncrypted"], vnfIdEncrypted);
  });

  it("should emit a DeleteVNF event", async() => {
    // arrange
    const instance = await VNFDeployment.deployed();
    const user = await instance.creator();
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);

    const vnfdId = "1";
    const params = "ram=1G,cpu=2,disk=500G";
    await instance.deployVNF(vnfdId, params)

    // act
    const result = (await instance.deleteVNF(1)).logs[0];

    // assert
    assert.equal(result.event, "DeleteVNF");
    assert.equal(result.args["creator"], user);
    assert.equal(result.args["vnfId"], 1);
  });

  it("should emit a DeletionStatus event", async() => {
    // arrange
    const instance = await VNFDeployment.deployed();
    const user = await instance.creator();
    await instance.registerBackend(user);
    await instance.reportRegistration(user, true);
    const vnfdId = "1";
    const params = "ram=1G,cpu=2,disk=500G";
    await instance.deployVNF(vnfdId, params);
    const vnfId = 1;
    const vnfIdEncrypted = "0xfabababababababab";

    // act
    const result = (await instance.reportDeletion(vnfId, user, true)).logs[0];

    // assert
    assert.equal(result.event, "DeletionStatus");
    assert.equal(result.args["vnfId"], vnfId);
    assert.equal(result.args["user"], user);
    assert.equal(result.args["success"], true);
  });

})
