const { Given, When, Then } = require('@cucumber/cucumber')
const ethers = require('hardhat').ethers
const { expect } = require("chai")
const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const crypto = require('crypto')

Given('contract is deployed', async () => {
    const [owner] = await ethers.getSigners()

    const l2LiskTokenContract = await ethers.getContractFactory("L2LiskToken")
    const l2LiskToken = await l2LiskTokenContract.deploy(ethers.Wallet.createRandom().address)
    await l2LiskToken.initialize(ethers.Wallet.createRandom().address)
    
    // const ProxyContract = await ethers.getContractFactory("Proxy")
    // const l2StakingImplementation = await l2StakingContract.deploy() 
    // const l2StakingProxy = await ProxyContract.deploy(l2StakingImplementation.getAddress())

    const l2VotingPowerContract = await ethers.getContractFactory("L2VotingPower")
    const l2VotingPower = await l2VotingPowerContract.deploy()

    const l2LockingPositionContract = await ethers.getContractFactory("L2LockingPosition")
    const l2LockingPosition = await l2LockingPositionContract.deploy()

    const l2StakingContract = await ethers.getContractFactory("L2Staking")
    const l2Staking = await l2StakingContract.deploy()

    await l2LockingPosition.initialize(l2Staking.getAddress())
    await l2LockingPosition.initializeVotingPower(l2VotingPower.getAddress())
    // await l2Staking.initializeLockingPosition(l2LockingPosition.getAddress())
    // await l2Reward.initializeLockingPosition(l2Staking.getAddress())

    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60
    const ONE_GWEI = 1_000_000_000
    const lockedAmount = ONE_GWEI

    await ethers.getContractFactory("Lock")
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS

    const Proxy = await ethers.getContractFactory("L1LiskToken")

    const signers = await ethers.getSigners()

    console.log(signers.length);
    // time.setNextBlockTimestamp(19740 * 86400)
    const Lock = await ethers.getContractFactory("Lock");
    const lock = await Lock.deploy(unlockTime, { value: lockedAmount });
    let deploymentDate = Number(await lock.todayDay())
    // this.state = { lock, unlockTime, lockedAmount, owner, otherAccount, Proxy };
    this.state = { deploymentDate, lock }
})

Then('owner is correct', async () => {
    let deploymentDate = Number(this.state.deploymentDate)

    deploymentDate = await this.state.lock.todayDay()

    console.log(deploymentDate)

    expect(true).to.be.true
})


Then('on day {int}', async (numberOfDays) => {
    let today = this.state.deploymentDate + numberOfDays

    await time.increaseTo(today * 86400)

    expect(today).to.eq(Number(await this.state.lock.todayDay()))
})

Given('{int} stakers', async (numberOfStakers) => {
    const stakers = Array(numberOfStakers)

    for (let i = 0; i < stakers.length; i++) {
        stakers[i] = ethers.Wallet.createRandom() 
    }

    this.state.stakers = stakers

    // console.log(ethers.Wallet.fromPhrase("bridge"))
})

When('when 1', async () => {
    console.log('when 1')
})

Given('given 1', async () => {
    console.log('given 1')
})

Then('then 1', async () => {
    console.log('then 1')
})