=== System ===
arm64
ProductName:		macOS
ProductVersion:		26.4.1
BuildVersion:		25E253

=== Binary ===
-rwxr-xr-x@ 1 macro  staff  379648 Apr 18 18:52 ./cc5_macho
./cc5_macho: Mach-O 64-bit executable arm64

./cc5_macho:
Mach header
      magic  cputype cpusubtype  caps    filetype ncmds sizeofcmds      flags
 0xfeedfacf 16777228          0  0x00           2    17        896 0x00200085

=== Codesign ===
Executable=/Users/macro/cc5_macho
Identifier=cc5_macho-55554944cafebabe050004008000000000000004
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=939 flags=0x2(adhoc) hashes=23+2 location=embedded
Hash type=sha256 size=32
CandidateCDHash sha256=1db89399e00ed21b5aef8cd1923ad9a4956ad6fa
CandidateCDHashFull sha256=1db89399e00ed21b5aef8cd1923ad9a4956ad6fa0bc54f4bdc52391ccde0807b
Hash choices=sha256
CMSDigest=1db89399e00ed21b5aef8cd1923ad9a4956ad6fa0bc54f4bdc52391ccde0807b
CMSDigestType=2
./cc5_macho: valid on disk
./cc5_macho: satisfies its Designated Requirement

=== Direct run ===
./mac-diagnose.sh: line 26: 18107 Illegal instruction: 4  "$CC5" < /dev/null > /tmp/cc5_stdout 2> /tmp/cc5_stderr
exit=132  (132=SIGILL, 137=SIGKILL, 139=SIGSEGV, 0=clean)
stdout bytes:        0
stderr:

=== Crash dump (if one landed) ===
total 224
-rw-------@ 1 macro  _analyticsusers   5120 Apr 18 19:03 cc5_macho-2026-04-18-190312.ips
-rw-------@ 1 macro  _analyticsusers   5120 Apr 18 18:58 cc5_macho-2026-04-18-185845.ips
--- /Users/macro/Library/Logs/DiagnosticReports/cc5_macho-2026-04-18-190312.ips ---
{"app_name":"cc5_macho","timestamp":"2026-04-18 19:03:12.00 -0700","app_version":"","slice_uuid":"cafebabe-0500-0400-8000-000000000004","build_version":"","platform":1,"share_with_app_devs":1,"is_first_party":1,"bug_type":"309","os_version":"macOS 26.4.1 (25E253)","roots_installed":0,"incident_id":"D20219B8-3E2C-44EB-A04B-E388F93462D4","name":"cc5_macho"}
{
  "uptime" : 34000,
  "procRole" : "Unspecified",
  "version" : 2,
  "userID" : 501,
  "deployVersion" : 210,
  "modelCode" : "Mac17,8",
  "coalitionID" : 721,
  "osVersion" : {
    "train" : "macOS 26.4.1",
    "build" : "25E253",
    "releaseType" : "User"
  },
  "captureTime" : "2026-04-18 19:03:12.6275 -0700",
  "codeSigningMonitor" : 2,
  "incident" : "D20219B8-3E2C-44EB-A04B-E388F93462D4",
  "pid" : 17869,
  "translated" : false,
  "cpuType" : "ARM-64",
  "procLaunch" : "2026-04-18 19:00:53.0142 -0700",
  "procStartAbsTime" : 826648530496,
  "procExitAbsTime" : 829998652054,
  "procName" : "cc5_macho",
  "procPath" : "\/Users\/USER\/cc5_macho",
  "parentProc" : "launchd",
  "parentPid" : 1,
  "coalitionName" : "com.mitchellh.ghostty",
  "crashReporterKey" : "B7F4A75D-C459-C9EF-FC6F-3011B1FE7054",
  "appleIntelligenceStatus" : {"state":"available"},
  "developerMode" : 1,
  "codeSigningID" : "cc5_macho-55554944cafebabe050004008000000000000004",
  "codeSigningTeamID" : "",
  "codeSigningFlags" : 838860833,
  "codeSigningValidationCategory" : 10,
  "codeSigningTrustLevel" : 4294967295,
  "codeSigningAuxiliaryInfo" : 0,
  "instructionByteStream" : {"beforePC":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==","atPC":"6ZZ8BABVSInlSIHsEAAAAEiJvfj\/\/\/9IibXw\/\/\/\/6QAAAABIi4X4\/w=="},
  "bootSessionUUID" : "32FB0D33-E43C-4D9A-8B8D-D57612BC035A",
  "wakeTime" : 3058,
  "sleepWakeUUID" : "1B910BDE-0A06-4CAA-A482-DBD8A2CA3F16",
  "sip" : "enabled",
  "exception" : {"codes":"0x0000000000000001, 0x00000000047c96e9","rawCodes":[1,75273961],"type":"EXC_BAD_INSTRUCTION","signal":"SIGILL"},
  "termination" : {"flags":0,"code":4,"namespace":"SIGNAL","indicator":"Illegal instruction: 4","byProc":"exc handler","byPid":17869},
  "extMods" : {"caller":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"system":{"thread_create":0,"thread_set_state":20,"task_for_pid":2},"targeted":{"thread_create":0,"thread_set_state":10,"task_for_pid":1},"warnings":1},
  "faultingThread" : 0,
  "threads" : [{"triggered":true,"id":406103,"threadState":{"x":[{"value":1},{"value":6171914920},{"value":6171914936},{"value":6171915272},{"value":1},{"value":32},{"value":99},{"value":0},{"value":4294983680},{"value":8305905312,"symbolLocation":3440,"symbol":"lsl::sPoolBytes"},{"value":6171911864},{"value":8306032944},{"value":131072},{"value":6494833088,"symbolLocation":0,"symbol":"_dyld_start"},{"value":1},{"value":85},{"value":6498887908,"symbolLocation":0,"symbol":"os_unfair_lock_unlock"},{"value":8332050824},{"value":0},{"value":8305901640,"symbolLocation":0,"symbol":"lsl::sMemoryManagerBuffer"},{"value":8305901808,"symbolLocation":0,"symbol":"lsl::sAllocatorBuffer"},{"value":6171913400},{"value":18446744073709551600},{"value":8308748704,"symbolLocation":0,"symbol":"vm_page_mask"},{"value":1},{"value":6171913760},{"value":8308748720,"symbolLocation":0,"symbol":"mach_task_self_"},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6494944676},"cpsr":{"value":1610614784},"fp":{"value":6171914880},"sp":{"value":6171913264},"esr":{"value":1979711490},"pc":{"value":4294983680,"matchesCrashFrame":1},"far":{"value":0}},"queue":"com.apple.main-thread","frames":[{"imageOffset":16384,"imageIndex":0}]}],
  "usedImages" : [
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4294967296,
    "size" : 327680,
    "uuid" : "cafebabe-0500-0400-8000-000000000004",
    "path" : "\/Users\/USER\/cc5_macho",
    "name" : "cc5_macho"
  },
  {
    "size" : 0,
    "source" : "A",

=== Done ===

================================================================
# Round 2 — post-fix test (v5.3.13+gate)
================================================================

After the x86-backend gate landed in `src/backend/x86/fixup.cyr`,
rebuilt cc5_macho with `CYRIUS_MACHO_ARM=1 build/cc5_aarch64 < src/main_aarch64_macho.cyr`.
User pulled the new 478144-byte binary to Apple Silicon, codesigned,
and re-ran `mac-selfhost.sh` with the watchdog.

## Result
```
cc5:    ./cc5_macho (  478144 bytes)
source: main_aarch64_macho.cyr (   13148 bytes)

=== Round 1: compile self ===
  cc5:  ./cc5_macho (  478144 bytes)
  src:  main_aarch64_macho.cyr (   13148 bytes)
  starting compile...
  [hung — watchdog killed after 30s]
```
- `cc5_macho_b` = 0 bytes (no stdout produced)
- `cc5_macho_b.err` = 0 bytes (no stderr produced)
- No SIGILL / SIGSEGV / SIGBUS — process just hung

## Interpretation

Binary starts, runs further than the arm64-wrapping-x86 version (no
SIGILL), but gets stuck somewhere post-mmap, pre-output. Since nothing
reached stderr and no output was emitted, it's in the startup / stdin-
read / lex / parse phase.

Likely suspects (ranked):
1. **stdin-read loop**: `while (n > 0)` reading from fd=0. If BSD
   `read` via raw SVC signals error via the carry flag (returns
   errno as a small positive in x0), our code interprets errno as
   "N bytes read" and never sees EOF. Would loop forever without
   reaching the parser.
2. **lex / parse infinite loop**: some token pattern in
   `main_aarch64_macho.cyr` that the emitter produces code for
   successfully on Linux but trips a Mach-O-ARM-specific bug.
3. **adrp page-diff overflow**: multi-page `__TEXT` at
   cc5_macho's size (~460KB) pushes some fixup past the 21-bit
   signed page-diff range, producing a wrap-around branch that
   loops back on itself.

## Next narrowing step

Run a **minimum-input smoke test** to isolate whether the hang is
in startup/read or in compilation-of-main_aarch64_macho.cyr:
```
echo 'syscall(60, 42);' | ./cc5_macho > /tmp/tiny.out
```
- If THAT completes (<1s) and produces a valid Mach-O → the hang
  is specific to compiling the 13KB main source (lex/parse loop bug).
- If THAT also hangs → cc5_macho's startup / read loop itself is
  broken on macOS. Most likely raw-SVC carry-flag mishandling.

Both cases are debuggable without hardware access by instrumenting
main_aarch64_macho.cyr to write progress markers to stderr at each
phase (after mmap, after read, after pass1, after pass2, after
FIXUP, before emit) and re-running the smoke test.
