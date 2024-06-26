// Copyright (c) PDX, Inc.
// SPDX-License-Identifier: Apache-2.0

module lumiwave::vote {
    use std::vector;
    use sui::vec_map::{Self, VecMap};
    use std::string::{utf8, String};
    use sui::object::{Self, UID};
    use sui::tx_context::{TxContext};
    use sui::clock::{Self};
    use sui::url::{Self, Url};

    friend lumiwave::LWA;

    // Vote status information
    struct VoteStatus has store, copy, drop {
        enable: bool,           // Whether voting is enabled
        start_ts: u64,          // Start time of voting (ms)
        end_ts: u64,            // End time of voting (ms)
        min_voting_count: u64,  // minimum number of voters
        passing_threshold: u64, // the percentage of votes cast in favor of
    }

    // Participant information for voting
    struct Participant has store, copy, drop {
        addr: address,  // Voter's wallet address
        ts: u64,        // Timestamp of voting participation
        is_agree: bool, // Agreement, disagreement
    }

    // NFT for confirming voting participation
    struct VotingEvidence has key, store {
        id: UID,
        name: String,
        description: String,
        project_url: Url,
        image_url: Url,
        creator: String,
        is_agree: bool,
    }

    public(friend) fun empty_status(): VoteStatus{
        VoteStatus{
            enable: false, 
            start_ts: 0,
            end_ts: 0,
            min_voting_count: 0,
            passing_threshold : 0,
        }
    }

    public(friend) fun empty_participants() :VecMap<address, Participant> {
        vec_map::empty<address, Participant>()
    } 

    // Create voting confirmation NFT
    public(friend) fun make_VotingEvidence(ctx: &mut TxContext, is_agree: bool): VotingEvidence {
        VotingEvidence{
            id: object::new(ctx),
            name: utf8(b"minting vote"),
            description: utf8(b""),
            project_url: url::new_unsafe_from_bytes(b"https://lumiwavelab.com/"),
            image_url: url::new_unsafe_from_bytes( b"https://innofile.blob.core.windows.net/inno/live/icon/LUMIWAVE_Primary_black.png"),
            creator: utf8(b""),
            is_agree,
        }
    }

    // === Public-View Functions ===
    public fun voting_evidence_detail(voting_evidence: &VotingEvidence): (String, String, Url, Url, String, bool) {
        (voting_evidence.name, voting_evidence.description, voting_evidence.project_url, voting_evidence.image_url, voting_evidence.creator, voting_evidence.is_agree)
    }


    // Check if voting is enabled
    public(friend) fun is_votestatus_enable(vote_status: &VoteStatus): bool {  
        vote_status.enable
    } 

    // Check voting participation
    public(friend) fun is_voted(participants: &VecMap<address, Participant>, participant: address): bool{
       vec_map::contains<address, Participant>(participants, &participant)
    }

    // Details of voters
    public fun participant(participant: &Participant): (address, u64, bool) {
        (participant.addr, participant.ts, participant.is_agree)
    }

    // Check voting period
    public(friend) fun votestatus_period_check(vote_status: &VoteStatus, clock_vote: &clock::Clock): bool {
        let cur_ts = clock::timestamp_ms(clock_vote);
        if (cur_ts >= vote_status.start_ts && cur_ts <= vote_status.end_ts ) {
            true
        }else{
            false
        }
    }

    // Check if voting is countable
    public(friend) fun votestatus_countable(vote_status: &VoteStatus, participants: &VecMap<address, Participant>, clock_vote: &clock::Clock): (bool, bool) {
        // Check if the voting end time has passed, and if the total number of voters is over 'min_voting_count'
        ( vote_status.end_ts < clock::timestamp_ms(clock_vote), vec_map::size(participants) >= vote_status.min_voting_count )
    }

    // Check voting results
    #[allow(unused_assignment)]
    public(friend) fun vote_counting(participants: &VecMap<address, Participant>, vote_status: &VoteStatus,): (u64, u64, u64, bool) {
        let (_, participants) = vec_map::into_keys_values(*participants);
        let i: u64 = 0;
        let agree_cnt : u64 = 0;
        let disagree_cnt: u64 = 0;
        while( i < vector::length(&participants)) {
            let participant = vector::borrow(&participants, i);
            if ( participant.is_agree == true ) {
                agree_cnt = agree_cnt + 1;
            }else{
                disagree_cnt = disagree_cnt + 1;
            };
            i = i + 1;
        };

        let result: bool = false;
        if ( agree_cnt * 100 / i < vote_status.passing_threshold ) { // Need more than 'passing_threshold'(%) for agreement
            // Opposition passed
            result = false;
        }else{
            // Agreement passed
            result = true;
        };

        (agree_cnt, disagree_cnt, i, result)  // Number of agreements, number of disagreements, total number of voters, voting result
    }

    // === Public-Mutative Functions ===
    // Participate in voting
    public(friend) fun voting(participants: &mut VecMap<address, Participant>, participant: address, clock_vote: &clock::Clock, is_agree: bool) {
        let newParticipant = Participant{
            addr: participant,
            ts: clock::timestamp_ms(clock_vote),
            is_agree,
        };
        vec_map::insert<address, Participant>(participants, participant, newParticipant);
    }

    // Enable voting
    public(friend) fun votestatus_enable(vote_status: &mut VoteStatus, enable: bool, vote_start_ts: u64, vote_end_ts: u64, 
                    min_voting_count:u64, passing_threshold: u64) {  
        vote_status.enable = enable;
        vote_status.start_ts = vote_start_ts;
        vote_status.end_ts = vote_end_ts;
        vote_status.min_voting_count = min_voting_count;
        vote_status.passing_threshold = passing_threshold;
    } 
}