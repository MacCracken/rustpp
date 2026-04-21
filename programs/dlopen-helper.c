/*
 * dlopen-helper.c — foreign-dlopen bridge for lib/fdlopen.cyr
 *
 * Compiled at install time by scripts/install.sh into
 * ~/.cyrius/dlopen-helper. Linked against the host glibc so ld.so
 * brings up the full libc state normally when our static cyrius
 * binary mmap's this helper + ld-linux.so.2 and jumps to ld.so's
 * ELF entry point with a constructed startup stack.
 *
 * Protocol with the cyrius side (see lib/fdlopen.cyr):
 *   - argv[1] is the hex-encoded 64-bit address of the fdlopen
 *     state buffer inside the static cyrius binary's address space.
 *   - argv[2] is the hex-encoded 64-bit address of the callback
 *     function the cyrius side wants invoked once we've populated
 *     the state buffer with fn pointers.
 *
 * We resolve a fixed set of symbols (dlopen, dlsym, dlclose, dlerror,
 * getaddrinfo, freeaddrinfo, gai_strerror, strerror, setlocale,
 * setenv, unsetenv) from the live glibc, stuff the pointers into
 * the state buffer at the offsets lib/fdlopen.cyr documents, then
 * invoke the callback. The callback is expected to longjmp back
 * into the cyrius setjmp frame — it does not return to us.
 *
 * This file is intentionally tiny and dependency-free (only libdl +
 * libc). Keep it that way — each added dep is another potential
 * ABI break across distros.
 *
 * Copyright (C) 2026 Robert MacCracken
 * GPL-3.0-only
 */

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void (*fdlopen_cb_t)(void);

/* State buffer slot offsets — must match lib/fdlopen.cyr FdlopenOff */
#define FDL_DLOPEN          128
#define FDL_DLSYM           136
#define FDL_DLCLOSE         144
#define FDL_DLERROR         152
#define FDL_GETADDRINFO     160
#define FDL_FREEADDRINFO    168
#define FDL_GAI_STRERROR    176
#define FDL_STRERROR        184
#define FDL_SETLOCALE       192
#define FDL_SETENV          200
#define FDL_UNSETENV        208

static unsigned long parse_hex(const char *s) {
    unsigned long v = 0;
    if (!s) return 0;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
    while (*s) {
        char c = *s++;
        unsigned d;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
        else return v;
        v = (v << 4) | d;
    }
    return v;
}

static void store_ptr(unsigned char *base, unsigned long off, void *p) {
    memcpy(base + off, &p, sizeof(p));
}

int main(int argc, char **argv, char **envp) {
    if (argc < 3) {
        fprintf(stderr, "dlopen-helper: expected 2 args (state_addr, callback_addr)\n");
        return 2;
    }
    unsigned long state_addr = parse_hex(argv[1]);
    unsigned long cb_addr    = parse_hex(argv[2]);
    if (!state_addr || !cb_addr) {
        fprintf(stderr, "dlopen-helper: zero state or callback addr\n");
        return 3;
    }

    /* Open libc via the already-running ld.so. RTLD_DEFAULT works
     * because libc is already loaded as part of our own link. */
    void *libc = dlopen("libc.so.6", RTLD_NOW | RTLD_GLOBAL);
    if (!libc) libc = RTLD_DEFAULT;

    unsigned char *state = (unsigned char *)state_addr;

    /* Populate the state buffer with real fn pointers */
    store_ptr(state, FDL_DLOPEN,       (void *)dlopen);
    store_ptr(state, FDL_DLSYM,        (void *)dlsym);
    store_ptr(state, FDL_DLCLOSE,      (void *)dlclose);
    store_ptr(state, FDL_DLERROR,      (void *)dlerror);
    store_ptr(state, FDL_GETADDRINFO,  dlsym(libc, "getaddrinfo"));
    store_ptr(state, FDL_FREEADDRINFO, dlsym(libc, "freeaddrinfo"));
    store_ptr(state, FDL_GAI_STRERROR, dlsym(libc, "gai_strerror"));
    store_ptr(state, FDL_STRERROR,     dlsym(libc, "strerror"));
    store_ptr(state, FDL_SETLOCALE,    dlsym(libc, "setlocale"));
    store_ptr(state, FDL_SETENV,       dlsym(libc, "setenv"));
    store_ptr(state, FDL_UNSETENV,     dlsym(libc, "unsetenv"));

    /* Invoke the cyrius-side callback. It is expected to longjmp
     * back to the setjmp frame that dispatched us — this call
     * does NOT return to the helper. */
    fdlopen_cb_t cb = (fdlopen_cb_t)cb_addr;
    cb();

    /* Unreachable on success. If the callback returned (no longjmp),
     * exit cleanly so the process doesn't linger. */
    return 0;
}
