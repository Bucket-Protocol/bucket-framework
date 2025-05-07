#[test_only]
module bucket_framework::entity_b;

use sui::sui::{SUI};
use sui::balance::{Self, Balance};
use bucket_framework::sheet::{Self, Sheet, Loan, Request};

// Witness

public struct B has drop {}

public struct TreasuryB has key {
    id: UID,
    balance: Balance<SUI>,
    sheet: Sheet<SUI, B>,
}

fun init(ctx: &mut TxContext) {
    let treasury = TreasuryB {
        id: object::new(ctx),
        balance: balance::zero(),
        sheet: sheet::new(B {}),
    };
    transfer::share_object(treasury);
}

public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

public fun deposit(treasury: &mut TreasuryB, balance: Balance<SUI>) {
    treasury.balance.join(balance);
}

public fun add_debtor<Debtor>(treasury: &mut TreasuryB) {
    treasury.sheet.add_debtor(sheet::entity<Debtor>(), B {});
}

public fun add_creditor<Creditor>(treasury: &mut TreasuryB) {
    treasury.sheet.add_creditor(sheet::entity<Creditor>(), B {});
}

public fun lend<To>(
    treasury: &mut TreasuryB,
    amount: u64,
): Loan<SUI, B, To> {
    let out = treasury.balance.split(amount);
    treasury.sheet.lend(out, B {})
} 

public fun receive<From>(
    treasury: &mut TreasuryB,
    loan: Loan<SUI, From, B>
) {
    let balance = treasury.sheet.receive(loan, B {});
    treasury.balance.join(balance);
}

public fun pay<Collector>(
    treasury: &mut TreasuryB,
    req: &mut Request<SUI, Collector>,
    amount: u64,
) {
    let repayment = treasury.balance.split(amount);
    treasury.sheet.pay(req, repayment, B {});
}

public fun request(treasury: &TreasuryB, requirement: u64): Request<SUI, B> {
    assert!(requirement <= treasury.sheet().total_credit());
    sheet::request(requirement, B {})
}

public fun collect(treasury: &mut TreasuryB, collector: Request<SUI, B>) {
    let repayment = treasury.sheet.collect(collector, B {});
    treasury.balance.join(repayment);
}

public fun ban<E>(treasury: &mut TreasuryB) {
    treasury.sheet.ban(sheet::entity<E>(), B {});
}

public fun unban<E>(treasury: &mut TreasuryB) {
    treasury.sheet.unban(sheet::entity<E>(), B {});
}

public fun balance(treasury: &TreasuryB): u64 {
    treasury.balance.value()
}

public fun sheet(treasury: &TreasuryB): &Sheet<SUI, B> {
    &treasury.sheet
}
