module clashofbots::mint {
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self as CoinMod, Coin};
    use aptos_framework::signer;
    use aptos_std::bcs;
    use aptos_std::hash;
    use clashofbots::{liquidity, storage};

    const E_PAYMENT_TOO_SMALL: u64 = 30;

    /// Mint a new bot with deterministic base traits. Payment must be exactly 10 APT.
    public entry fun mint_bot(account: &signer, mut payment: Coin<AptosCoin>) acquires storage::Registry, liquidity::LiquidityPool {
        storage::assert_initialized();
        liquidity::assert_initialized();

        let price = storage::MINT_PRICE;
        let paid = CoinMod::value(&payment);
        assert!(paid >= price, E_PAYMENT_TOO_SMALL);

        let locked = CoinMod::split(&mut payment, price);
        liquidity::lock(locked);
        refund_if_needed(account, payment);

        let owner = signer::address_of(account);
        let next_id = storage::preview_next_id();

        let aggression = derive_stat(owner, next_id, 3);
        let defense = derive_stat(owner, next_id, 7);
        let adaptability = derive_stat(owner, next_id, 11);
        let confidence = derive_stat(owner, next_id, 13);
        let speed = derive_stat(owner, next_id, 17);

        let _id = storage::create_bot(
            owner,
            aggression,
            defense,
            adaptability,
            confidence,
            speed,
            price,
        );
    }

    fun refund_if_needed(account: &signer, leftover: Coin<AptosCoin>) {
        if (CoinMod::value(&leftover) == 0) {
            CoinMod::destroy_zero(leftover);
        } else {
            CoinMod::deposit(account, leftover);
        }
    }

    /// Simple deterministic generator: baseline 30 with up to +39 variance.
    fun derive_stat(owner: address, id: u64, salt: u64): u64 {
        let payload = bcs::to_bytes(&(owner, id, salt));
        let hash_val = hash::sip_hash(payload);
        30 + (hash_val % 40)
    }
}
