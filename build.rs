fn main() {
    println!("cargo:rerun-if-changed=assets/deck-shelf.ico");

    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        let mut resource = winres::WindowsResource::new();
        resource
            .set_icon("assets/deck-shelf.ico")
            .set("FileDescription", "Deck Shelf")
            .set("ProductName", "Deck Shelf")
            .set("OriginalFilename", "Deck Shelf.exe");
        resource
            .compile()
            .expect("failed to compile Windows resources");
    }
}
