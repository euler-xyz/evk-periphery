## Verification

### Step 1

Verify the primary contracts using the `verifyContracts.sh` script:

    ./script/utils/verifyContracts.sh script/deployments/mainnet/broadcast/Core.s.sol.json

Note that you may need to do this for each deployment you ran.

### Step 2

For contracts created by other contracts, verify them manually.

#### BeaconProxy

After somebody deploys a vault, collect the trailing data from the logs, then use it to encode constructor args:

    cast abi-encode "constructor(bytes memory)" "0x00000000C02AAA39B223FE8D0A0E5C4F27EAD9083C756CC283B3B76873D36A28440CF53371DF404C424971360000000000000000000000000000000000000348"

Then you can run `forge verify-contract` manually:

    forge verify-contract 0xd8b27cf359b7d15710a5be299af6e7bf904984c2 BeaconProxy --chain mainnet --verifier-url FIXME --etherscan-api-key FIXME --skip-is-verified-check --watch --constructor-args 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc283b3b76873d36a28440cf53371df404c424971360000000000000000000000000000000000000348

#### EulerRouter

    cast abi-encode "constructor(address,address)" 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383 0xee009faf00cf54c1b4387829af7a8dc5f0c8c8c5

    forge verify-contract 0x83b3b76873d36a28440cf53371df404c42497136 EulerRouter --chain mainnet --verifier-url FIXME --etherscan-api-key FIXME --skip-is-verified-check --watch --constructor-args 0x0000000000000000000000000c9a3dd6b8f28529d72d7f9ce918d493519ee383000000000000000000000000ee009faf00cf54c1b4387829af7a8dc5f0c8c8c5

#### IRMLinearKink

    cast abi-encode "constructor(uint256,uint256,uint256,uint32)" 0 218407859 42500370385 3865470566

    forge verify-contract 0x3ff20b354dcc623073647e4f2a2cd955a45defb1 IRMLinearKink --chain mainnet --verifier-url FIXME --etherscan-api-key FIXME --skip-is-verified-check --watch --constructor-args 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d04a3b300000000000000000000000000000000000000000000000000000009e5382fd100000000000000000000000000000000000000000000000000000000e6666666

#### DToken

DToken takes no constructor args

    forge verify-contract 0x6ac3bd91be9a390aeb12c9e5512f4f75b7589311 DToken --chain mainnet --verifier-url FIXME --etherscan-api-key FIXME --skip-is-verified-check --watch --constructor-args 0x
