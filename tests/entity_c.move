#[test_only]
module bucket_framework::entity_c;

use sui::sui::{SUI};
use sui::balance::{Self, Balance};
use bucket_framework::sheet::{Self, Sheet, Loan, Request};

// Witness

public struct C has drop {}

public struct TreasuryC has key {
    id: UID,
    balance: Balance<SUI>,
    sheet: Sheet<SUI, C>,
}

fun init(ctx: &mut TxContext) {
    let treasury = TreasuryC {
        id: object::new(ctx),
        balance: balance::zero(),
        sheet: sheet::new(C {}),
    };
    transfer::share_object(treasury);
}

public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

public fun deposit(treasury: &mut TreasuryC, balance: Balance<SUI>) {
    treasury.balance.join(balance);
}

public fun add_debtor<Debtor>(treasury: &mut TreasuryC) {
    treasury.sheet.add_debtor(sheet::entity<Debtor>(), C {});
}

public fun add_creditor<Creditor>(treasury: &mut TreasuryC) {
    treasury.sheet.add_creditor(sheet::entity<Creditor>(), C {});
}

public fun lend<To>(
    treasury: &mut TreasuryC,
    amount: u64,
): Loan<SUI, C, To> {
    let out = treasury.balance.split(amount);
    treasury.sheet.lend(out, C {})
} 

public fun receive<From>(
    treasury: &mut TreasuryC,
    loan: Loan<SUI, From, C>
) {
    let balance = treasury.sheet.receive(loan, C {});
    treasury.balance.join(balance);
}

public fun pay<Collector>(
    treasury: &mut TreasuryC,
    collector: &mut Request<SUI, Collector>,
    amount: u64,
) {
    let repayment = treasury.balance.split(amount);
    treasury.sheet.pay(collector, repayment, C {});
}

public fun request(requirement: u64): Request<SUI, C> {
    sheet::request(requirement, C {})
}

public fun collect(treasury: &mut TreasuryC, collector: Request<SUI, C>) {
    let repayment = treasury.sheet.collect(collector, C {});
    treasury.balance.join(repayment);
}

public fun balance(treasury: &TreasuryC): u64 {
    treasury.balance.value()
}

public fun sheet(treasury: &TreasuryC): &Sheet<SUI, C> {
    &treasury.sheet
}
