# Struct-packing pattern for C FFI

When `fncallN` can't call a C function directly (struct-by-value
args, float args, variadic, >6 args on aarch64 — see
[`fncall-abi.md`](fncall-abi.md)), the canonical fix is a C shim
that accepts a packed-args struct by pointer. This doc shows the
pattern with real examples from mabda's `deps/wgpu_main.c`.

**Landed:** v5.4.13 (alongside `fncall7` / `fncall8`).

---

## The pattern

```
Cyrius side                   C shim side                   Real C API
───────────                   ───────────                   ──────────
build Args struct       →     accept Args*            →     call real fn with
call fncall2(                 unpack into locals            ABI-correct layout
    shim_fp,                  fill descriptor(s)
    subject,                  invoke the wgpu call
    &args)                    return any result
```

Cyrius always calls the shim via `fncall2(shim_fp, subject_handle,
&args)` — a two-argument call that's always in the safe zone
(scalars only, ≤ 6 args, no floats, no struct-by-value).

---

## Example 1 — `wgpu_shim_buffer_map` (5 args)

Original C API:

```c
void wgpuBufferMapAsync(
    WGPUBuffer buffer,
    WGPUMapMode mode,
    size_t offset,
    size_t size,
    WGPUBufferMapCallbackInfo cb   // struct-by-value → needs shim
);
```

Shim (`mabda/deps/wgpu_main.c:57-76`):

```c
typedef struct {
    WGPUBuffer buffer;
    uint32_t   mode;
    size_t     offset;
    size_t     size;
    long*      status_ptr;
} WgpuMapArgs;

void wgpu_shim_buffer_map(WGPUDevice device, WgpuMapArgs* args) {
    WGPUBufferMapCallbackInfo cb = {
        .mode = WGPUCallbackMode_AllowSpontaneous,
        .callback = c_on_buffer_mapped,
        .userdata1 = args->status_ptr,
    };
    wgpuBufferMapAsync(args->buffer, (WGPUMapMode)args->mode,
                       args->offset, args->size, cb);
    wgpuDevicePoll(device, true, NULL);
}
```

Cyrius caller (`mabda/src/wgpu_ffi.cyr`):

```cyrius
var args = alloc(40);                  # sizeof(WgpuMapArgs)
store64(args + 0,  buffer_handle);
store64(args + 8,  mode);
store64(args + 16, offset);
store64(args + 24, size);
store64(args + 32, &status);
fncall2(_fp(buffer_map_shim), device, args);
```

---

## Example 2 — `wgpu_shim_copy_buffer_to_buffer` (6 args)

Original C API takes 6 scalars — would be direct-callable if not
for the wgpu-specific reasons to consolidate shims. Packs into
`WgpuCopyArgs` for consistency with Example 1:

```c
typedef struct {
    WGPUBuffer src;
    uint64_t   src_off;
    WGPUBuffer dst;
    uint64_t   dst_off;
    uint64_t   size;
} WgpuCopyArgs;

void wgpu_shim_copy_buffer_to_buffer(
    WGPUCommandEncoder encoder, WgpuCopyArgs* args
) {
    wgpuCommandEncoderCopyBufferToBuffer(
        encoder, args->src, args->src_off,
        args->dst, args->dst_off, args->size
    );
}
```

Note: this case could use `fncall6` directly post-v5.4.13, but the
shim stays. Reason: consolidating all copy/buffer operations behind
one shim pattern gives mabda a single surface to instrument, audit,
and bench — and insulates from future ABI evolutions (if wgpu-native
adds a descriptor-struct version of this call, the cyrius side
doesn't change).

---

## Example 3 — nested-struct descriptor (the render-pass case)

Original C API:

```c
WGPURenderPassEncoder wgpuCommandEncoderBeginRenderPass(
    WGPUCommandEncoder encoder,
    const WGPURenderPassDescriptor* descriptor
);
```

The descriptor nests a `colorAttachments` array, a
`depthStencilAttachment` sub-struct, and a `timestampWrites`
sub-struct. Building that layout from cyrius would require nested
`alloc` + `store64` sequences that duplicate the C struct layout
and silently break on any wgpu version bump. The shim owns the
layout instead:

```c
typedef struct {
    void*       color_attachments;      // pointer to packed array
    long        color_attachment_count; // i64
    void*       depth_stencil;          // pointer or NULL
    void*       timestamp_writes;       // pointer or NULL
    const char* label;                  // cstr or NULL
} WgpuBeginPassArgs;

WGPURenderPassEncoder wgpu_shim_command_encoder_begin_render_pass(
    WGPUCommandEncoder enc, const WgpuBeginPassArgs* args
) {
    WGPURenderPassDescriptor desc = WGPU_RENDER_PASS_DESCRIPTOR_INIT;
    desc.colorAttachmentCount = args->color_attachment_count;
    desc.colorAttachments = args->color_attachments;
    desc.depthStencilAttachment = args->depth_stencil;
    desc.timestampWrites = args->timestamp_writes;
    if (args->label) {
        desc.label.data = args->label;
        desc.label.length = strlen(args->label);
    }
    return wgpuCommandEncoderBeginRenderPass(enc, &desc);
}
```

Cyrius builds the flat `WgpuBeginPassArgs` and passes `&args` via
`fncall2`. The shim owns all wgpu descriptor layout details.

---

## Design notes

### Layout

Keep the `SomethingArgs` struct layout **flat and stable**. Each
field is one 8-byte slot (pointer or i64 widened from smaller
types). Match cyrius's `store64(args + offset, value)` write
pattern. Don't mix widths or embed sub-structs — the shim unpacks
into the real descriptor.

### Lifetime

The `args` pointer is valid **only for the duration of the
`fncall2`**. If the real C API captures the pointer (e.g. async
callback that reads args later), the shim must copy data out of
`*args` before returning. All three examples above satisfy this:
`buffer_map` submits immediately, `copy_buffer_to_buffer` dispatches
synchronously, `begin_render_pass` builds the descriptor locally.

### Error handling

Shims should return an `int64_t` or pointer so cyrius can detect
failure. `void`-returning real APIs become `int wgpu_shim_X(…)`
returning 0 on success and negative on failure (matching cyrius's
syscall return convention). Callers then `assert_eq(r, 0, "…")`.

### Build integration

C shims live in `deps/NAME_main.c` alongside the vendored C deps.
`cyrius.cyml` `[build.c_deps]` (or the equivalent at the consumer
repo) names the C file; cyrius's build driver invokes the system
C compiler to produce an object that links into the final binary.
No changes needed at the cyrius-stdlib level.

---

## See also

- [`fncall-abi.md`](fncall-abi.md) — direct-vs-shim decision table.
- `lib/fnptr.cyr` — `fncallN` implementations + header comment.
- mabda `docs/issues/2026-04-19-fncall6-wgpu-crash-resolution.md`
  — the case study that surfaced this pattern as a policy.
- mabda `deps/wgpu_main.c` — reference implementation of 5+ shims.
