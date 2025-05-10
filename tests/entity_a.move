#[test_only]
module bucket_tools::entity_a;

use sui::sui::{SUI};
use sui::balance::{Self, Balance};
use bucket_tools::sheet::{Self, Entity, Sheet, Loan, Request};

// Witness

public struct A has drop {}

public struct TreasuryA has key {
    id: UID,
    balance: Balance<SUI>,
    sheet: Sheet<SUI, A>,
}

fun init(ctx: &mut TxContext) {
    let treasury = TreasuryA {
        id: object::new(ctx),
        balance: balance::zero(),
        sheet: sheet::new(A {}),
    };
    transfer::share_object(treasury);
}

public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

public fun deposit(treasury: &mut TreasuryA, balance: Balance<SUI>) {
    treasury.balance.join(balance);
}

public fun add_debtor<Debtor>(treasury: &mut TreasuryA) {
    treasury.sheet.add_debtor(sheet::entity<Debtor>(), A {});
}

public fun add_creditor<Creditor>(treasury: &mut TreasuryA) {
    treasury.sheet.add_creditor(sheet::entity<Creditor>(), A {});
}

public fun lend<To>(
    treasury: &mut TreasuryA,
    amount: u64,
): Loan<SUI, A, To> {
    let out = treasury.balance.split(amount);
    treasury.sheet.lend(out, A {})
} 

public fun receive<From>(
    treasury: &mut TreasuryA,
    loan: Loan<SUI, From, A>
) {
    let balance = treasury.sheet.receive(loan, A {});
    treasury.balance.join(balance);
}

public fun pay<Collector>(
    treasury: &mut TreasuryA,
    req: &mut Request<SUI, Collector>,
    amount: u64,
) {
    let repayment = treasury.balance.split(amount);
    treasury.sheet.pay(req, repayment, A {});
}

public fun request(
    treasury: &TreasuryA,
    requirement: u64,
    checklist: Option<vector<Entity>>,
): Request<SUI, A> {
    assert!(requirement <= treasury.sheet().total_credit());
    sheet::request(requirement, checklist, A {})
}

public fun collect(treasury: &mut TreasuryA, collector: Request<SUI, A>) {
    let repayment = treasury.sheet.collect(collector, A {});
    treasury.balance.join(repayment);
}

public fun ban<E>(treasury: &mut TreasuryA) {
    treasury.sheet.ban(sheet::entity<E>(), A {});
}

public fun unban<E>(treasury: &mut TreasuryA) {
    treasury.sheet.unban(sheet::entity<E>(), A {});
}

public fun balance(treasury: &TreasuryA): u64 {
    treasury.balance.value()
}

public fun sheet(treasury: &TreasuryA): &Sheet<SUI, A> {
    &treasury.sheet
}
