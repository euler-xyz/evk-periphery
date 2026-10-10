# BondHolder

The `BondHolder` contract enables vault curators and other participants to lock vault shares as first-loss capital, demonstrating "skin in the game" to protect lenders. Optionally, it can receive fee distributions that improve the exchange rate for bond holders over time.

## Overview

BondHolder's primary purpose is to provide a **first-loss capital mechanism** where vault curators lock their vault shares to signal their commitment and align incentives with lenders. By requiring a 30-day unbond delay, the contract ensures that curators cannot exit early during periods of stress, providing additional protection beyond the vault's built-in bad debt socialization mechanism.

As an optional feature, the vault's governor can designate the BondHolder contract as the vault's `feeReceiver`. When this is configured, fee distributions (in the form of vault shares) are transferred to the BondHolder during the [fee flow auctions](https://docs.euler.finance/euler-vault-kit-white-paper/#fees), improving the exchange rate for all bond holders as a reward for providing first-loss protection.

### Key Concepts

- **First-Loss Capital**: Vault shares locked by curators to provide protection for depositors in case of bank runs or adverse events
- **Vault Shares**: ERC-4626 tokens representing ownership in a vault
- **Bond Shares**: Internal accounting units representing a user's proportional claim on the BondHolder's vault shares
- **Exchange Rate**: The ratio between bond shares and vault shares, which can improve if the BondHolder receives fee distributions
- **Unbond Delay**: A 30-day waiting period between initiating and completing an unbond, ensuring curators remain committed during periods of stress

## How It Works

### Bonding

When a user bonds vault shares:

1. Vault shares are transferred from the user to the BondHolder contract
2. Bond shares are accounted for the user based on the current exchange rate
3. The exchange rate formula is:
   ```
   bondShares = vaultShares × (totalBondShares + VIRTUAL_AMOUNT) / (vaultBalance + VIRTUAL_AMOUNT)
   ```

The `VIRTUAL_AMOUNT` (1e6) prevents manipulation and division by zero, following EVK-style accounting.

### Fee Distribution (Optional)

When the vault's governor sets the BondHolder as the vault's `feeReceiver`, bond holders receive additional rewards:

1. **Fee Accrual**: As borrowers pay interest, a portion accumulates as fees in the vault (see [EVK Fees](https://docs.euler.finance/euler-vault-kit-white-paper/#fees))

2. **Fee Conversion**: When `convertFees()` is called (typically during fee flow auctions that occur approximately every 7 days), the accumulated fees are converted to vault shares

3. **Fee Distribution**: The portion designated for the governor (after the Euler DAO's protocol fee) is transferred as vault shares to the BondHolder contract

4. **Exchange Rate Improvement**: Since vault shares increase while total bond shares remain constant, the exchange rate improves

Example:
- Initial state: 100 bond shares = 100 vault shares (1:1 ratio)
- Fee auction occurs: 10 vault shares transferred to BondHolder
- New state: 100 bond shares = 110 vault shares (1:1.1 ratio)
- Bond holders can now unbond 10% more vault shares than they deposited

**Note**: If the BondHolder is not set as the `feeReceiver`, the exchange rate remains constant (1:1), and the contract purely serves as a first-loss commitment mechanism.

### Unbonding

Unbonding is a two-step process with a 30-day delay:

1. **Initiate Unbond**: User calls `initiateUnbond()`
   - Bond shares are converted to vault shares at the current exchange rate
   - Vault shares are locked for the user
   - User does not benefit from fees during the delay period
   - Bond shares are removed from circulation

2. **Complete Unbond**: After 30 days, user calls `unbond(receiver)`
   - Locked vault shares are transferred to the receiver
   - All unbond state is cleared

### Canceling Unbond

Users can cancel an unbond before completion by calling `cancelUnbond()`. This converts the locked vault shares back to bond shares at the current exchange rate, effectively re-bonding at the current rate.

## Important Considerations

### First-Loss Capital and Skin in the Game

The BondHolder contract complements the vault's [bad debt socialization](https://docs.euler.finance/euler-vault-kit-white-paper/#bad-debt-socialisation) mechanism:

- **Bad Debt Socialization**: Handles sporadic liquidation failures where collateral value is insufficient, spreading losses among all depositors
- **First-Loss Capital (BondHolder)**: Provides an additional protection layer by ensuring curators cannot exit early during stress events

During a bank run scenario:
1. If bad debt occurs, it is first socialized among all depositors (including the vault shares held by BondHolder)
2. BondHolder's locked shares effectively serve as junior tranche capital that absorbs losses proportionally
3. Curators (and users who deposited into BondHolder) cannot immediately withdraw during the crisis due to the 30-day unbond delay
4. This ensures curators bear the consequences of poor risk management decisions

### UI Warning Logic

User interfaces should display warnings when vault curators have insufficient skin in the game. Example logic:

```
// Display warning if curator doesn't have adequate first-loss coverage
if (vault_is_borrowable 
    AND vault_has_external_curator 
    AND (total_assets_cover < supply_cap / 100 
         OR total_assets_cover < total_assets / 100)) {
    display_warning("Curator has less than 1% first-loss capital coverage")
}
```

This alerts depositors when the curator's first-loss capital is less than 1% of either the supply cap or total assets, indicating potentially inadequate alignment of incentives.

### MEV Resistance

The BondHolder contract is resistant to MEV attacks:

- **Fee frontrunning is unprofitable**: Even if an attacker frontruns fee distributions by bonding immediately before `convertFees()` is called, they must wait 30 days to unbond
- **Auction frequency**: Fee flow auctions occur approximately every 7 days on average
- **Lock period >> auction period**: The 30-day lock period is ~4.3x longer than the auction frequency
- **Net negative for attackers**: Any gains from captured fees are outweighed by the capital lockup cost and exposure to the vault's risk during the 30-day period

### Exchange Rate Lock-in

When initiating unbond, the vault share amount is locked at that moment. Users do not benefit from fee distributions during the 30-day delay period. This design:
- Prevents gaming the system by timing unbonds
- Encourages long-term bonding for maximum fee capture (if fees are enabled)
- Ensures curators remain committed during their notice period
- Simplifies accounting and prevents race conditions

**Important**: If a user cancels the unbond, they re-enter at the current exchange rate, effectively resetting their position as if they had just bonded.

### Multi-Vault Support

The BondHolder contract supports multiple vaults simultaneously. Each vault maintains independent:
- Bond share accounting
- Unbond state tracking
- Exchange rate calculations
