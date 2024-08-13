# ZKsync Token Proposer MVP

This repo contains contracts for Hats Protocol's submission to the ZKsync Token Proposer MVP. It contains the following contracts:

- `GrantCreator`: A contract that creates all the components for a new grant. See below for more details.
- `StreamManager`: One of the components of a grant. It is responsible for minting new tokens and streaming them to the recipient. See below for more details.

## Prerequisites

These contracts assume that the following elements are already deployed on ZKsync:

- Factories for the following Hats modules and peripheral contracts:
  - Allowlist Eligibility 
  - Agreement Eligibility
  - Hats Signer Gate
- A Multi Claims Hatter instance
- The ZK Token
- The ZK Token Governor and associated Timelock
- The SablierV2LockupLinear contract
- The Safe proxy factory
- The Hats Signer Gate Factory
- A Hats tree (`x`) with the following hats

  | Hat Name                         | Hat ID    | Wearer                           | Required      |
  |----------------------------------|-----------|----------------------------------|---------------|
  | Tophat                           | `x`         | ZK Token Governor Timelock       | exactly as is |
  | Auto Admin                       | `x.1`       | Multi Claims Hatter instance     | exactly as is |
  | $ZK Token Controller             | `x.1.1`     | ZK Token Governor Timelock       | exactly as is |
  | $ZK Grant Funding                | `x.1.1.1`   | Grant Creator instance (to be deployed) | Yes    |
  | Grants Accountability            | `x.1.1.2`   |                                  | optional      |
  | Accountability Council           | `x.1.1.2.1` |                                  | Yes           |
  | Accountability Council Member    | `x.1.1.2.2` |                                  | optional      |
  | Grants Operations                | `x.1.1.3`   |                                  | optional      |
  | KYC Service Provider             | `x.1.1.3.1` |                                  | Yes           |


## Grant Creator

This contract is responsible for creating all the components for a new grant. It does this by...

1. Creating a new Grant Recipient hat `x.1.1.1.y` and minting it to the specified recipient. The hat has the following properties:
    - Grant name
    - Grant agreement, e.g. a URI to a document
    - Allowlist eligibility module, owned by the KYC Service Provider hat. This is how we ensure that the grant recipient has passed KYC
    - Agreement eligibility module, with the arbitrator role set to the Accountability Council hat
    - A chaining eligibility module that combines the above two

2. Creating a new Safe and Hats Signer Gate, with the signer hat set as the Grant Recipient hat (1)

3. Creating a new Stream Manager instance, with the following properties:
    - Grant recipient Safe (2) set as the stream receiver
    - Grant amount
    - Grant stream duration
    - The Grant Recipient hat (1) authorized to initiate the stream
    - The Accountability Council hat authorized to cancel the stream

In order to create the new Grant Recipient hat (1), this contract must wear the $ZK Grant Funding hat `x.1.1.1`.

This contract is designed to work with the ZK Token Governor by creating a new proposal that calls the `createGrant` function.

### Creating a new grant

```solidity
function createGrant(string name, string agreement, uint256 accountabilityJudgeHat, uint256 kycManagerHat, uint128 amount, uint40 streamDuration, address predictedStreamManagerAddress) 
  external returns (uint256 recipientHat, address hsg, address recipientSafe, address streamManager);
```

The `predictedStreamManagerAddress` is required to ensure that the Stream Manager instance deployed by this contract is the same one granted the `MINTER_ROLE` in the ZK Token contract. Typically, a proposal will include both the `createGrant` call and the `grantMinterRole` call as separate actions in a multicall. These actions can be executed in the same transaction, but the result of one cannot be used as input to the other. Use the following function to get the predicted Stream Manager address:

```solidity
function predictStreamManagerAddress(uint256 accountabilityJudgeHat, uint128 amount, uint40 streamDuration) external view returns (address);
```

## Stream Manager

This contract is responsible for minting new tokens and streaming them to the recipient. It authorizes a specified Grant Recipient hat to initiate a stream, and a specified Accountability Council hat to cancel the stream.

To function, it must be authorized to mint new tokens by the ZK Token Governor, ie it must have the `MINTER_ROLE` in the ZK Token contract.

### Creating a new stream

This function can only be called by a wearer of the Grant Recipient hat. It mints new $ZK tokens and starts a stream to the recipient Safe.

```solidity
function createStream() external returns (uint256 streamId);
```

### Cancelling a stream

This function can only be called by a wearer of the Accountability Council hat. It cancels the stream and transfers any unstreamed tokens to the specified destination.

```solidity
function cancelStream(address refundDestination) external;
```