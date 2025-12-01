module clashofbots::leaderboard {
    use std::vector;
    use clashofbots::storage;

    const LEADERBOARD_SIZE: u64 = 5;

    struct Rank has copy, drop, store {
        id: u64,
        value: u64,
    }

    /// Top 5 bots sorted by total wins.
    public fun top_by_wins(): vector<u64> acquires storage::Registry {
        build_leaderboard(true)
    }

    /// Top 5 bots sorted by liquidity.
    public fun top_by_liquidity(): vector<u64> acquires storage::Registry {
        build_leaderboard(false)
    }

    fun build_leaderboard(by_wins: bool): vector<u64> acquires storage::Registry {
        storage::assert_initialized();
        let ids = storage::all_bot_ids();
        let mut ranks = vector::empty<Rank>();
        let mut i = 0;
        let len = vector::length(&ids);
        while (i < len) {
            let id = *vector::borrow(&ids, i);
            let bot = storage::get_bot(id);
            let metric = if (by_wins) { bot.wins } else { bot.liquidity };
            insert_rank(&mut ranks, Rank { id, value: metric });
            i = i + 1;
        };
        ranks_to_ids(&ranks)
    }

    fun insert_rank(ranks: &mut vector<Rank>, entry: Rank) {
        vector::push_back(ranks, entry);
        let mut idx = vector::length(ranks);
        while (idx > 1) {
            let right = idx - 1;
            let left = right - 1;
            let left_ref = vector::borrow(ranks, left);
            let right_ref = vector::borrow(ranks, right);
            if (left_ref.value >= right_ref.value) {
                break;
            };
            vector::swap(ranks, left, right);
            idx = idx - 1;
        };
        if (vector::length(ranks) > LEADERBOARD_SIZE) {
            let _ = vector::pop_back(ranks);
        };
    }

    fun ranks_to_ids(ranks: &vector<Rank>): vector<u64> {
        let mut ids = vector::empty<u64>();
        let len = vector::length(ranks);
        let mut i = 0;
        while (i < len) {
            let rank_ref = vector::borrow(ranks, i);
            vector::push_back(&mut ids, rank_ref.id);
            i = i + 1;
        };
        ids
    }
}
