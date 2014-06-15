#![feature(globs)]
#![allow(unused_attribute)]

// Extracts lib/crate dependencies from rustc JSON AST output
extern crate serialize;
extern crate collections;

use serialize::json;
use std::io::stdio;
use jlens::{Selector,JsonExt,descend,at,wherein,and};

pub mod jlens;

fn main() {
    let json = json::from_reader(&mut stdio::stdin()).unwrap();
    // Extract names of all crate dependencies (extern crate foo)
    // and library link dependencies (#[link(name="foo")])
    let matches = json.query(
        descend().key("node").union(
            wherein(at(0).string().equals("ViewItemExternCrate")).at(1),
            wherein(and(at(0).string().equals("MetaList"),
                      at(1).string().equals("link")))
                .at(2).child().key("node")
                .wherein(and(at(0).string().equals("MetaNameValue"),
                           at(1).string().equals("name")))
                .at(2).key("node")
                .wherein(at(0).string().equals("LitStr"))
                .at(1)).string());

    for &m in matches.iter() {
        match m {
            &json::String(ref s) => println!("{}", s),
            _ => fail!("Impossible")
        }
    }
}
