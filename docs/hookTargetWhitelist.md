# HookTargetWhitelist

The `HookTargetWhitelist` contract allows to whitelist addresses that are allowed to call specific functions, identified by their selector.
On deployment the `DEFAULT_ADMIN_ROLE` is assigned to the `admin` address, addresses with this role can allow specific addresses to call specific functions or all of them by assigning the role which corresponds with the specific function selector or the `WILD_CARD_SELECTOR` to allow all functions to be called by that address.