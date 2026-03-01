use std::time::SystemTime;

fn main() {
    let now = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .expect("Time went backwards")
        .as_secs();
    
    println!("{"status": "ok", "timestamp": {}, "engine": "wasm"}", now);
}
