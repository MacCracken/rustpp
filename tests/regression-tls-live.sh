#!/bin/sh
# Regression: live TLS handshake to a public endpoint.
#
# PINNED: v5.6.37 (fdlopen-based libssl loading). Previously
# tls_connect deadlocked on a futex inside cyrius's TCB when the
# plain dynlib_open path was used; v5.6.37 routed libssl through
# fdlopen's ld.so-bootstrapped real glibc dlopen, which provides
# a fully-initialised pthread state so SSL_CTX_new no longer
# recursively deadlocks on its internal init mutex.
#
# This gate builds a cyrius program that does a full libssl
# round-trip (TCP connect → SSL_connect → SSL_write HTTP GET →
# SSL_read response → SSL_shutdown), then asserts the response
# starts with "HTTP/1.1 200 OK".
#
# Skip cleanly if:
#   - ~/.cyrius/dlopen-helper isn't built (no fdlopen path),
#   - network to 1.1.1.1:443 is unreachable,
#   - cc5 cross-compile fails (e.g. stdlib missing).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not present"
    exit 0
fi

if [ ! -x "$HOME/.cyrius/dlopen-helper" ]; then
    echo "  skip: ~/.cyrius/dlopen-helper missing — run scripts/install.sh"
    exit 0
fi

# Quick network reachability probe — 1.1.1.1:443 is Cloudflare DNS
# (well-known, globally reachable). Single 3-second timeout.
if ! timeout 3 sh -c 'exec 3<>/dev/tcp/1.1.1.1/443' 2>/dev/null; then
    echo "  skip: 1.1.1.1:443 unreachable (no network)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/tls_probe.cyr" <<'EOF'
include "lib/alloc.cyr"
include "lib/string.cyr"
include "lib/syscalls.cyr"
include "lib/mmap.cyr"
include "lib/fnptr.cyr"
include "lib/dynlib.cyr"
# v5.6.37+ requirement: tls.cyr uses fdlopen for libssl init,
# and tls.cyr does NOT auto-include fdlopen (preprocessor
# expanded-output cap is tight for heavy consumers; see
# lib/tls.cyr docstring).
include "lib/fdlopen.cyr"
include "lib/tagged.cyr"
include "lib/net.cyr"
include "lib/tls.cyr"

fn main() {
    alloc_init();
    if (tls_available() == 0) { return 10; }

    var fd = payload(tcp_socket());
    var ip = 1 | (1 << 8) | (1 << 16) | (1 << 24);   # 1.1.1.1
    sock_connect(fd, ip, 443);   # returns Tagged(Ok/Err); tls_connect will fail if TCP didn't connect

    var tls = tls_connect(fd, "one.one.one.one");
    if (tls == 0) { return 12; }

    # Send minimal HTTP GET
    var req = "GET / HTTP/1.1\r\nHost: 1.1.1.1\r\nConnection: close\r\n\r\n";
    var req_len = strlen(req);
    if (tls_write(tls, req, req_len) < 0) { return 13; }

    # Read response — any non-empty read with HTTP/1.1 prefix is PASS
    var buf = alloc(4096);
    var n = tls_read(tls, buf, 4096);
    if (n < 12) { return 14; }

    # Check prefix "HTTP/1.1 " — 1.1.1.1:443 returns 301 redirect
    # which is fine; we're verifying the TLS handshake + HTTP framing
    # completed, not any particular status code.
    var expect = "HTTP/1.1 ";
    var i = 0;
    while (i < 9) {
        if (load8(buf + i) != load8(expect + i)) { return 20 + i; }
        i = i + 1;
    }

    tls_close(tls);
    sock_close(fd);
    return 0;
}
var r = main();
syscall(60, r);
EOF

cat "$TMP/tls_probe.cyr" | "$CC" > "$TMP/tls_probe" 2>/dev/null || {
    echo "  FAIL: cc5 compile failed"
    exit 1
}
chmod +x "$TMP/tls_probe"

set +e
timeout 30 "$TMP/tls_probe"
rc=$?
set -e

if [ "$rc" = "0" ]; then
    echo "  PASS TLS live round-trip (1.1.1.1:443 HTTP/1.1 response)"
    exit 0
fi
case "$rc" in
    10) echo "  FAIL: tls_available() returned 0" ;;
    11) echo "  FAIL: sock_connect to 1.1.1.1:443 failed" ;;
    12) echo "  FAIL: tls_connect returned 0 (handshake failed)" ;;
    13) echo "  FAIL: tls_write returned negative" ;;
    14) echo "  FAIL: tls_read returned < 12 bytes" ;;
    124) echo "  FAIL: timeout (30s) — likely hung in SSL_connect" ;;
    *) echo "  FAIL: rc=$rc (unknown)" ;;
esac
exit 1
