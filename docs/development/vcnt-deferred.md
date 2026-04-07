# Deferred Due to VCNT Limit (Fixed in v1.7.0)

**Status:** VCNT expanded to 2048 in v1.7.0. These items can now be restored.

Items were stripped from the agnostik Cyrius port to fit within the original 512 variable table limit.
With VCNT at 2048, all enums below can be restored to their full typed forms.

## Enum Variants Removed (~100 slots)

### LinuxCapability — 39 variants
Currently: use raw integers 0–38.
Restore: `enum LinuxCapability { CAP_CHOWN; CAP_DAC_OVERRIDE; ... CAP_PERFMON; }`

### SeccompArch — 17 variants
Currently: use raw integers 0–16.
Restore: `enum SeccompArch { ARCH_X86; ARCH_X86_64; ... ARCH_RISCV64; }`

### LandlockFsAccess — 15 variants
Currently: use raw integers 0–14.
Restore: `enum LandlockFsAccess { LL_EXECUTE; LL_WRITE_FILE; ... LL_TRUNCATE; }`

### SeccompArgOp — 7 variants
Currently: use raw integers 0–6.
Restore: `enum SeccompArgOp { ARG_NOT_EQUAL; ... ARG_MASKED_EQUAL; }`

### ConditionOperator — 8 variants
Currently: use raw integers 0–7.
Restore: `enum ConditionOperator { COND_EQ; ... COND_LTE; }`

### RlimitType — 10 variants
Currently: use raw integers 0–9.
Restore: `enum RlimitType { RLIM_NOFILE; ... RLIM_MSGQUEUE; }`

### DeviceType — 3 variants
Currently: use raw integers 0–2.
Restore: `enum DeviceType { DEV_CHAR; DEV_BLOCK; DEV_ALL; }`

### SystemFeature — 6 variants
Currently: use raw integers 0–5.
Restore: `enum SystemFeature { FEAT_LANDLOCK; ... FEAT_SECURE_BOOT; }`

### LandlockNetAccess — 2 variants
Currently: use raw integers 0–1.
Restore: `enum LandlockNetAccess { LL_BIND_TCP; LL_CONNECT_TCP; }`

### PiiKind — 16 variants (classification)
Currently: `var PII_EMAIL = 0; var PII_SSN = 2;` (only 2 of 16 as named constants).
Restore: full `enum PiiKind { PII_EMAIL; PII_PHONE; ... PII_CUSTOM; }`

### MemoryType — 12 variants (hardware)
Currently: use raw integers 0–11.
Restore: `enum MemoryType { MEM_GDDR5; ... MEM_UNKNOWN; }`

### DeviceVendor — 9 variants (hardware)
Currently: `var VENDOR_NVIDIA = 0;` (only 1 named constant).
Restore: full `enum DeviceVendor { VENDOR_NVIDIA; ... VENDOR_CUSTOM; }`

### DeviceHealth — 4 variants (hardware)
Currently: `var HEALTH_OK = 0;` (only 1 named constant).
Restore: full `enum DeviceHealth { HEALTH_OK; HEALTH_DEGRADED; HEALTH_FAILED; HEALTH_UNKNOWN; }`

### LlmProvider — 7 variants removed
Currently: 6 variants (OLLAMA, OPENAI, ANTHROPIC, GOOGLE, DEEPSEEK, CUSTOM).
Restore: LLAMA_CPP, MISTRAL, GROK, GROQ, OPENROUTER, LMSTUDIO, LOCALAI (13 total).

### ContentBlockType — 3 variants removed
Currently: 5 variants (TEXT, IMAGE, TOOL_USE, TOOL_RESULT, THINKING).
Restore: DOCUMENT, AUDIO, CITATION (8 total).

### StreamEventType — 8 variants
Currently: removed entirely (use tagged unions with raw integers).
Restore: `enum StreamEventType { STREAM_CONTENT_BLOCK_START; ... STREAM_PING; }`

## Accessor Functions Removed (~20 functions)

Various getter/setter functions were trimmed to reduce local variable pressure.
These are mechanical to restore — add back the one-liner accessor patterns.

## Total VCNT Recovery

Restoring all deferred enums adds ~160 variable slots.
Current usage: ~486 of 512. Needs VCNT ≥ 650 or per-function scoping.
