module clashofbots::randomness {
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_std::bcs;
    use aptos_std::hash;

    friend clashofbots::battle_engine;

    /// Roll a value in the range [0, 99] for post-battle evolution.
    public fun percent_roll(label_a: u64, label_b: u64): u64 {
        let payload = bcs::to_bytes(&(label_a, label_b, timestamp::now_seconds()));
        let digest = hash::sha3_256(payload);
        to_u64(&digest) % 100
    }

    fun to_u64(bytes: &vector<u8>): u64 {
        let mut out: u64 = 0;
        let mut i = 0;
        while (i < 8) {
            out = (out << 8) + (*vector::borrow(bytes, i) as u64);
            i = i + 1;
        };
        out
    }
}
