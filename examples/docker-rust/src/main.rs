// サンプル: 非同期ランタイム無しの最小 HTTP サーバ（実アプリに差し替える前提）。
// docker-node/server.ts を Rust + std TcpListener で写したもの。
// JSON 本文は serde / serde_json で組み立てる。
use std::env;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::process::exit;

use serde::Serialize;

/// `/healthz` が返すヘルスチェック応答。
#[derive(Serialize)]
struct Health {
    status: &'static str,
}

/// ヘルスチェック応答の JSON 本文（`{"status":"ok"}`）を組み立てる。
/// サーバ応答とヘルスチェック判定の両方から使うため切り出してテスト対象にする。
fn health_body() -> String {
    serde_json::to_string(&Health { status: "ok" }).expect("serialize health body")
}

/// `PORT` 環境変数（既定 3000）を解決する。
fn resolve_port() -> u16 {
    env::var("PORT")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(3000)
}

fn main() {
    // `healthcheck` 引数で起動された場合は HTTP で /healthz を叩いて疎通だけ確認する
    // （distroless にはシェルや curl が無いため、バイナリ自身を HEALTHCHECK に使う）。
    if env::args().nth(1).as_deref() == Some("healthcheck") {
        exit(run_healthcheck(resolve_port()));
    }
    serve(resolve_port());
}

/// TcpListener で待ち受け、`/healthz` には JSON を、それ以外には固定テキストを返す。
fn serve(port: u16) {
    let listener = TcpListener::bind(("0.0.0.0", port)).expect("bind listener");
    println!("listening on :{port}");
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => handle(stream),
            Err(e) => eprintln!("connection error: {e}"),
        }
    }
}

/// 1 接続を処理する。リクエストの 1 行目だけを見てパスで分岐する最小実装。
fn handle(mut stream: TcpStream) {
    let mut buf = [0u8; 1024];
    let n = stream.read(&mut buf).unwrap_or(0);
    let request = String::from_utf8_lossy(&buf[..n]);
    let path = request
        .lines()
        .next()
        .and_then(|line| line.split_whitespace().nth(1))
        .unwrap_or("/");
    let _ = stream.write_all(http_response(path).as_bytes());
}

/// パスに応じた HTTP 応答（ステータス行＋ヘッダ＋本文）を組み立てる。
/// `/healthz` は JSON、それ以外は固定テキストを返す。I/O を伴わないのでテスト対象にする。
fn http_response(path: &str) -> String {
    if path == "/healthz" {
        let body = health_body();
        format!(
            "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\n\r\n{}",
            body.len(),
            body
        )
    } else {
        let body = "Hello from the sample app\n";
        format!(
            "HTTP/1.1 200 OK\r\ncontent-type: text/plain; charset=utf-8\r\ncontent-length: {}\r\n\r\n{}",
            body.len(),
            body
        )
    }
}

/// `/healthz` に GET して 200 が返るかを確認する。成功 0 / 失敗 1 を終了コードで返す。
fn run_healthcheck(port: u16) -> i32 {
    let result = (|| -> std::io::Result<bool> {
        let mut stream = TcpStream::connect(("127.0.0.1", port))?;
        stream.write_all(b"GET /healthz HTTP/1.0\r\nHost: localhost\r\n\r\n")?;
        let mut resp = String::new();
        stream.read_to_string(&mut resp)?;
        Ok(resp.starts_with("HTTP/1.1 200"))
    })();
    match result {
        Ok(true) => 0,
        _ => 1,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn health_body_is_status_ok_json() {
        assert_eq!(health_body(), r#"{"status":"ok"}"#);
    }

    #[test]
    fn healthz_path_returns_json_body() {
        let resp = http_response("/healthz");
        assert!(resp.starts_with("HTTP/1.1 200 OK"));
        assert!(resp.contains("content-type: application/json"));
        assert!(resp.ends_with(r#"{"status":"ok"}"#));
    }

    #[test]
    fn other_path_returns_plain_text() {
        let resp = http_response("/");
        assert!(resp.contains("content-type: text/plain; charset=utf-8"));
        assert!(resp.ends_with("Hello from the sample app\n"));
        assert!(!resp.contains("application/json"));
    }
}
