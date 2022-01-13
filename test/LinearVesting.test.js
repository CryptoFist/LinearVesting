const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("LinearVesting contract", function () {
  let linearVesting;
  let liteCoin;
  const time  = 10**3 * 60;  // 1 second

  before(async function () {
    linearVesting = await ethers.getContractFactory('LinearVesting');

    liteCoin = await ethers.getContractFactory('BEP20BitcoinCash');
    liteCoin = await liteCoin.deploy();
    await liteCoin.deployed();

    linearVesting = await linearVesting.deploy();
    await linearVesting.deployed();
  });

  beforeEach(async function () {});

  const setAllowance = async (owner) => {
    const ownerBalance = await liteCoin.balanceOf(owner.address);
    await liteCoin.increaseAllowance(linearVesting.address, ownerBalance);
  }

  // Test case
  it('Check mint function', async function () {
    const [owner, addr1] = await ethers.getSigners();
    await setAllowance(owner);
    await linearVesting.mint(liteCoin.address, addr1.address, time);
  });

  it('After mint, param checking', async function () {
    const [owner, addr1] = await ethers.getSigners();
    const scheduleID = await linearVesting.getLastScheduleID();

    assert.equal(scheduleID, 0);
    assert.equal(await linearVesting.duration(scheduleID), time);
    assert.equal(await linearVesting.beneficiary(scheduleID), addr1.address);
    assert.equal(await liteCoin.balanceOf(owner.address), 0);
    const toBalance = await liteCoin.balanceOf(addr1.address);
    const ownerBalance = await liteCoin.balanceOf(owner.address);
    assert.equal(toBalance.eq(ethers.BigNumber.from(ownerBalance)), true);
  });

  it('Check redeem', async function () {
    const [owner, addr1] = await ethers.getSigners();
    const scheduleID = await linearVesting.getLastScheduleID();
    await linearVesting.redeem(scheduleID);
    console.log(await liteCoin.balanceOf(addr1.address));
  });

});