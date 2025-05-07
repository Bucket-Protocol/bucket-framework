#[test_only]
module bucket_framework::test_sheet;

use sui::balance;
use sui::sui::{SUI};
use sui::test_scenario::{Self as ts, Scenario};
use bucket_framework::sheet::{entity};
use bucket_framework::entity_a::{Self, A, TreasuryA};
use bucket_framework::entity_b::{Self, B, TreasuryB};
use bucket_framework::entity_c::{Self, C, TreasuryC};
use bucket_framework::sheet;

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

    // A loan to B
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
    assert!(treasury_a.sheet().total_credit() == a_loan_amount);
    assert!(treasury_a.sheet().total_debt() == 0);
    treasury_b.add_creditor<A>();
    treasury_b.receive(loan);
    assert!(treasury_b.balance() == a_loan_amount);
    assert!(treasury_b.sheet().debts().get(&entity<A>()).value() == a_loan_amount);
    assert!(treasury_b.sheet().total_credit() == 0);
    assert!(treasury_b.sheet().total_debt() == a_loan_amount);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    // C loan to B
    let c_init_amount = 3_000;
    let c_loan_amount = 2_456;
    s.next_tx(dummy());
    let mut treasury_c = s.take_shared<TreasuryC>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_c.deposit(balance::create_for_testing<SUI>(c_init_amount));
    treasury_c.add_debtor<B>();
    let loan = treasury_c.lend<B>(c_loan_amount);
    assert!(loan.value() == c_loan_amount);
    assert!(treasury_c.balance() == c_init_amount - c_loan_amount);
    assert!(treasury_c.sheet().credits().get(&entity<B>()).value() == c_loan_amount);
    assert!(treasury_c.sheet().total_credit() == c_loan_amount);
    assert!(treasury_c.sheet().total_debt() == 0);
    treasury_b.add_creditor<C>();
    treasury_b.ban<C>();
    treasury_b.unban<C>();
    treasury_b.unban<C>();
    treasury_b.receive(loan);
    assert!(treasury_b.balance() == a_loan_amount + c_loan_amount);
    assert!(treasury_b.sheet().debts().get(&entity<C>()).value() == c_loan_amount);
    assert!(treasury_b.sheet().total_credit() == 0);
    assert!(treasury_b.sheet().total_debt() == a_loan_amount + c_loan_amount);
    ts::return_shared(treasury_c);
    ts::return_shared(treasury_b);

    // A collect from B, C
    let b_pay_amount = 600;
    let c_pay_amount = 400;
    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    let mut treasury_c = s.take_shared<TreasuryC>();
    
    treasury_a.add_debtor<C>();
    treasury_a.add_debtor<C>();
    treasury_a.add_creditor<C>();
    treasury_a.add_creditor<C>();
    treasury_c.add_debtor<A>();
    treasury_c.add_creditor<A>();

    let mut request = treasury_a.request(b_pay_amount + c_pay_amount);
    treasury_b.pay(&mut request, b_pay_amount);
    treasury_c.pay(&mut request, c_pay_amount / 4);
    treasury_c.pay(&mut request, c_pay_amount * 3 / 4);
    treasury_a.collect(request);

    assert!(treasury_a.balance() == a_init_amount - a_loan_amount + b_pay_amount + c_pay_amount);
    let sheet_a = treasury_a.sheet();
    assert!(sheet_a.total_credit() == a_loan_amount - b_pay_amount);
    assert!(sheet_a.total_debt() == c_pay_amount);
    assert!(sheet_a.credits().get(&entity<B>()).value() == a_loan_amount - b_pay_amount);
    assert!(sheet_a.debts().get(&entity<C>()).value() == c_pay_amount);

    assert!(treasury_b.balance() == a_loan_amount + c_loan_amount - b_pay_amount);
    let sheet_b = treasury_b.sheet();
    assert!(sheet_b.total_credit() == 0);
    assert!(sheet_b.total_debt() == a_loan_amount + c_loan_amount - b_pay_amount);
    assert!(sheet_b.debts().get(&entity<A>()).value() == a_loan_amount - b_pay_amount);
    assert!(sheet_b.debts().get(&entity<C>()).value() == c_loan_amount);

    assert!(treasury_c.balance() == c_init_amount - c_loan_amount - c_pay_amount);
    let sheet_c = treasury_c.sheet();
    assert!(sheet_c.total_credit() == c_loan_amount + c_pay_amount);
    assert!(sheet_c.total_debt() == 0);
    assert!(sheet_c.credits().get(&entity<A>()).value() == c_pay_amount);
    assert!(sheet_c.credits().get(&entity<B>()).value() == c_loan_amount);

    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);
    ts::return_shared(treasury_c);

    scenario.end();
}

#[test, expected_failure(abort_code = sheet::EInvalidEntityForCredit)]
fun test_invalid_debtor() {
    let mut scenario = setup();
    let s = &mut scenario;

    // A loan to B
    let a_init_amount = 2_000;
    let a_loan_amount = 1_342;
    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_a.deposit(balance::create_for_testing<SUI>(a_init_amount));
    // treasury_a.add_debtor<B>();
    let loan = treasury_a.lend<B>(a_loan_amount);
    treasury_b.add_creditor<A>();
    treasury_b.receive(loan);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    scenario.end();
}

#[test, expected_failure(abort_code = sheet::EInvalidEntityForDebt)]
fun test_invalid_creditor() {
    let mut scenario = setup();
    let s = &mut scenario;

    // A loan to B
    let a_init_amount = 2_000;
    let a_loan_amount = 1_342;
    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_a.deposit(balance::create_for_testing<SUI>(a_init_amount));
    treasury_a.add_debtor<B>();
    let loan = treasury_a.lend<B>(a_loan_amount);
    // treasury_b.add_creditor<A>();
    treasury_b.receive(loan);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    scenario.end();
}

#[test, expected_failure(abort_code = sheet::EPayTooMuch)]
fun test_pay_too_much() {
    let mut scenario = setup();
    let s = &mut scenario;

    // A loan to B
    let a_init_amount = 2_000;
    let a_loan_amount = 1_342;
    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_a.deposit(balance::create_for_testing<SUI>(a_init_amount));
    treasury_a.add_debtor<B>();
    let loan = treasury_a.lend<B>(a_loan_amount);
    treasury_b.add_creditor<A>();
    treasury_b.receive(loan);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    let mut request = treasury_a.request(a_loan_amount / 2);
    treasury_b.pay(&mut request, a_loan_amount);
    treasury_a.collect(request);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    scenario.end();
}

#[test, expected_failure(abort_code = sheet::EInvalidEntityForCredit)]
fun test_blacklist_debtor() {
    let mut scenario = setup();
    let s = &mut scenario;

    // A loan to B
    let a_init_amount = 2_000;
    let a_loan_amount = 1_342;
    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_a.deposit(balance::create_for_testing<SUI>(a_init_amount));
    treasury_a.add_debtor<B>();
    treasury_a.ban<B>();
    treasury_a.ban<B>();
    let loan = treasury_a.lend<B>(a_loan_amount);
    treasury_b.add_creditor<A>();
    treasury_b.receive(loan);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    scenario.end();
}

#[test, expected_failure(abort_code = sheet::EInvalidEntityForDebt)]
fun test_blacklist_creditor() {
    let mut scenario = setup();
    let s = &mut scenario;

    // A loan to B
    let a_init_amount = 2_000;
    let a_loan_amount = 1_342;
    s.next_tx(dummy());
    let mut treasury_a = s.take_shared<TreasuryA>();
    let mut treasury_b = s.take_shared<TreasuryB>();
    treasury_a.deposit(balance::create_for_testing<SUI>(a_init_amount));
    treasury_a.add_debtor<B>();
    let loan = treasury_a.lend<B>(a_loan_amount);
    treasury_b.add_creditor<A>();
    treasury_b.ban<A>();
    treasury_b.ban<A>();
    treasury_b.receive(loan);
    ts::return_shared(treasury_a);
    ts::return_shared(treasury_b);

    scenario.end();
}
