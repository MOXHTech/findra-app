//! Regenerates `../src/lib/bindings.ts` without launching the GUI app -
//! `cargo run --bin export_bindings` from `src-tauri/`. Used in CI (frontend
//! typecheck/build needs the file to exist *before* the Rust binary is ever
//! run, which `tauri build`'s release path never does - see
//! `findra_app_lib::export_bindings`'s doc comment) and as the fresh-clone
//! bootstrap step before the first `npm run build`/`tauri dev`.
fn main() {
    findra_app_lib::export_bindings();
    println!("Wrote ../src/lib/bindings.ts");
}
