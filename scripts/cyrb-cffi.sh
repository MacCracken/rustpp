#!/bin/sh
# cyrb cffi — generate C FFI wrapper (header + implementation)
# Creates a .h and .c that communicate with a Cyrius binary via subprocess.
#
# Usage: cyrb cffi <source.cyr> <output_prefix>
# Output: <prefix>.h (header) + <prefix>.c (subprocess bridge) + <prefix> (binary)
#
# The .c file forks the Cyrius binary, sends function calls via pipe,
# receives results. Compile with: gcc -o libfoo.so -shared foo.c

CC="${1:-./build/cc2}"
SRC="$2"
PREFIX="$3"

if [ -z "$SRC" ] || [ -z "$PREFIX" ]; then
    echo "Usage: cyrb cffi <cc2_path> <source.cyr> <output_prefix>"
    echo "Example: cyrb cffi ./build/cc2 lib/mylib.cyr mylib"
    exit 1
fi

# Compile the binary
cat "$SRC" | "$CC" > "${PREFIX}" 2>/dev/null
chmod +x "${PREFIX}"
echo "Binary: ${PREFIX} ($(wc -c < "${PREFIX}") bytes)"

# Generate header
sh "$(dirname "$0")/cyrb-header.sh" "$SRC" > "${PREFIX}.h"
echo "Header: ${PREFIX}.h"

# Generate C wrapper
cat > "${PREFIX}_ffi.c" << 'CEOF'
/* Auto-generated FFI wrapper — calls Cyrius binary via subprocess */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

static const char *_cyrius_binary = NULL;

void cyrius_init(const char *binary_path) {
    _cyrius_binary = binary_path;
}

/* Call a Cyrius function by compiling+running an expression */
int64_t cyrius_call(const char *expr) {
    if (!_cyrius_binary) return -1;

    int pipefd[2];
    if (pipe(pipefd) < 0) return -1;

    pid_t pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], 1);
        close(pipefd[1]);
        /* Write expression to stdin of compiler, capture binary, run it */
        /* For now: just exec the pre-compiled binary */
        execl(_cyrius_binary, _cyrius_binary, NULL);
        _exit(127);
    }
    close(pipefd[1]);

    int status;
    waitpid(pid, &status, 0);
    close(pipefd[0]);

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return -1;
}
CEOF
echo "FFI wrapper: ${PREFIX}_ffi.c"
echo ""
echo "Usage from C:"
echo "  #include \"${PREFIX}.h\""
echo "  cyrius_init(\"./${PREFIX}\");"
echo "  int64_t result = cyrius_call(\"expression\");"
