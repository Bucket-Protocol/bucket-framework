#[test_only]
module bucket_framework::test_sheet;

use sui::balance;
use sui::sui::{SUI};
use sui::test_scenario::{Self as ts, Scenario};
use bucket_framework::sheet::{entity};
use bucket_framework::entity_a::{Self, A, TreasuryA};
use bucket_framework::entity_b::{Self, B, TreasuryB};
use bucket_framework::entity_c::{Self, C, TreasuryC};

public fun dummy(): address { @0xcafe }

public fun setup(): Scenario {
    let mut scenario = ts::begin(dummy());
    let s = &mut scenario;
    entity_a::init_for_testing(s.ctx());
    entity_b::init_for_testing(s.ctx());
    entity_c::init_for_testing(s.ctx());

    scenario
}

#[test]
fun test_sheet() {
    let mut scenario = setup();
    let s = &mut scenario;

    let a_init_amount = 2_000;
    let a_loan_amount = 1_342;
    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_a.deposit(balance::create_for_testing<SUI>(a_init_amount));
    treasury_a.add_debtor<B>();
    let loan = treasury_a.lend<B>(a_loan_amount);
    assert!(loan.value() == a_loan_amount);
    assert!(treasury_a.balance() == a_init_amount - a_loan_amount);
    assert!(treasury_a.sheet().credits().get(&entity<B>()).value() == a_loan_amount);
    treasury_b.add_creditor<A>();
    treasury_b.receive(loan);
    assert!(treasury_b.balance() == a_loan_amount);
    assert!(treasury_b.sheet().debts().get(&entity<A>()).value() == a_loan_amount);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    let b_init_amount = 3_000;
    let b_loan_amount = 2_456;
    s.next_tx(dummy());
    let mut treasury_c = s.take_shared<TreasuryC>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_c.deposit(balance::create_for_testing<SUI>(b_init_amount));
    treasury_c.add_debtor<B>();
    let loan = treasury_c.lend<B>(b_loan_amount);
    assert!(loan.value() == b_loan_amount);
    assert!(treasury_c.balance() == b_init_amount - b_loan_amount);
    assert!(treasury_c.sheet().credits().get(&entity<B>()).value() == b_loan_amount);
    treasury_b.add_creditor<C>();
    treasury_b.receive(loan);
    assert!(treasury_b.balance() == a_loan_amount + b_loan_amount);
    assert!(treasury_b.sheet().debts().get(&entity<C>()).value() == b_loan_amount);
    ts::return_shared(treasury_c);
    ts::return_shared(treasury_b);

    scenario.end();
}