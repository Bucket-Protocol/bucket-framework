module bucket_tools::sheet;

/// Dependencies

use std::type_name::{get, TypeName};
use sui::balance::{Self, Balance};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use bucket_tools::liability::{Self, Credit, Debt};

/// Structs

public struct Entity(TypeName) has copy, drop, store;

public struct Sheet<phantom CoinType, phantom SelfEntity: drop> has store {
    credits: VecMap<Entity, Credit<CoinType>>,
    debts: VecMap<Entity, Debt<CoinType>>,
    blacklist: VecSet<Entity>,
}

// Hot potato

public struct Loan<phantom CoinType, phantom Lender, phantom Receiver> {
    balance: Balance<CoinType>,
    debt: Debt<CoinType>,
}

public struct Request<phantom CoinType, phantom Collector> {
    requirement: u64,
    balance: Balance<CoinType>,
    checklist: Option<vector<Entity>>,
    payor_debts: VecMap<Entity, Debt<CoinType>>,
}

// Errors

const EInvalidEntityForDebt: u64 = 0;
fun err_invalid_entity_for_debt() { abort EInvalidEntityForDebt }

const EInvalidEntityForCredit: u64 = 1;
fun err_invalid_entity_for_credit() { abort EInvalidEntityForCredit }

const EPayTooMuch: u64 = 2;
fun err_pay_too_much() { abort EPayTooMuch }

const EChecklistNotFulfill: u64 = 3;
fun err_checklist_not_fulfill() { abort EChecklistNotFulfill }

// Public Funs

public fun new<T, E: drop>(_: E): Sheet<T, E> {
    Sheet<T, E> {
        credits: vec_map::empty(),
        debts: vec_map::empty(),
        blacklist: vec_set::empty(),
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
    checklist: Option<vector<Entity>>,
    _collector_stamp: C,
): Request<T, C> {
    Request {
        requirement,
        balance: balance::zero(),
        checklist,
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
        err_pay_too_much();
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
    let Request { requirement: _, checklist, balance, mut payor_debts } = req;
    if (checklist.is_some() &&
        checklist.destroy_some() != payor_debts.keys()
    ) {
        err_checklist_not_fulfill();
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

public fun add_debtor<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    debtor: Entity,
    _stamp: E,
) {
    if (!sheet.credits().contains(&debtor)) {
        sheet.credits.insert(debtor, liability::zero_credit());
    };
}

public fun add_creditor<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    creditor: Entity,
    _stamp: E,
) {
    if (!sheet.debts().contains(&creditor)) {
        sheet.debts.insert(creditor, liability::zero_debt());
    };
}

public fun ban<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    entity: Entity,
    _stamp: E,
) {
    if (!sheet.blacklist.contains(&entity)) {
        sheet.blacklist.insert(entity);
    };
}

public fun unban<T, E: drop>(
    sheet: &mut Sheet<T, E>,
    entity: Entity,
    _stamp: E,
) {
    if (sheet.blacklist.contains(&entity)) {
        sheet.blacklist.remove(&entity);
    };   
}

// Getter Funs

public fun entity<E>(): Entity { Entity(get<E>()) }

public fun credits<T, E: drop>(sheet: &Sheet<T, E>): &VecMap<Entity, Credit<T>> {
    &sheet.credits
}

public fun debts<T, E: drop>(sheet: &Sheet<T, E>): &VecMap<Entity, Debt<T>> {
    &sheet.debts
}

public fun blacklist<T, E: drop>(sheet: &Sheet<T, E>): &VecSet<Entity> {
    &sheet.blacklist
}

public fun total_credit<T, E: drop>(sheet: &Sheet<T, E>): u64 {
    sheet.credits().keys().map_ref!(|e| sheet.credits().get(e).value()).fold!(0, |x, y| x + y)
}

public fun total_debt<T, E: drop>(sheet: &Sheet<T, E>): u64 {
    sheet.debts().keys().map_ref!(|e| sheet.debts().get(e).value()).fold!(0, |x, y| x + y)
}

public use fun loan_value as Loan.value;
public fun loan_value<T, C, D>(loan: &Loan<C, D, T>): u64 {
    loan.balance.value()
}

public fun requirement<T, C>(req: &Request<T, C>): u64 {
    req.requirement
}

public fun balance<T, C>(req: &Request<T, C>): u64 {
    req.balance.value()
}

public fun shortage<T, C>(req: &Request<T, C>): u64 {
    req.requirement() - req.balance()
}

public fun payor_debts<T, C>(req: &Request<T, C>): &VecMap<Entity, Debt<T>> {
    &req.payor_debts
}

// Internal Funs

fun debt_against<T, S: drop>(
    sheet: &mut Sheet<T, S>,
    entity: Entity,
): &mut Debt<T> {
    if (!sheet.debts().contains(&entity) ||
        sheet.blacklist().contains(&entity)
    ) {
        err_invalid_entity_for_debt();
    };
    sheet.debts.get_mut(&entity)
}

fun credit_against<T, S: drop>(
    sheet: &mut Sheet<T, S>,
    entity: Entity,
): &mut Credit<T> {
    if (!sheet.credits().contains(&entity) ||
        sheet.blacklist().contains(&entity)
    ) {
        err_invalid_entity_for_credit();
    };
    sheet.credits.get_mut(&entity)
}
