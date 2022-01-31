# @version 0.2.12
"""
@title Broxus Token Vault
@license GNU AGPLv3
@author https://tonbridge.io
@notice
    Broxus Token Vault is a fork of Yearn Token Vault v2.
    The Vault is used as an entry point for token transfers
    between EVM-compatible networks and Everscale, by using Broxus bridge.

    Fork commit: https://github.com/yearn/yearn-vaults/tree/e20d7e61692e61b1583628f8f3f96b27f824fbb4

    The key differences are:

    - The Vault is no longer a share token. The ERC20 interface is not supported.
    No tokens are minted / burned on deposit / withdraw.
    - The share token equivalent is corresponding token in Everscale network. So if you're
    depositing Dai in this Vault, you receives Dai in Everscale.
    - When user deposits into Vault, he specifies his Everscale address.
    In the end, the deposited amount of corresponding token will be transferred to this address.
    - To withdraw tokens from the Vault, user needs to provide "withdraw receipt"
    and corresponding set of relay's signatures.
    - If there're enough tokens on the Vault balance, the withdraw will be filled instantly
    - If not - the withdraw will be saved as a "pending withdraw". There're multiple ways to finalize
    pending withdrawal:
      1. User can specify so called `bounty` - how much tokens he wills to pay as a reward
      to anyone, who fills his pending withdrawal. Pending withdrawal can only be filled completely.
      2. User can use `withdraw` function, which works the same as original Yearn's withdraw.
      3. User can cancel his pending withdraw partially or entirely.
    - Since Vyper does not support dynamic size arrays and bytes-decoding, special contract `wrapper` is used
    for uploading withdraw receipts (`VaultWrapper.sol`).
    - Vault has emergency strategy withdraw
    - If total amount of pending withdrawals is more than `totalAssets()`, than strategies dont receive new
    debt
    - Vault may have deposit / withdraw fee

    ORIGINAL NOTE:

    Yearn Token Vault. Holds an underlying token, and allows users to interact
    with the Yearn ecosystem through Strategies connected to the Vault.
    Vaults are not limited to a single Strategy, they can have as many Strategies
    as can be designed (however the withdrawal queue is capped at 20.)

    Deposited funds are moved into the most impactful strategy that has not
    already reached its limit for assets under management, regardless of which
    Strategy a user's funds end up in, they receive their portion of yields
    generated across all Strategies.

    When a user withdraws, if there are no funds sitting undeployed in the
    Vault, the Vault withdraws funds from Strategies in the order of least
    impact. (Funds are taken from the Strategy that will disturb everyone's
    gains the least, then the next least, etc.) In order to achieve this, the
    withdrawal queue's order must be properly set and managed by the community
    (through governance).

    Vault Strategies are parameterized to pursue the highest risk-adjusted yield.

    There is an "Emergency Shutdown" mode. When the Vault is put into emergency
    shutdown, assets will be recalled from the Strategies as quickly as is
    practical (given on-chain conditions), minimizing loss. Deposits are
    halted, new Strategies may not be added, and each Strategy exits with the
    minimum possible damage to position, while opening up deposits to be
    withdrawn by users. There are no restrictions on withdrawals above what is
    expected under Normal Operation.

    For further details, please refer to the specification:
    https://github.com/iearn-finance/yearn-vaults/blob/main/SPECIFICATION.md
"""

API_VERSION: constant(String[28]) = "0.1.4"

from vyper.interfaces import ERC20


interface Strategy:
    def want() -> address: view
    def vault() -> address: view
    def isActive() -> bool: view
    def delegatedAssets() -> uint256: view
    def estimatedTotalAssets() -> uint256: view
    def withdraw(_amount: uint256) -> uint256: nonpayable
    def migrate(_newStrategy: address): nonpayable


interface ExtendedERC20:
    def decimals() -> uint256: view

token: public(ERC20)
governance: public(address)
management: public(address)
guardian: public(address)
pendingGovernance: address


# ================= Broxus bridge structures =================

struct TONEvent:
    eventTransactionLt: uint256
    eventTimestamp: uint256
    eventData: Bytes[10000]
    configurationWid: int128
    configurationAddress: uint256
    proxy: address
    round: uint256

struct TONAddress:
    wid: int128
    addr: uint256

struct PendingWithdrawal:
    amount: uint256 # Amount of user's tokens in withdrawal status
    bounty: uint256 # How much tokens user wills to pay as bounty
    open: bool
    approveStatus: uint256 # Approve status, see note bellow
    _timestamp: uint256 # Event withdrawal timestamp

# NOTE: on `approveStatus`
# 0 - approve not required
# 1 - approve required
# 2 - approved
# 3 - rejected

struct PendingWithdrawalId:
    recipient: address
    id: uint256

struct WithdrawalPeriod:
    total: uint256 # How many tokens withdrawn in this period (includes pending)
    considered: uint256 # How many tokens have been approved / rejected in this period

# NOTE: Vault may have non-zero deposit / withdraw fee.
struct Fee:
    step: uint256 # The fee is charged only on amounts exceeding this value
    size: uint256 # Size in BPS

# ================= Broxus bridge structures =================


# ================= Broxus bridge events =================

# NOTE: this relay is monitored by the Broxus bridge relays.
# Allows to mint corresponding tokens in the Everscale network
event Deposit:
    amount: uint256 # Amount of tokens to be minted
    wid: int128 # Recipient in TON, see note on `TONAddress`
    addr: uint256

event NewDeposit:
    sender: address
    recipientWid: int128
    recipientAddr: uint256
    amount: uint256
    pendingWithdrawalRecipient: address
    pendingWithdrawalId: uint256
    sendTransferToTon: bool

event InstantWithdrawal:
    recipient: address
    payloadId: bytes32
    amount: uint256

event CreatePendingWithdrawal:
    recipient: address
    id: uint256
    payloadId: bytes32
    amount: uint256
    bounty: uint256

event UpdatePendingWithdrawalBounty:
    recipient: address
    id: uint256
    bounty: uint256

event CancelPendingWithdrawal:
    recipient: address
    id: uint256
    amount: uint256

event WithdrawPendingWithdrawal:
    recipient: address
    id: uint256
    requestedAmount: uint256
    redeemedAmount: uint256

event FillPendingWithdrawal:
    recipient: address
    id: uint256

event UpdateBridge:
    bridge: address

event UpdateWrapper:
    wrapper: address

event UpdateConfiguration:
    wid: int128
    addr: uint256

event UpdateTargetDecimals:
    targetDecimals: uint256

event ForceWithdraw:
    recipient: address
    id: uint256

event UpdateWithdrawGuardian:
    withdrawGuardian: address

event UpdatePendingWithdrawApprove:
    recipient: address
    id: uint256
    approveStatus: uint256

event WithdrawApprovedWithdrawal:
    recipient: address
    id: uint256

event UpdateWithdrawLimitPerPeriod:
    withdrawLimitPerPeriod: uint256

event UpdateUndeclaredWithdrawLimit:
    undeclaredWithdrawLimit: uint256

# NOTE: unlike the original Yearn Vault,
# fees are paid in corresponding token on the Everscale side
# See note on `_assessFees`
event UpdateRewards:
    wid: int128
    addr: uint256

event UpdateStrategyRewards:
    strategy: address
    wid: int128
    addr: uint256

event UpdateDepositFee:
    step: uint256
    size: uint256

event UpdateWithdrawFee:
    step: uint256
    size: uint256

# ================= Broxus bridge events =================

struct StrategyParams:
    performanceFee: uint256  # Strategist's fee (basis points)
    activation: uint256  # Activation block.timestamp
    debtRatio: uint256  # Maximum borrow amount (in BPS of total assets)
    minDebtPerHarvest: uint256  # Lower limit on the increase of debt since last harvest
    maxDebtPerHarvest: uint256  # Upper limit on the increase of debt since last harvest
    lastReport: uint256  # block.timestamp of the last time a report occured
    totalDebt: uint256  # Total outstanding debt that Strategy has
    totalGain: uint256  # Total returns that Strategy has realized for Vault
    totalSkim: uint256 # Total amount of skimmed tokens (see note on `skim`)
    totalLoss: uint256  # Total losses that Strategy has realized for Vault
    rewardsManager: address # Address allowed to update strategy rewards receiver
    rewards: TONAddress # Strategist rewards address (see note on `_assessFees`)

event StrategyAdded:
    strategy: indexed(address)
    debtRatio: uint256  # Maximum borrow amount (in BPS of total assets)
    minDebtPerHarvest: uint256  # Lower limit on the increase of debt since last harvest
    maxDebtPerHarvest: uint256  # Upper limit on the increase of debt since last harvest
    performanceFee: uint256  # Strategist's fee (basis points)


event StrategyReported:
    strategy: indexed(address)
    gain: uint256
    loss: uint256
    debtPaid: uint256
    totalGain: uint256
    totalSkim: uint256
    totalLoss: uint256
    totalDebt: uint256
    debtAdded: uint256
    debtRatio: uint256


event UpdateGovernance:
    governance: address # New active governance

event NewPendingGovernance:
    governance: address # New pending governance


event UpdateManagement:
    management: address # New active manager


event UpdateDepositLimit:
    depositLimit: uint256 # New active deposit limit


event UpdatePerformanceFee:
    performanceFee: uint256 # New active performance fee


event UpdateManagementFee:
    managementFee: uint256 # New active management fee


event UpdateGuardian:
    guardian: address # Address of the active guardian


event EmergencyShutdown:
    active: bool # New emergency shutdown state (if false, normal operation enabled)


event UpdateWithdrawalQueue:
    queue: address[MAXIMUM_STRATEGIES] # New active withdrawal queue

event StrategyUpdateDebtRatio:
    strategy: indexed(address) # Address of the strategy for the debt ratio adjustment
    debtRatio: uint256 # The new debt limit for the strategy (in BPS of total assets)


event StrategyUpdateMinDebtPerHarvest:
    strategy: indexed(address) # Address of the strategy for the rate limit adjustment
    minDebtPerHarvest: uint256  # Lower limit on the increase of debt since last harvest


event StrategyUpdateMaxDebtPerHarvest:
    strategy: indexed(address) # Address of the strategy for the rate limit adjustment
    maxDebtPerHarvest: uint256  # Upper limit on the increase of debt since last harvest


event StrategyUpdatePerformanceFee:
    strategy: indexed(address) # Address of the strategy for the performance fee adjustment
    performanceFee: uint256 # The new performance fee for the strategy


event StrategyMigrated:
    oldVersion: indexed(address) # Old version of the strategy to be migrated
    newVersion: indexed(address) # New version of the strategy

event StrategyRevoked:
    strategy: indexed(address) # Address of the strategy that is revoked


event StrategyRemovedFromQueue:
    strategy: indexed(address) # Address of the strategy that is removed from the withdrawal queue


event StrategyAddedToQueue:
    strategy: indexed(address) # Address of the strategy that is added to the withdrawal queue


# ================= Broxus bridge variables =================

# NOTE: Track pending withdrawals
pendingWithdrawalsPerUser: public(HashMap[address, uint256])
pendingWithdrawals: public(HashMap[address, HashMap[uint256, PendingWithdrawal]])

# NOTE: Track total amount of tokens to be withdrawn
pendingWithdrawalsTotal: public(uint256)

# NOTE: Track already seen withdrawal receipts to prevent double-spending
withdrawIds: public(HashMap[bytes32, bool])

# NOTE: Wrapper contract, see VaultWrapper.sol
wrapper: public(address)

# NOTE: Broxus bridge contract address. Used for validating withdrawal signatures.
# See note on `saveWithdraw`
bridge: public(address)

# NOTE: withdraw receipts
configuration: public(TONAddress)

# NOTE: Gov rewards are sent on the Everscale side
rewards: public(TONAddress)

# NOTE: Vault may have non-zero fee for deposit / withdraw
depositFee: public(Fee)
withdrawFee: public(Fee)

MAXIMUM_SIGNATURES_FOR_WITHDRAW_RECEIPT: constant(uint256) = 100
MAXIMUM_WITHDRAW_RECEIPT_SIZE: constant(uint256) = 10000

# ================= Broxus bridge variables =================

# NOTE: Track the total for overhead targeting purposes
strategies: public(HashMap[address, StrategyParams])
MAXIMUM_STRATEGIES: constant(uint256) = 20
DEGRADATION_COEFFICIENT: constant(uint256) = 10 ** 18
# SET_SIZE can be any number but having it in power of 2 will be more gas friendly and collision free.
# Note: Make sure SET_SIZE is greater than MAXIMUM_STRATEGIES
SET_SIZE: constant(uint256) = 32

# Ordering that `withdraw` uses to determine which strategies to pull funds from
# NOTE: Does *NOT* have to match the ordering of all the current strategies that
#       exist, but it is recommended that it does or else withdrawal depth is
#       limited to only those inside the queue.
# NOTE: Ordering is determined by governance, and should be balanced according
#       to risk, slippage, and/or volatility. Can also be ordered to increase the
#       withdrawal speed of a particular Strategy.
# NOTE: The first time a ZERO_ADDRESS is encountered, it stops withdrawing
withdrawalQueue: public(address[MAXIMUM_STRATEGIES])

emergencyShutdown: public(bool)

depositLimit: public(uint256)  # Limit for totalAssets the Vault can hold
debtRatio: public(uint256)  # Debt ratio for the Vault across all strategies (in BPS, <= 10k)
totalDebt: public(uint256)  # Amount of tokens that all strategies have borrowed
lastReport: public(uint256)  # block.timestamp of last report
activation: public(uint256)  # block.timestamp of contract deployment
lockedProfit: public(uint256) # how much profit is locked and cant be withdrawn
lockedProfitDegradation: public(uint256) # rate per block of degradation. DEGRADATION_COEFFICIENT is 100% per block
# Governance Fee for management of Vault (given to `rewards`)
managementFee: public(uint256)
# Governance Fee for performance of Vault (given to `rewards`)
performanceFee: public(uint256)
MAX_BPS: constant(uint256) = 10_000  # 100%, or 10k basis points
# NOTE: A four-century period will be missing 3 of its 100 Julian leap years, leaving 97.
#       So the average year has 365 + 97/400 = 365.2425 days
#       ERROR(Julian): -0.0078
#       ERROR(Gregorian): -0.0003
#       A day = 24 * 60 * 60 sec = 86400 sec
#       365.2425 * 86400 = 31556952.0
SECS_PER_YEAR: constant(uint256) = 31_556_952  # 365.2425 days


tokenDecimals: public(uint256)
targetDecimals: public(uint256)

# ================= Storage update 1 =================

withdrawalPeriods: public(HashMap[uint256, WithdrawalPeriod])
# NOTE: Each period is 24 hours long.
# In case the `withdrawLimitPerPeriod` is reached for specific period,
# every withdraw in this period requires additional approve.
# Each withdraw can be approved / rejected, see note on `setPendingWithdrawApprove`
# Or bunch of withdrawals can be approved simultaneously, see note on `setWithdrawPeriodApprovedUntil`

withdrawLimitPerPeriod: public(uint256) # Period withdraw limit
undeclaredWithdrawLimit: public(uint256) # How many tokens users can withdraw without an approve at once
withdrawGuardian: public(address) # Can approve / reject withdrawals

WITHDRAW_PERIOD_DURATION_IN_SECONDS: constant(uint256) = 60 * 60 * 24 # 24 hours

@external
def initialize(
    token: address,
    governance: address,
    bridge: address,
    targetDecimals: uint256,
):
    """
    @notice
        Initializes the Vault, this is called only once, when the contract is
        deployed.
        The performance fee is set to 10% of yield, per Strategy.
        The management fee is set to 2%, per year.
        The initial deposit limit is set to 0 (deposits disabled); it must be
        updated after initialization.
        The rewards TON address and corresponding Bridge Configuration also should be set after initialization.
    @dev
        The token used by the vault should not change balances outside transfers and
        it must transfer the exact amount requested. Fee on transfer and rebasing are not supported.
    @param token The token that may be deposited into this Vault.
    @param governance The address authorized for governance interactions.
    @param bridge The address of the Bridge contract
    @param targetDecimals Amount of decimals in the corresponding Everscale token
    """
    assert self.activation == 0  # dev: no devops199

    self.token = ERC20(token)
    self.tokenDecimals = ExtendedERC20(token).decimals()
    self.targetDecimals = targetDecimals

    self.governance = governance
    log UpdateGovernance(governance)

    self.bridge = bridge
    log UpdateBridge(bridge)

    self.performanceFee = 0  # 0% of yield (per Strategy)
    log UpdatePerformanceFee(convert(0, uint256))

    self.managementFee = 0  # 0% per year
    log UpdateManagementFee(convert(0, uint256))

    self.lastReport = block.timestamp
    self.activation = block.timestamp
    self.lockedProfitDegradation = convert(DEGRADATION_COEFFICIENT * 46 / 10 ** 6 , uint256) # 6 hours in blocks


@pure
@external
def apiVersion() -> String[28]:
    """
    @notice
        Used to track the deployed version of this contract. In practice you
        can use this version number to compare with Broxus's GitHub and
        determine which version of the source matches this deployed contract.
    @dev
        All strategies must have an `apiVersion()` that matches the Vault's
        `API_VERSION`.
    @return API_VERSION which holds the current version of this contract.
    """
    return API_VERSION


@external
def setDepositFee(fee: Fee):
    """
    @notice
        Set new value. Deposit fee is charged on `deposit`,
        fee is charged on the Ethereum side.
    @dev Use (0,0) to set zero fee.
    @param fee New deposit fee value
    """
    assert msg.sender in [self.management, self.governance]

    self.depositFee = fee

    log UpdateDepositFee(fee.step, fee.size)

@external
def setWithdrawFee(fee: Fee):
    """
    @notice
        Set new value. Withdrawal fee is charged on `saveWithdraw`.
    @dev Use (0,0) to set zero fee.
    @param fee New withdraw fee value
    """
    assert msg.sender in [self.management, self.governance]

    self.withdrawFee = fee

    log UpdateWithdrawFee(fee.step, fee.size)

@external
def setWrapper(wrapper: address):
    """
    @notice
        Used to decode raw bytes with withdrawal TONEvent and withdrawal event data.
        See note on `saveWithdraw`.
    @param wrapper New wrapper contract
    """

    assert msg.sender == self.governance
    log UpdateWrapper(wrapper)
    self.wrapper = wrapper

@external
def setConfiguration(configuration: TONAddress):
    assert msg.sender == self.governance

    log UpdateConfiguration(configuration.wid, configuration.addr)

    self.configuration = configuration

@external
def setGovernance(governance: address):
    """
    @notice
        Nominate a new address to use as governance.

        This may only be called by the current governance address.
    @param governance The to use as new governance.
    """
    assert msg.sender == self.governance

    log UpdateGovernance(governance)
    self.governance = governance

@external
def setManagement(management: address):
    """
    @notice
        Changes the management address.
        Management is able to make some investment decisions adjusting parameters.

        This may only be called by governance.
    @param management The address to use for managing.
    """
    assert msg.sender == self.governance
    self.management = management
    log UpdateManagement(management)


@external
def setStrategyRewards(strategy: address, rewards: TONAddress):
    assert self.strategies[strategy].activation > 0
    assert msg.sender in [self.governance, self.strategies[strategy].rewardsManager]

    self.strategies[strategy].rewards = rewards

    log UpdateStrategyRewards(strategy, rewards.wid, rewards.addr)


@external
def setRewards(rewards: TONAddress):
    """
    @notice
        Rewards are distributed on the Everscale side in corresponding token.

        This may only be called by governance.
    @param rewards The address to use for collecting rewards.
    """
    assert msg.sender == self.governance

    self.rewards = rewards

    log UpdateRewards(rewards.wid, rewards.addr)


@external
def setLockedProfitDegradation(degradation: uint256):
    """
    @notice
        Changes the locked profit degradation.
    @param degradation The rate of degradation in percent per second scaled to 1e18.
    """
    assert msg.sender == self.governance
    # Since "degradation" is of type uint256 it can never be less than zero
    assert degradation <= DEGRADATION_COEFFICIENT
    self.lockedProfitDegradation = degradation


@external
def setDepositLimit(limit: uint256):
    """
    @notice
        Changes the maximum amount of tokens that can be deposited in this Vault.

        Note, this is not how much may be deposited by a single depositor,
        but the maximum amount that may be deposited across all depositors.

        This may only be called by governance.
    @param limit The new deposit limit to use.
    """
    assert msg.sender == self.governance
    self.depositLimit = limit
    log UpdateDepositLimit(limit)


@external
def setPerformanceFee(fee: uint256):
    """
    @notice
        Used to change the value of `performanceFee`.

        Should set this value below the maximum strategist performance fee.

        This may only be called by governance.
    @param fee The new performance fee to use.
    """
    assert msg.sender == self.governance
    assert fee <= MAX_BPS / 2
    self.performanceFee = fee
    log UpdatePerformanceFee(fee)


@external
def setManagementFee(fee: uint256):
    """
    @notice
        Used to change the value of `managementFee`.

        This may only be called by governance.
    @param fee The new management fee to use.
    """
    assert msg.sender == self.governance
    assert fee <= MAX_BPS
    self.managementFee = fee
    log UpdateManagementFee(fee)


@external
def setGuardian(guardian: address):
    """
    @notice
        Used to change the address of `guardian`.

        This may only be called by governance or the existing guardian.
    @param guardian The new guardian address to use.
    """
    assert msg.sender in [self.guardian, self.governance]
    self.guardian = guardian
    log UpdateGuardian(guardian)


@external
def setWithdrawGuardian(withdrawGuardian: address):
    """
    @notice
        Used to change the address of `withdrawGuardian`.

        This may only be called by governance or the existing withdraw guardian.
    @param withdrawGuardian The new withdraw guardian address to use.
    """

    assert msg.sender in [self.withdrawGuardian, self.governance]

    self.withdrawGuardian = withdrawGuardian

    log UpdateWithdrawGuardian(withdrawGuardian)

@external
def setWithdrawLimitPerPeriod(withdrawLimitPerPeriod: uint256):
    """
    @notice
        Used to change the value of `withdrawLimitPerPeriod`.
        Affects all periods, including the past.

        This may only be called by governance.
    @param withdrawLimitPerPeriod The new withdraw limit per period to use.
    """

    assert msg.sender == self.governance

    self.withdrawLimitPerPeriod = withdrawLimitPerPeriod

    log UpdateWithdrawLimitPerPeriod(withdrawLimitPerPeriod)

@external
def setUndeclaredWithdrawLimit(undeclaredWithdrawLimit: uint256):
    """
    @notice
        Used to change the value of `undeclaredWithdrawLimit`.
        Affects all periods, including the past.

        This may only be called by governance.
    @param undeclaredWithdrawLimit The new undeclared withdraw limit.
    """

    assert msg.sender == self.governance

    self.undeclaredWithdrawLimit = undeclaredWithdrawLimit

    log UpdateUndeclaredWithdrawLimit(undeclaredWithdrawLimit)


@external
def setEmergencyShutdown(active: bool):
    """
    @notice
        Activates or deactivates Vault mode where all Strategies go into full
        withdrawal.

        During Emergency Shutdown:
        1. No Users may deposit into the Vault (but may withdraw as usual.)
        2. Governance may not add new Strategies.
        3. Each Strategy must pay back their debt as quickly as reasonable to
            minimally affect their position.
        4. Only Governance may undo Emergency Shutdown.

        See contract level note for further details.

        This may only be called by governance or the guardian.
    @param active
        If true, the Vault goes into Emergency Shutdown. If false, the Vault
        goes back into Normal Operation.
    """
    if active:
        assert msg.sender in [self.guardian, self.governance]
    else:
        assert msg.sender == self.governance
    self.emergencyShutdown = active
    log EmergencyShutdown(active)


@external
def setWithdrawalQueue(queue: address[MAXIMUM_STRATEGIES]):
    """
    @notice
        Updates the withdrawalQueue to match the addresses and order specified
        by `queue`.

        There can be fewer strategies than the maximum, as well as fewer than
        the total number of strategies active in the vault. Assumes the input is well-
        ordered with 0x0 only at the end.

        This may only be called by governance or management.
    @dev
        This is order sensitive, specify the addresses in the order in which
        funds should be withdrawn (so `queue`[0] is the first Strategy withdrawn
        from, `queue`[1] is the second, etc.)

        This means that the least impactful Strategy (the Strategy that will have
        its core positions impacted the least by having funds removed) should be
        at `queue`[0], then the next least impactful at `queue`[1], and so on.
    @param queue
        The array of addresses to use as the new withdrawal queue. This is
        order sensitive.
    """
    assert msg.sender in [self.management, self.governance]

    self.withdrawalQueue = queue

    log UpdateWithdrawalQueue(queue)


@internal
def _assertPendingWithdrawalApproved(
    withdrawal: PendingWithdrawal
):
    assert withdrawal.approveStatus in [0, 2], "Vault: pending withdrawal not approved"


@internal
def _assertPendingWithdrawalOpened(
    withdrawal: PendingWithdrawal
):
    assert withdrawal.open, "Vault: pending withdrawal closed"


@external
def setPendingWithdrawalBounty(
    id: uint256,
    bounty: uint256
):
    """
        @notice Update pending withdraw bounty.
        @param id Pending withdrawal id
        @param bounty New bounty value
    """
    self._assertPendingWithdrawalOpened(self.pendingWithdrawals[msg.sender][id])

    self.pendingWithdrawals[msg.sender][id].bounty = bounty

    log UpdatePendingWithdrawalBounty(msg.sender, id, bounty)

@internal
def erc20_safe_transfer(token: address, receiver: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # HACK: Used to handle non-compliant tokens like USDT
    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transfer(address,uint256)"),
            convert(receiver, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) > 0:
        assert convert(response, bool), "Transfer failed!"


@internal
def erc20_safe_transferFrom(token: address, sender: address, receiver: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # HACK: Used to handle non-compliant tokens like USDT
    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transferFrom(address,address,uint256)"),
            convert(sender, bytes32),
            convert(receiver, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) > 0:
        assert convert(response, bool), "Transfer failed!"


@view
@internal
def _totalAssets() -> uint256:
    # See note on `totalAssets()`.
    return self.token.balanceOf(self) + self.totalDebt


@view
@external
def totalAssets() -> uint256:
    """
    @notice
        Returns the total quantity of all assets under control of this
        Vault, whether they're loaned out to a Strategy, or currently held in
        the Vault.
    @return The total assets under control of this Vault.
    """
    return self._totalAssets()


@view
@internal
def _calculateLockedProfit() -> uint256:
    lockedFundsRatio: uint256 = (block.timestamp - self.lastReport) * self.lockedProfitDegradation

    if(lockedFundsRatio < DEGRADATION_COEFFICIENT):
        lockedProfit: uint256 = self.lockedProfit
        return lockedProfit - (
                lockedFundsRatio
                * lockedProfit
                / DEGRADATION_COEFFICIENT
            )
    else:
        return 0

@view
@internal
def _convertToTargetDecimals(amount: uint256) -> uint256:
    if self.targetDecimals == self.tokenDecimals:
        return amount
    elif self.targetDecimals > self.tokenDecimals:
        return amount * 10 ** (self.targetDecimals - self.tokenDecimals)
    else:
        return amount / 10 ** (self.tokenDecimals - self.targetDecimals)


@view
@internal
def _convertFromTargetDecimals(amount: uint256) -> uint256:
    if self.targetDecimals == self.tokenDecimals:
        return amount
    elif self.targetDecimals > self.tokenDecimals:
        return amount / 10 ** (self.targetDecimals - self.tokenDecimals)
    else:
        return amount * 10 ** (self.tokenDecimals - self.targetDecimals)


@internal
def _transferToTon(
    _amount: uint256,
    recipient: TONAddress
):
    # Convert amount to the target decimals
    amount: uint256 = self._convertToTargetDecimals(_amount)

    log Deposit(
        amount,
        recipient.wid,
        recipient.addr,
    )

@internal
def _considerMovementFee(amount: uint256, fee: Fee) -> uint256:
    if fee.size == 0 or amount < fee.step:
        return amount

    feeAmount: uint256 = amount * fee.size / MAX_BPS

    self._transferToTon(feeAmount, self.rewards)

    return (amount - feeAmount)

@internal
@view
def _deriveWithdrawalPeriodId(
    _timestamp: uint256
) -> uint256:
    return _timestamp / WITHDRAW_PERIOD_DURATION_IN_SECONDS


@external
@nonreentrant("withdraw")
def deposit(
    sender: address,
    recipient: TONAddress,
    _amount: uint256,
    pendingWithdrawalId: PendingWithdrawalId,
    sendTransferToTon: bool
):
    """
    @notice
        Deposits `_amount` `token` which leads to issuing token to `recipient` in the Everscale network.

        If the Vault is in Emergency Shutdown, deposits will not be accepted and this call will fail.
    @dev
        In opposite to the original Yearn vaults, this one doesn't issue shares.
        In this case the role of share token is played by the corresponding token on the Everscale side.
        To receive locked tokens back, user should withdraw tokens from the Everscale side.
        See note on `saveWithdraw`

        This may only be called by wrapper.

    @param sender Sender Ethereum address
    @param recipient
        The Everscale recipient to transfer tokens to.
    @param _amount The quantity of tokens to deposit, defaults to all.
    @param pendingWithdrawalId Pending withdrawal id to be closed
    @param sendTransferToTon Boolean, emit transfer to TON or not
    """
    assert not self.emergencyShutdown  # Deposits are locked out

    assert msg.sender == self.wrapper

    # Ensure deposit limit is respected
    assert self._totalAssets() + _amount <= self.depositLimit, "Vault: respect the deposit limit"

    # Consider deposit fee
    amount: uint256 = self._considerMovementFee(_amount, self.depositFee)

    # Ensure we are depositing something
    assert amount > 0

    # Tokens are transferred from the original sender
    self.erc20_safe_transferFrom(self.token.address, sender, self, amount)

    # Fill pending withdrawal if specified
    fillingAmount: uint256 = 0
    fillingBounty: uint256 = 0

    if pendingWithdrawalId.recipient != ZERO_ADDRESS:
        withdrawal: PendingWithdrawal = self.pendingWithdrawals[pendingWithdrawalId.recipient][pendingWithdrawalId.id]

        self._assertPendingWithdrawalApproved(withdrawal)
        self._assertPendingWithdrawalOpened(withdrawal)

        fillingAmount = withdrawal.amount
        fillingBounty = withdrawal.bounty

        self.erc20_safe_transfer(
            self.token.address,
            pendingWithdrawalId.recipient,
            withdrawal.amount - withdrawal.bounty
        )

        self.pendingWithdrawals[pendingWithdrawalId.recipient][pendingWithdrawalId.id].open = False
        self.pendingWithdrawalsTotal -= withdrawal.amount

        log FillPendingWithdrawal(pendingWithdrawalId.recipient, pendingWithdrawalId.id)

    assert amount >= fillingAmount, "Vault: too low deposit for specified fillings"

    if sendTransferToTon:
        self._transferToTon(amount + fillingBounty, recipient)

    log NewDeposit(
        sender,
        recipient.wid,
        recipient.addr,
        amount,
        pendingWithdrawalId.recipient,
        pendingWithdrawalId.id,
        sendTransferToTon
    )

@internal
def _reportLoss(strategy: address, loss: uint256):
    # Loss can only be up the amount of debt issued to strategy
    totalDebt: uint256 = self.strategies[strategy].totalDebt
    assert totalDebt >= loss

    # Also, make sure we reduce our trust with the strategy by the amount of loss
    if self.debtRatio != 0: # if vault with single strategy that is set to EmergencyOne
        # NOTE: The context to this calculation is different than the calculation in `_reportLoss`,
        # this calculation intentionally approximates via `totalDebt` to avoid manipulatable results
        ratio_change: uint256 = min(
            # NOTE: This calculation isn't 100% precise, the adjustment is ~10%-20% more severe due to EVM math
            loss * self.debtRatio / self.totalDebt,
            self.strategies[strategy].debtRatio,
        )
        self.strategies[strategy].debtRatio -= ratio_change
        self.debtRatio -= ratio_change
    # Finally, adjust our strategy's parameters by the loss
    self.strategies[strategy].totalLoss += loss
    self.strategies[strategy].totalDebt = totalDebt - loss
    self.totalDebt -= loss

@internal
def _registerWithdraw(
    id: bytes32
):
    # Withdraw id should not be seen before
    # Id calculated in `wrapper` as `keccack256(bytes memory withdraw_payload)`
    assert not self.withdrawIds[id], "Vault: withdraw already seen"

    self.withdrawIds[id] = True


@external
def saveWithdraw(
    payloadId: bytes32,
    recipient: address,
    _amount: uint256,
    _timestamp: uint256,
    bounty: uint256
):
    """
        @notice
            Unlike the original Yearn Vault, withdrawing from the Broxus Vault may be splitted in a separate steps.

            Withdraw payload event data contents the following details:

            - Withdraw initializer TON address
            - Withdraw amount
            - Withdraw recipient in the Ethereum
            - Chain id (it is necessary, since Broxus Bridge supports multiple EVM networks)

            If there're enough free tokens on the vault, withdraw will be executed immediately.
            If not - withdraw details will be saved into the Vault and user can execute it later in the following ways:

            - Set non zero bounty. Anyone can make a deposit into the Vault and specify user's pending withdrawal,
            so deposited tokens will fill the withdrawal.
            - Same withdraw mechanism as original Yearn.

        @dev
            Anyone can save withdraw request, but only withdraw recipient can specify bounty. Ignores otherwise.

        @param payloadId Withdraw payload ID
        @param recipient Withdraw recipient
        @param _amount Withdraw amount
        @param _timestamp Withdraw event timestamp
        @param bounty Bounty amount
    """
    assert msg.sender == self.wrapper

    assert not self.emergencyShutdown

    self._registerWithdraw(payloadId)

    amount: uint256 = self._convertFromTargetDecimals(_amount)
    amount = self._considerMovementFee(amount, self.withdrawFee)

    withdrawalPeriodId: uint256 = self._deriveWithdrawalPeriodId(_timestamp)

    withdrawalPeriod: WithdrawalPeriod = self.withdrawalPeriods[withdrawalPeriodId]

    # Respect period withdraw limit
    # If there's no limitations for the withdraw - fill it instantly or save as regular pending
    if amount + withdrawalPeriod.total - withdrawalPeriod.considered >= self.withdrawLimitPerPeriod or amount >= self.undeclaredWithdrawLimit:
        self.pendingWithdrawalsTotal += amount

        id: uint256 = self.pendingWithdrawalsPerUser[recipient]
        self.pendingWithdrawalsPerUser[recipient] += 1

        self.pendingWithdrawals[recipient][id] = PendingWithdrawal({
            amount: amount,
            bounty: bounty,
            open: True,
            approveStatus: 1,
            _timestamp: _timestamp
        })

        log CreatePendingWithdrawal(recipient, id, payloadId, amount, bounty)
        log UpdatePendingWithdrawApprove(recipient, id, 1)
    elif amount <= self.token.balanceOf(self):
        self.erc20_safe_transfer(
            self.token.address,
            recipient,
            amount
        )

        log InstantWithdrawal(recipient, payloadId, amount)
    else:
        self.pendingWithdrawalsTotal += amount

        id: uint256 = self.pendingWithdrawalsPerUser[recipient]
        self.pendingWithdrawalsPerUser[recipient] += 1

        self.pendingWithdrawals[recipient][id] = PendingWithdrawal({
            amount: amount,
            bounty: bounty,
            open: True,
            approveStatus: 0,
            _timestamp: _timestamp
        })

        log CreatePendingWithdrawal(recipient, id, payloadId, amount, bounty)

    self.withdrawalPeriods[withdrawalPeriodId].total += amount

@external
def cancelPendingWithdrawal(
    id: uint256,
    amount: uint256,
    recipient: TONAddress
):
    """
    @notice
        In case user has pending withdrawal, he can cancel it by transferring tokens back to the Everscale.
        Works only in case withdrawal approved, see note on `_assertPendingWithdrawalApproved`
    @param id
        Pending withdrawal id
    @param recipient
        The Everscale address to transfer tokens to
    """
    assert not self.emergencyShutdown

    withdrawal: PendingWithdrawal = self.pendingWithdrawals[msg.sender][id]

    self._assertPendingWithdrawalApproved(withdrawal)
    self._assertPendingWithdrawalOpened(withdrawal)

    assert withdrawal.amount >= amount, "Vault: pending withdrawal too small"

    # Ensure we are cancelling something
    assert withdrawal.amount > 0

    self._transferToTon(amount, recipient)

    self.pendingWithdrawalsTotal -= amount
    self.pendingWithdrawals[msg.sender][id].amount -= amount

    if self.pendingWithdrawals[msg.sender][id].amount == 0:
        self.pendingWithdrawals[msg.sender][id].open = False

    log CancelPendingWithdrawal(msg.sender, id, amount)

@external
@nonreentrant("withdraw")
def withdraw(
    id: uint256,
    _value: uint256,
    recipient: address = msg.sender,
    maxLoss: uint256 = 1,  # 0.01% [BPS]
) -> uint256:
    """
    @notice
        Withdraws the calling account's tokens from this Vault, redeeming
        amount `_shares` for an appropriate amount of tokens.

        See note on `setWithdrawalQueue` for further details of withdrawal
        ordering and behavior.
    @dev
        Measuring the value of shares is based on the total outstanding debt
        that this contract has ("expected value") instead of the total balance
        sheet it has ("estimated value") has important security considerations,
        and is done intentionally. If this value were measured against external
        systems, it could be purposely manipulated by an attacker to withdraw
        more assets than they otherwise should be able to claim by redeeming
        their shares.

        On withdrawal, this means that shares are redeemed against the total
        amount that the deposited capital had "realized" since the point it
        was deposited, up until the point it was withdrawn. If that number
        were to be higher than the "expected value" at some future point,
        withdrawing shares via this method could entitle the depositor to
        *more* than the expected value once the "realized value" is updated
        from further reports by the Strategies to the Vaults.

        Under exceptional scenarios, this could cause earlier withdrawals to
        earn "more" of the underlying assets than Users might otherwise be
        entitled to, if the Vault's estimated value were otherwise measured
        through external means, accounting for whatever exceptional scenarios
        exist for the Vault (that aren't covered by the Vault's own design.)

        In the situation where a large withdrawal happens, it can empty the
        vault balance and the strategies in the withdrawal queue.
        Strategies not in the withdrawal queue will have to be harvested to
        rebalance the funds and make the funds available again to withdraw.
    @param id
        Pending withdrawal id
    @param _value
        Amount of tokens to be withdrawn, should less or equal than specified withdrawal size
    @param recipient
        The address to send the redeemed tokens. Defaults to the
        caller's address.
    @param maxLoss
        The maximum acceptable loss to sustain on withdrawal. Defaults to 0.01%.
        If a loss is specified, up to that amount of shares may be burnt to cover losses on withdrawal.
    @return The quantity of tokens redeemed for `_shares`.
    """
    assert not self.emergencyShutdown

    withdrawal: PendingWithdrawal = self.pendingWithdrawals[msg.sender][id]

    self._assertPendingWithdrawalApproved(withdrawal)

    # Ensure withdraw is open
    self._assertPendingWithdrawalOpened(withdrawal)

    value: uint256 = _value

    if value == 0:
        value = withdrawal.amount

    assert value > 0
    assert value <= withdrawal.amount

    if value > self.token.balanceOf(self):
        totalLoss: uint256 = 0
        # We need to go get some from our strategies in the withdrawal queue
        # NOTE: This performs forced withdrawals from each Strategy. During
        #       forced withdrawal, a Strategy may realize a loss. That loss
        #       is reported back to the Vault, and the will affect the amount
        #       of tokens that the withdrawer receives for their shares. They
        #       can optionally specify the maximum acceptable loss (in BPS)
        #       to prevent excessive losses on their withdrawals (which may
        #       happen in certain edge cases where Strategies realize a loss)
        for strategy in self.withdrawalQueue:
            if strategy == ZERO_ADDRESS:
                break  # We've exhausted the queue

            vault_balance: uint256 = self.token.balanceOf(self)
            if value <= vault_balance:
                break  # We're done withdrawing

            amountNeeded: uint256 = value - vault_balance

            # NOTE: Don't withdraw more than the debt so that Strategy can still
            #       continue to work based on the profits it has
            # NOTE: This means that user will lose out on any profits that each
            #       Strategy in the queue would return on next harvest, benefiting others
            amountNeeded = min(amountNeeded, self.strategies[strategy].totalDebt)
            if amountNeeded == 0:
                continue  # Nothing to withdraw from this Strategy, try the next one

            # Force withdraw amount from each Strategy in the order set by governance
            loss: uint256 = Strategy(strategy).withdraw(amountNeeded)
            withdrawn: uint256 = self.token.balanceOf(self) - vault_balance

            # NOTE: Withdrawer incurs any losses from liquidation
            if loss > 0:
                value -= loss
                totalLoss += loss
                self._reportLoss(strategy, loss)

            # Reduce the Strategy's debt by the amount withdrawn ("realized returns")
            # NOTE: This doesn't add to returns as it's not earned by "normal means"
            self.strategies[strategy].totalDebt -= withdrawn
            self.totalDebt -= withdrawn

        assert self.token.balanceOf(self) >= value, "Vault: cant close pending withdrawal even with strategies liquidation"

        # NOTE: This loss protection is put in place to revert if losses from
        #       withdrawing are more than what is considered acceptable.
        assert totalLoss <= maxLoss * (value + totalLoss) / MAX_BPS

    # Withdraw remaining balance to recipient (may be different to msg.sender) (minus fee)
    self.erc20_safe_transfer(self.token.address, recipient, value)

    requestedAmount: uint256 = _value
    if requestedAmount == 0:
        requestedAmount = withdrawal.amount

    self.pendingWithdrawals[msg.sender][id].amount -= requestedAmount

    if self.pendingWithdrawals[msg.sender][id].amount == 0:
        self.pendingWithdrawals[msg.sender][id].open = False

    self.pendingWithdrawalsTotal -= requestedAmount

    log WithdrawPendingWithdrawal(msg.sender, id, requestedAmount, value)

    return value

@external
def addStrategy(
    strategy: address,
    debtRatio: uint256,
    minDebtPerHarvest: uint256,
    maxDebtPerHarvest: uint256,
    performanceFee: uint256,
):
    """
    @notice
        Add a Strategy to the Vault.

        This may only be called by governance.
    @dev
        The Strategy will be appended to `withdrawalQueue`, call
        `setWithdrawalQueue` to change the order.
    @param strategy The address of the Strategy to add.
    @param debtRatio
        The share of the total assets in the `vault that the `strategy` has access to.
    @param minDebtPerHarvest
        Lower limit on the increase of debt since last harvest
    @param maxDebtPerHarvest
        Upper limit on the increase of debt since last harvest
    @param performanceFee
        The fee the strategist will receive based on this Vault's performance.
    """
    # Check if queue is full
    assert self.withdrawalQueue[MAXIMUM_STRATEGIES - 1] == ZERO_ADDRESS

    # Check calling conditions
    assert not self.emergencyShutdown
    assert msg.sender == self.governance

    # Check strategy configuration
    assert strategy != ZERO_ADDRESS
    assert self.strategies[strategy].activation == 0
    assert self == Strategy(strategy).vault()
    assert self.token.address == Strategy(strategy).want()

    # Check strategy parameters
    assert self.debtRatio + debtRatio <= MAX_BPS
    assert minDebtPerHarvest <= maxDebtPerHarvest
    assert performanceFee <= MAX_BPS / 2

    # Add strategy to approved strategies
    self.strategies[strategy] = StrategyParams({
        performanceFee: performanceFee,
        activation: block.timestamp,
        debtRatio: debtRatio,
        minDebtPerHarvest: minDebtPerHarvest,
        maxDebtPerHarvest: maxDebtPerHarvest,
        lastReport: block.timestamp,
        totalDebt: 0,
        totalGain: 0,
        totalSkim: 0,
        totalLoss: 0,
        rewardsManager: ZERO_ADDRESS,
        rewards: self.rewards
    })
    log StrategyAdded(strategy, debtRatio, minDebtPerHarvest, maxDebtPerHarvest, performanceFee)

    # Update Vault parameters
    self.debtRatio += debtRatio


@external
def updateStrategyDebtRatio(
    strategy: address,
    debtRatio: uint256,
):
    """
    @notice
        Change the quantity of assets `strategy` may manage.

        This may be called by governance or management.
    @param strategy The Strategy to update.
    @param debtRatio The quantity of assets `strategy` may now manage.
    """
    assert msg.sender == self.governance
    assert self.strategies[strategy].activation > 0
    self.debtRatio -= self.strategies[strategy].debtRatio
    self.strategies[strategy].debtRatio = debtRatio
    self.debtRatio += debtRatio
    assert self.debtRatio <= MAX_BPS
    log StrategyUpdateDebtRatio(strategy, debtRatio)


@external
def updateStrategyMinDebtPerHarvest(
    strategy: address,
    minDebtPerHarvest: uint256,
):
    """
    @notice
        Change the quantity assets per block this Vault may deposit to or
        withdraw from `strategy`.

        This may only be called by governance or management.
    @param strategy The Strategy to update.
    @param minDebtPerHarvest
        Lower limit on the increase of debt since last harvest
    """
    assert msg.sender in [self.management, self.governance]
    assert self.strategies[strategy].activation > 0
    assert self.strategies[strategy].maxDebtPerHarvest >= minDebtPerHarvest
    self.strategies[strategy].minDebtPerHarvest = minDebtPerHarvest
    log StrategyUpdateMinDebtPerHarvest(strategy, minDebtPerHarvest)


@external
def updateStrategyMaxDebtPerHarvest(
    strategy: address,
    maxDebtPerHarvest: uint256,
):
    """
    @notice
        Change the quantity assets per block this Vault may deposit to or
        withdraw from `strategy`.

        This may only be called by governance or management.
    @param strategy The Strategy to update.
    @param maxDebtPerHarvest
        Upper limit on the increase of debt since last harvest
    """
    assert msg.sender in [self.management, self.governance]
    assert self.strategies[strategy].activation > 0
    assert self.strategies[strategy].minDebtPerHarvest <= maxDebtPerHarvest
    self.strategies[strategy].maxDebtPerHarvest = maxDebtPerHarvest
    log StrategyUpdateMaxDebtPerHarvest(strategy, maxDebtPerHarvest)


@external
def updateStrategyPerformanceFee(
    strategy: address,
    performanceFee: uint256,
):
    """
    @notice
        Change the fee the strategist will receive based on this Vault's
        performance.

        This may only be called by governance.
    @param strategy The Strategy to update.
    @param performanceFee The new fee the strategist will receive.
    """
    assert msg.sender == self.governance
    assert performanceFee <= MAX_BPS / 2
    assert self.strategies[strategy].activation > 0
    self.strategies[strategy].performanceFee = performanceFee
    log StrategyUpdatePerformanceFee(strategy, performanceFee)


@internal
def _revokeStrategy(strategy: address):
    self.debtRatio -= self.strategies[strategy].debtRatio
    self.strategies[strategy].debtRatio = 0
    log StrategyRevoked(strategy)


@external
def migrateStrategy(oldVersion: address, newVersion: address):
    """
    @notice
        Migrates a Strategy, including all assets from `oldVersion` to
        `newVersion`.

        This may only be called by governance.
    @dev
        Strategy must successfully migrate all capital and positions to new
        Strategy, or else this will upset the balance of the Vault.

        The new Strategy should be "empty" e.g. have no prior commitments to
        this Vault, otherwise it could have issues.
    @param oldVersion The existing Strategy to migrate from.
    @param newVersion The new Strategy to migrate to.
    """
    assert msg.sender == self.governance
    assert newVersion != ZERO_ADDRESS
    assert self.strategies[oldVersion].activation > 0
    assert self.strategies[newVersion].activation == 0

    strategy: StrategyParams = self.strategies[oldVersion]

    self._revokeStrategy(oldVersion)
    # _revokeStrategy will lower the debtRatio
    self.debtRatio += strategy.debtRatio
    # Debt is migrated to new strategy
    self.strategies[oldVersion].totalDebt = 0

    self.strategies[newVersion] = StrategyParams({
        performanceFee: strategy.performanceFee,
        # NOTE: use last report for activation time, so E[R] calc works
        activation: strategy.lastReport,
        debtRatio: strategy.debtRatio,
        minDebtPerHarvest: strategy.minDebtPerHarvest,
        maxDebtPerHarvest: strategy.maxDebtPerHarvest,
        lastReport: strategy.lastReport,
        totalDebt: strategy.totalDebt,
        totalGain: 0,
        totalSkim: 0,
        totalLoss: 0,
        rewardsManager: strategy.rewardsManager,
        rewards: strategy.rewards
    })

    Strategy(oldVersion).migrate(newVersion)
    log StrategyMigrated(oldVersion, newVersion)

    for idx in range(MAXIMUM_STRATEGIES):
        if self.withdrawalQueue[idx] == oldVersion:
            self.withdrawalQueue[idx] = newVersion
            return  # Don't need to reorder anything because we swapped


@external
def revokeStrategy(strategy: address = msg.sender):
    """
    @notice
        Revoke a Strategy, setting its debt limit to 0 and preventing any
        future deposits.

        This function should only be used in the scenario where the Strategy is
        being retired but no migration of the positions are possible, or in the
        extreme scenario that the Strategy needs to be put into "Emergency Exit"
        mode in order for it to exit as quickly as possible. The latter scenario
        could be for any reason that is considered "critical" that the Strategy
        exits its position as fast as possible, such as a sudden change in market
        conditions leading to losses, or an imminent failure in an external
        dependency.

        This may only be called by governance, the guardian, or the Strategy
        itself. Note that a Strategy will only revoke itself during emergency
        shutdown.
    @param strategy The Strategy to revoke.
    """
    assert msg.sender in [strategy, self.governance, self.guardian]
    # NOTE: This function may be called via `BaseStrategy.setEmergencyExit` while the
    #       strategy might have already been revoked or had the debt limit set to zero
    if self.strategies[strategy].debtRatio == 0:
        return # already set to zero, nothing to do

    self._revokeStrategy(strategy)


@view
@internal
def _debtOutstanding(strategy: address) -> uint256:
    # See note on `debtOutstanding()`.
    if self.debtRatio == 0:
        return self.strategies[strategy].totalDebt

    strategy_debtLimit: uint256 = (
        self.strategies[strategy].debtRatio
        * self._totalAssets()
        / MAX_BPS
    )
    strategy_totalDebt: uint256 = self.strategies[strategy].totalDebt

    if self.emergencyShutdown:
        return strategy_totalDebt
    elif strategy_totalDebt <= strategy_debtLimit:
        return 0
    else:
        return strategy_totalDebt - strategy_debtLimit


@view
@external
def debtOutstanding(strategy: address = msg.sender) -> uint256:
    """
    @notice
        Determines if `strategy` is past its debt limit and if any tokens
        should be withdrawn to the Vault.
    @param strategy The Strategy to check. Defaults to the caller.
    @return The quantity of tokens to withdraw.
    """
    return self._debtOutstanding(strategy)


@view
@internal
def _creditAvailable(strategy: address) -> uint256:
    # See note on `creditAvailable()`.
    if self.emergencyShutdown:
        return 0

    vault_totalAssets: uint256 = self._totalAssets()

    # Cant extend Strategies debt until total amount of pending withdrawals is more than Vault's total assets
    if self.pendingWithdrawalsTotal >= vault_totalAssets:
        return 0

    vault_debtLimit: uint256 =  self.debtRatio * vault_totalAssets / MAX_BPS
    vault_totalDebt: uint256 = self.totalDebt
    strategy_debtLimit: uint256 = self.strategies[strategy].debtRatio * vault_totalAssets / MAX_BPS
    strategy_totalDebt: uint256 = self.strategies[strategy].totalDebt
    strategy_minDebtPerHarvest: uint256 = self.strategies[strategy].minDebtPerHarvest
    strategy_maxDebtPerHarvest: uint256 = self.strategies[strategy].maxDebtPerHarvest

    # Exhausted credit line
    if strategy_debtLimit <= strategy_totalDebt or vault_debtLimit <= vault_totalDebt:
        return 0

    # Start with debt limit left for the Strategy
    available: uint256 = strategy_debtLimit - strategy_totalDebt

    # Adjust by the global debt limit left
    available = min(available, vault_debtLimit - vault_totalDebt)

    # Can only borrow up to what the contract has in reserve
    # NOTE: Running near 100% is discouraged
    available = min(available, self.token.balanceOf(self))

    # Adjust by min and max borrow limits (per harvest)
    # NOTE: min increase can be used to ensure that if a strategy has a minimum
    #       amount of capital needed to purchase a position, it's not given capital
    #       it can't make use of yet.
    # NOTE: max increase is used to make sure each harvest isn't bigger than what
    #       is authorized. This combined with adjusting min and max periods in
    #       `BaseStrategy` can be used to effect a "rate limit" on capital increase.
    if available < strategy_minDebtPerHarvest:
        return 0
    else:
        return min(available, strategy_maxDebtPerHarvest)

@view
@external
def creditAvailable(strategy: address = msg.sender) -> uint256:
    """
    @notice
        Amount of tokens in Vault a Strategy has access to as a credit line.

        This will check the Strategy's debt limit, as well as the tokens
        available in the Vault, and determine the maximum amount of tokens
        (if any) the Strategy may draw on.

        In the rare case the Vault is in emergency shutdown this will return 0.
    @param strategy The Strategy to check. Defaults to caller.
    @return The quantity of tokens available for the Strategy to draw on.
    """
    return self._creditAvailable(strategy)


@view
@internal
def _expectedReturn(strategy: address) -> uint256:
    # See note on `expectedReturn()`.
    strategy_lastReport: uint256 = self.strategies[strategy].lastReport
    timeSinceLastHarvest: uint256 = block.timestamp - strategy_lastReport
    totalHarvestTime: uint256 = strategy_lastReport - self.strategies[strategy].activation

    # NOTE: If either `timeSinceLastHarvest` or `totalHarvestTime` is 0, we can short-circuit to `0`
    if timeSinceLastHarvest > 0 and totalHarvestTime > 0 and Strategy(strategy).isActive():
        # NOTE: Unlikely to throw unless strategy accumalates >1e68 returns
        # NOTE: Calculate average over period of time where harvests have occured in the past
        return (
            self.strategies[strategy].totalGain
            * timeSinceLastHarvest
            / totalHarvestTime
        )
    else:
        return 0  # Covers the scenario when block.timestamp == activation


@view
@external
def availableDepositLimit() -> uint256:
    if self.depositLimit > self._totalAssets():
        return self.depositLimit - self._totalAssets()
    else:
        return 0


@view
@external
def expectedReturn(strategy: address = msg.sender) -> uint256:
    """
    @notice
        Provide an accurate expected value for the return this `strategy`
        would provide to the Vault the next time `report()` is called
        (since the last time it was called).
    @param strategy The Strategy to determine the expected return for. Defaults to caller.
    @return
        The anticipated amount `strategy` should make on its investment
        since its last report.
    """
    return self._expectedReturn(strategy)


@internal
def _assessFees(strategy: address, gain: uint256) -> uint256:
    if self.strategies[strategy].activation == block.timestamp:
        return 0  # NOTE: Just added, no fees to assess

    duration: uint256 = block.timestamp - self.strategies[strategy].lastReport
    assert duration != 0 #dev: can't call assessFees twice within the same block

    if gain == 0:
        # NOTE: The fees are not charged if there hasn't been any gains reported
        return 0

    management_fee: uint256 = (
        (
            (self.strategies[strategy].totalDebt - Strategy(strategy).delegatedAssets())
            * duration
            * self.managementFee
        )
        / MAX_BPS
        / SECS_PER_YEAR
    )

    # NOTE: Applies if Strategy is not shutting down, or it is but all debt paid off
    # NOTE: No fee is taken when a Strategy is unwinding it's position, until all debt is paid
    strategist_fee: uint256 = (
        gain
        * self.strategies[strategy].performanceFee
        / MAX_BPS
    )
    # NOTE: Unlikely to throw unless strategy reports >1e72 harvest profit
    performance_fee: uint256 = gain * self.performanceFee / MAX_BPS

    # NOTE: This must be called prior to taking new collateral,
    #       or the calculation will be wrong!
    # NOTE: This must be done at the same time, to ensure the relative
    #       ratio of governance_fee : strategist_fee is kept intact
    total_fee: uint256 = performance_fee + strategist_fee + management_fee

    # ensure total_fee is not more than gain
    # is so - normalize fees, so total fee is equal to gain
    if total_fee > gain:
        strategist_fee = strategist_fee * gain / total_fee
        performance_fee = performance_fee * gain / total_fee
        management_fee = management_fee * gain / total_fee

        total_fee = gain

    if strategist_fee > 0:
        self._transferToTon(
            strategist_fee,
            self.strategies[strategy].rewards,
        )

    if performance_fee + management_fee > 0:
        self._transferToTon(
            performance_fee + management_fee,
            self.rewards,
        )

    return total_fee


@external
def report(gain: uint256, loss: uint256, _debtPayment: uint256) -> uint256:
    """
    @notice
        Reports the amount of assets the calling Strategy has free (usually in
        terms of ROI).

        The performance fee is determined here, off of the strategy's profits
        (if any), and sent to governance.

        The strategist's fee is also determined here (off of profits), to be
        handled according to the strategist on the next harvest.

        This may only be called by a Strategy managed by this Vault.
    @dev
        For approved strategies, this is the most efficient behavior.
        The Strategy reports back what it has free, then Vault "decides"
        whether to take some back or give it more. Note that the most it can
        take is `gain + _debtPayment`, and the most it can give is all of the
        remaining reserves. Anything outside of those bounds is abnormal behavior.

        All approved strategies must have increased diligence around
        calling this function, as abnormal behavior could become catastrophic.
    @param gain
        Amount Strategy has realized as a gain on it's investment since its
        last report, and is free to be given back to Vault as earnings
    @param loss
        Amount Strategy has realized as a loss on it's investment since its
        last report, and should be accounted for on the Vault's balance sheet.
        The loss will reduce the debtRatio. The next time the strategy will harvest,
        it will pay back the debt in an attempt to adjust to the new debt limit.
    @param _debtPayment
        Amount Strategy has made available to cover outstanding debt
    @return Amount of debt outstanding (if totalDebt > debtLimit or emergency shutdown).
    """

    # Only approved strategies can call this function
    assert self.strategies[msg.sender].activation > 0

    # No lying about total available to withdraw!
    assert self.token.balanceOf(msg.sender) >= gain + _debtPayment

    # We have a loss to report, do it before the rest of the calculations
    if loss > 0:
        self._reportLoss(msg.sender, loss)

    # Assess both management fee and performance fee, and issue both as shares of the vault
    totalFees: uint256 = self._assessFees(msg.sender, gain)

    # Returns are always "realized gains"
    self.strategies[msg.sender].totalGain += gain

    # Compute the line of credit the Vault is able to offer the Strategy (if any)
    credit: uint256 = self._creditAvailable(msg.sender)

    # Outstanding debt the Strategy wants to take back from the Vault (if any)
    # NOTE: debtOutstanding <= StrategyParams.totalDebt
    debt: uint256 = self._debtOutstanding(msg.sender)
    debtPayment: uint256 = min(_debtPayment, debt)

    if debtPayment > 0:
        self.strategies[msg.sender].totalDebt -= debtPayment
        self.totalDebt -= debtPayment
        debt -= debtPayment
        # NOTE: `debt` is being tracked for later

    # Update the actual debt based on the full credit we are extending to the Strategy
    # or the returns if we are taking funds back
    # NOTE: credit + self.strategies[msg.sender].totalDebt is always < self.debtLimit
    # NOTE: At least one of `credit` or `debt` is always 0 (both can be 0)
    if credit > 0:
        self.strategies[msg.sender].totalDebt += credit
        self.totalDebt += credit

    # Give/take balance to Strategy, based on the difference between the reported gains
    # (if any), the debt payment (if any), the credit increase we are offering (if any),
    # and the debt needed to be paid off (if any)
    # NOTE: This is just used to adjust the balance of tokens between the Strategy and
    #       the Vault based on the Strategy's debt limit (as well as the Vault's).
    totalAvail: uint256 = gain + debtPayment
    if totalAvail < credit:  # credit surplus, give to Strategy
        self.erc20_safe_transfer(self.token.address, msg.sender, credit - totalAvail)
    elif totalAvail > credit:  # credit deficit, take from Strategy
        self.erc20_safe_transferFrom(self.token.address, msg.sender, self, totalAvail - credit)
    # else, don't do anything because it is balanced

    # Profit is locked and gradually released per block
    # NOTE: compute current locked profit and replace with sum of current and new
    lockedProfitBeforeLoss: uint256 = self._calculateLockedProfit() + gain - totalFees
    if lockedProfitBeforeLoss > loss:
        self.lockedProfit = lockedProfitBeforeLoss - loss
    else:
        self.lockedProfit = 0

    # Update reporting time
    self.strategies[msg.sender].lastReport = block.timestamp
    self.lastReport = block.timestamp

    log StrategyReported(
        msg.sender,
        gain,
        loss,
        debtPayment,
        self.strategies[msg.sender].totalGain,
        self.strategies[msg.sender].totalSkim,
        self.strategies[msg.sender].totalLoss,
        self.strategies[msg.sender].totalDebt,
        credit,
        self.strategies[msg.sender].debtRatio,
    )

    if self.strategies[msg.sender].debtRatio == 0 or self.emergencyShutdown:
        # Take every last penny the Strategy has (Emergency Exit/revokeStrategy)
        # NOTE: This is different than `debt` in order to extract *all* of the returns
        return Strategy(msg.sender).estimatedTotalAssets()
    else:
        # Otherwise, just return what we have as debt outstanding
        return debt

@external
def sweep(token: address, amount: uint256 = MAX_UINT256):
    """
    @notice
        Removes tokens from this Vault that are not the type of token managed
        by this Vault. This may be used in case of accidentally sending the
        wrong kind of token to this Vault.

        Tokens will be sent to `governance`.

        This will fail if an attempt is made to sweep the tokens that this
        Vault manages.

        This may only be called by governance.
    @param token The token to transfer out of this vault.
    @param amount The quantity or tokenId to transfer out.
    """
    assert msg.sender == self.governance
    # Can't be used to steal what this Vault is protecting
    assert token != self.token.address
    value: uint256 = amount
    if value == MAX_UINT256:
        value = ERC20(token).balanceOf(self)
    self.erc20_safe_transfer(token, self.governance, value)

@external
def emergencyWithdrawAndRevoke(
    strategy: address,
    _amountNeeded: uint256 = MAX_UINT256
):
    """
        @notice
            Withdraws all the debt from the strategy and revokes it.
            This may only be called by governance or guardian.
        @param strategy The Strategy to withdraw and revoke.
        @param _amountNeeded The amount of tokens to be withdrawn. By default - strategy debt
    """

    assert msg.sender in [self.guardian, self.governance]

    amountNeeded: uint256 = 0

    if _amountNeeded == MAX_UINT256:
        amountNeeded = self.strategies[strategy].totalDebt
    else:
        amountNeeded = _amountNeeded

    assert amountNeeded > 0

    assert self.strategies[strategy].activation > 0

    vault_balance: uint256 = self.token.balanceOf(self)

    loss: uint256 = Strategy(strategy).withdraw(amountNeeded)
    withdrawn: uint256 = self.token.balanceOf(self) - vault_balance

    if loss > 0:
        self._reportLoss(strategy, loss)

    # Reduce the Strategy's debt by the amount withdrawn ("realized returns")
    # NOTE: This doesn't add to returns as it's not earned by "normal means"
    self.strategies[strategy].totalDebt -= withdrawn
    self.totalDebt -= withdrawn

    self._revokeStrategy(strategy)

@external
def forceWithdraw(recipient: address, id: uint256):
    """
    @notice
        Force user's pending withdraw. Works only if Vault has enough
        tokens on its balance.

        This may only be called by wrapper.
    @param recipient Address of person, who owns a pending withdrawal
    @param id Pending withdrawal id
    """

    assert msg.sender == self.wrapper

    withdrawal: PendingWithdrawal = self.pendingWithdrawals[recipient][id]

    self._assertPendingWithdrawalApproved(withdrawal)
    self._assertPendingWithdrawalOpened(withdrawal)

    self.erc20_safe_transfer(self.token.address, recipient, withdrawal.amount)

    self.pendingWithdrawalsTotal -= withdrawal.amount

    self.pendingWithdrawals[recipient][id].amount = 0
    self.pendingWithdrawals[recipient][id].open = False

    log ForceWithdraw(recipient, id)

@external
def skim(strategy: address):
    """
    @notice
        Skim strategy gain to the Everscale side.

        This may only be called by management or governance.
    @param strategy Strategy to skim
    """
    assert msg.sender in [self.management, self.governance]

    assert self.strategies[strategy].activation > 0

    amount: uint256 = self.strategies[strategy].totalGain - self.strategies[strategy].totalSkim

    assert amount > 0

    self.strategies[strategy].totalSkim += amount

    self._transferToTon(amount, self.rewards)

@external
def setPendingWithdrawApprove(
    recipient: address,
    id: uint256,
    approveStatus: uint256
):
    """
        @notice
            Set approve status to the specific pending withdrawal.
            Once approve status has been set, it can't be changed.
            If approve status is 2 (approved) and if vault has enough tokens - withdrawal is closed instantly.

            This may only be called by wrapper.
        @param recipient Address of person, who owns a pending withdrawal
        @param id Pending withdrawal id
        @param approveStatus New approve status
    """

    assert msg.sender == self.wrapper

    assert approveStatus in [2,3], "Vault: approve status wrong"

    pendingWithdrawal: PendingWithdrawal = self.pendingWithdrawals[recipient][id]

    # Check withdrawal requires approve
    assert pendingWithdrawal.approveStatus == 1, "Vault: withdrawal status wrong"

    self.pendingWithdrawals[recipient][id].approveStatus = approveStatus

    log UpdatePendingWithdrawApprove(recipient, id, approveStatus)

    # Update withdraw period considered amount
    # Works both for rejected and approved withdrawals
    withdrawalPeriodId: uint256 = self._deriveWithdrawalPeriodId(pendingWithdrawal._timestamp)

    self.withdrawalPeriods[withdrawalPeriodId].considered += pendingWithdrawal.amount

    # Withdraw instantly if vault has enough tokens
    if approveStatus == 2 and pendingWithdrawal.amount <= self.token.balanceOf(self):
        self.pendingWithdrawals[recipient][id].open = False

        self.erc20_safe_transfer(
            self.token.address,
            recipient,
            pendingWithdrawal.amount
        )

        self.pendingWithdrawalsTotal -= pendingWithdrawal.amount

        log WithdrawApprovedWithdrawal(recipient, id)