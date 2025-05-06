module bucket_framework::account;

/// Dependencies

use std::string::String;
use sui::transfer::{Receiving};

/// OTW

public struct ACCOUNT has drop {}

/// Object

public struct Account has key, store {
    id: UID,
    alias: Option<String>,
}

/// Struct

public struct AccountRequest has drop {
    account: address,
}

/// Init

fun init(otw: ACCOUNT, ctx: &mut TxContext) {
    sui::package::claim_and_keep(otw, ctx);
}

/// Public Funs

public fun new(
    alias: Option<String>,
    ctx: &mut TxContext,
): Account {
    Account {
        id: object::new(ctx),
        alias,
    }
}

public fun request(ctx: &TxContext): AccountRequest {
    AccountRequest { account: ctx.sender() }
}

public use fun request_with_account as Account.request;
public fun request_with_account(accout: &Account): AccountRequest {
    AccountRequest { account: object::id(accout).to_address() }
}

public fun receive<T: key + store>(
    account: &mut Account,
    receiving: Receiving<T>,
): T {
    transfer::public_receive(&mut account.id, receiving)
}

/// Getter Funs

public use fun account_address as Account.address;
public fun account_address(account: &Account): address {
    account.id.to_address()
}

public use fun request_address as AccountRequest.address;
public fun request_address(req: &AccountRequest): address {
    req.account
}

#[test]
fun test_account_request() {
    use sui::test_scenario::{Self as ts};
    use sui::package::{Publisher};
    let dev = @0xde1;
    let mut scenario = ts::begin(dev);
    let s = &mut scenario;
    init(ACCOUNT {}, s.ctx());

    s.next_tx(dev);
    let publisher = s.take_from_sender<Publisher>();
    assert!(publisher.from_module<ACCOUNT>());
    assert!(publisher.from_module<Account>());
    assert!(publisher.from_module<AccountRequest>());
    s.return_to_sender(publisher);

    let sender = @0x123;
    s.next_tx(sender);
    let account = new(option::none(), s.ctx());
    let account_id = object::id(&account);
    transfer::public_transfer(account, sender);
    let acc_req = request(s.ctx());
    assert!(acc_req.address() == sender);

    s.next_tx(sender);
    let account = s.take_from_sender<Account>();
    assert!(account.address() == account_id.to_address());
    s.return_to_sender(account);

    scenario.end();
}
