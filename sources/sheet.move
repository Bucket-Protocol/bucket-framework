module bucket_framework::sheet;

/// Dependencies

use std::type_name::{get, TypeName};
use sui::balance::{Self, Balance};
use sui::vec_map::{Self, VecMap};
use bucket_framework::liability::{Self, Credit, Debt};

/// Structs

public struct Entity(TypeName) has copy, drop, store;

public struct Sheet<phantom CoinType, phantom SelfEntity: drop> has store {
    credits: VecMap<Entity, Credit<CoinType>>,
    debts: VecMap<Entity, Debt<CoinType>>,
}

// Hot potato

public struct Loan<phantom CoinType, phantom Lender, phantom Receiver> {
    balance: Balance<CoinType>,
    debt: Debt<CoinType>,
}

public struct Request<phantom CoinType, phantom Collector> {
    requirement: u64,
    balance: Balance<CoinType>,
    payor_debts: VecMap<Entity, Debt<CoinType>>,
}

// Errors

const EInvalidEntity: u64 = 0;
fun err_invalid_entity() { abort EInvalidEntity }

const ENotEnoughRepayment: u64 = 2;
fun err_not_enough_repayment() { abort ENotEnoughRepayment }

const ERepayTooMuch: u64 = 3;
fun err_repay_too_much() { abort ERepayTooMuch }

// Public Funs

public fun new<T, E: drop>(_: E): Sheet<T, E> {
    Sheet<T, E> {
        credits: vec_map::empty(),
        debts: vec_map::empty(),
    }
}

public fun lend<T, L: drop, R>(
    sheet: &mut Sheet<T, L>,
    balance: Balance<T>,
    _lender_stamp: L,
): Loan<T, L, R> {
    // create credit and debt
    let balance_value = balance.value();
    let (credit, debt) = liability::new(balance_value);
    
    // record the credit against the receiver
    let receiver = entity<R>();
    sheet.credit_against(receiver).add(credit);

    // output loan including debt
    Loan { balance, debt }
}

public fun receive<T, L, R: drop>(
    sheet: &mut Sheet<T, R>,
    loan: Loan<T, L, R>,
    _receiver_stamp: R,
): Balance<T> {
    // get balance and debt in loan
    let Loan { balance, debt } = loan;

    // record
    let lender = entity<L>();
    sheet.debt_against(lender).add(debt);
    
    // out balance
    balance
}

public fun request<T, C: drop>(
    requirement: u64,
    _collector_stamp: C,
): Request<T, C> {
    Request {
        requirement,
        balance: balance::zero(),
        payor_debts: vec_map::empty(),
    }
}

public fun pay<T, C, P: drop>(
    sheet: &mut Sheet<T, P>,
    req: &mut Request<T, C>,
    balance: Balance<T>,
    _payor_stamp: P,
) {
    let balance_value = balance.value();
    if (balance_value > req.shortage()) {
        err_repay_too_much();
    };
    req.balance.join(balance);
    let (credit, debt) = liability::new(balance_value);
    let collector = entity<C>();
    let credit_opt = sheet.debt_against(collector).settle(credit);
    if (credit_opt.is_some()) {
        sheet.credit_against(collector).add(credit_opt.destroy_some());
    } else {
        credit_opt.destroy_none();
    };
    let payor = entity<P>();
    if (req.payor_debts().contains(&payor)) {
        req.payor_debts.get_mut(&payor).add(debt);
    } else {
        req.payor_debts.insert(payor, debt);
    };
}

public fun collect<T, C: drop>(
    sheet: &mut Sheet<T, C>,
    req: Request<T, C>,
    _stamp: C,
): Balance<T> {
    let Request { requirement, balance, mut payor_debts } = req;
    if (requirement != balance.value()) {
        err_not_enough_repayment();
    };
    while (!payor_debts.is_empty()) {
        let (payor, debt) = payor_debts.pop();
        let debt_opt = sheet.credit_against(payor).settle(debt);
        if (debt_opt.is_some()) {
            sheet.debt_against(payor).add(debt_opt.destroy_some());
        } else {
            debt_opt.destroy_none();
        };
    };
    payor_debts.destroy_empty();
    balance
}

public fun entity<E>(): Entity { Entity(get<E>()) }

public fun add_debtor<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    debtor: Entity,
    _stamp: E,
) {
    if (!sheet.credits().contains(&debtor)) {
        let (zero_credit, zero_debt) = liability::new(0);
        zero_debt.destroy_zero();
        sheet.credits.insert(debtor, zero_credit);    
    };
}

public fun add_creditor<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    creditor: Entity,
    _stamp: E,
) {
    if (!sheet.debts().contains(&creditor)) {
        let (zero_credit, zero_debt) = liability::new(0);
        zero_credit.destroy_zero();
        sheet.debts.insert(creditor, zero_debt);
    };
}

public fun remove_debtor<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    debtor: Entity,
    _stamp: E,
): Credit<T> {
    if (!sheet.credits.contains(&debtor)) {
        err_invalid_entity();
    };
    let (_, credit) = sheet.credits.remove(&debtor);
    credit
}

public fun remove_creditor<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    creditor: Entity,
    _stamp: E,
): Debt<T> {
    if (!sheet.debts.contains(&creditor)) {
        err_invalid_entity();
    };
    let (_, debt) = sheet.debts.remove(&creditor);
    debt
}

// Getter Funs

public fun credits<T, E: drop>(sheet: &Sheet<T, E>): &VecMap<Entity, Credit<T>> {
    &sheet.credits
}

public fun debts<T, E: drop>(sheet: &Sheet<T, E>): &VecMap<Entity, Debt<T>> {
    &sheet.debts
}

public use fun loan_value as Loan.value;
public fun loan_value<T, C, D>(loan: &Loan<C, D, T>): u64 {
    loan.balance.value()
}

public fun requirement<T, C>(req: &Request<T, C>): u64 {
    req.requirement
}

public fun repayment<T, C>(req: &Request<T, C>): u64 {
    req.balance.value()
}

public fun shortage<T, C>(req: &Request<T, C>): u64 {
    req.requirement() - req.repayment()
}

public fun payor_debts<T, C>(req: &Request<T, C>): &VecMap<Entity, Debt<T>> {
    &req.payor_debts
}

// Internal Funs

fun debt_against<T, S: drop>(
    sheet: &mut Sheet<T, S>,
    entity: Entity,
): &mut Debt<T> {
    if (!sheet.debts().contains(&entity)) {
        err_invalid_entity();
    };
    sheet.debts.get_mut(&entity)
}

fun credit_against<T, S: drop>(
    sheet: &mut Sheet<T, S>,
    entity: Entity,
): &mut Credit<T> {
    if (!sheet.credits().contains(&entity)) {
        err_invalid_entity();
    };
    sheet.credits.get_mut(&entity)
}
