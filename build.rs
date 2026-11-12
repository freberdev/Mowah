fn main() {
    println!("cargo:rerun-if-changed=res");
    // The icon, manifest, version info and dialog layout only exist in Windows builds.
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        embed_resource::compile("res/mowah.rc", embed_resource::NONE)
            .manifest_required()
            .expect("could not compile res/mowah.rc");
    }
}
