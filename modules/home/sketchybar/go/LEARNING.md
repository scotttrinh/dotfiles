# Go learning map

A running record of what we've covered while porting `../config/plugins/*.sh` to this Go CLI. Read this at the start of a session; update it at the end.

## Learner profile

- First real Go project.
- Strong in TypeScript and typed Python; has dabbled in Haskell, OCaml, and Rust. Use those as reference points (structural typing, `Result`, newtypes) rather than explaining static typing from scratch.
- Skeptical of the single-`package main` layout; expects to refactor into packages.

## How we work

- Port one shell plugin at a time, keeping behavior identical to the shell version unless we decide otherwise.
- Pull logic into pure functions and test them; keep `exec`/I/O at the edges.
- Short quizzes to check understanding; record corrected misconceptions below.

## Covered

Confidence: **solid** = explained correctly in a quiz; **seen** = used in code, not yet checked or only partly understood.

| Topic | Where | Confidence |
|---|---|---|
| Module path, `go.mod`, `package main` across files | `go.mod`, all files | solid |
| `main`, `os.Args`, `os.Exit` codes (2 usage, 1 runtime) | `main.go` | solid |
| `os.Getenv` | `main.go` | seen |
| `var` vs `:=`, zero values | `main.go` | seen (zero value of `error` was new) |
| `switch` on strings | `main.go` | seen |
| Multiple returns, `(T, error)`, `if err != nil` | `probe.go`, `clock.go` | solid |
| `fmt.Sprintf`, `Fprintln(os.Stderr)`, `%q` | throughout | seen |
| `os/exec`: `Command`, wiring Stdout/Stderr, `Run` | `probe.go`, `clock.go` | solid |
| `time.Format` reference-time layouts | `clock.go` | solid |
| `time.Duration` as a named `int64`, typed constants | `clock.go` | seen (see misconceptions) |
| String slicing `s[:2]` | `clock.go` | seen |
| `max` builtin (Go 1.21+) | `clock.go` | seen |
| Exported vs unexported identifiers (capitalization) | `clock_test.go` | solid |
| Tests: `testing.T`, `t.Fatalf`, got/want | `clock_test.go` | solid |
| Fuzzing: `testing.F`, `f.Add`, `f.Fuzz`, property checks | `clock_test.go` | seen (see misconceptions) |
| Pure functions / injecting `time.Time` for testability | `clock.go` | solid |
| `go run` / `build` / `test`, `buildGoModule`, `vendorHash`, dev vs Nix binary | `README.md`, `package.nix` | seen |

## Misconceptions corrected

- **Zero value of `error`**: it's `nil`. `error` is an interface (`interface{ Error() string }`), and all interfaces zero to `nil`. Interfaces are satisfied structurally, like TS. Future topic: a typed nil pointer inside an interface is not `== nil`.
- **`int(d / time.Hour)` truncation**: the truncation happens in the division (`Duration / Duration` is integer division on `int64` nanoseconds). `int(...)` is only a type conversion; Go has no implicit numeric conversions. Adding half a unit before dividing turns truncation into rounding.
- **Fuzz range in `FuzzIntervalMinuteProgression`**: the property "adding a minute changes the label" only holds in the minutes range. Below 30s the result clamps to `1 minute`; at 3600s and above, labels are whole hours, so 61m and 62m both print `1h`. An unbounded `uint64` could also overflow `Duration`. The bounds encode where the property is true.
- **`package main_test`**: an external test package can't import `package main` at all, which is one concrete reason to move logic into importable packages.

## Loose ends in the code

- `formatInterval` lacks the shell's `> 12h` → `Nd` branch.
- `runClock` hardcodes item `"clock"` instead of using `name`.
- `clock` command exists but isn't wired into `../config/sketchybarrc` or `../default.nix`.
- `README.md` still says only `probe` exists.
- The five `formatInterval` tests are copy-paste; candidate for a table-driven test.

## Not yet covered

- Structs, methods, pointers vs values
- Slices (beyond string slicing), maps, `for` loops, `range`
- Table-driven tests and `t.Run` subtests
- Error wrapping: `fmt.Errorf("%w")`, `errors.Is`, `errors.As`
- File I/O (`os.ReadFile`/`WriteFile`), `strings`/`strconv` parsing
- `encoding/json` with struct tags
- `context` and timeouts for subprocesses
- Splitting into packages (`internal/...`)
- Goroutines and channels

## Next up

Continue porting `clock.sh`, roughly in this order:

1. Convert the interval tests to a table-driven test (slices of structs, `for range`, `t.Run`), then add the `Nd` branch test-first.
2. Title truncation (`truncate_title`): strings vs bytes vs runes, since titles can contain `…` and non-ASCII.
3. The event cache: a struct for the event, read/write `$TMPDIR/sketchybar-next-event.cache`, parse with `strings`/`strconv`, error wrapping.
4. Calling `acal` with a timeout via `context`, decoding its JSON into structs.
5. Wire `clock` into `sketchybarrc`/`default.nix`, retire `clock.sh`.

## Session log

- **Session 1** (commit `50829a1`): module setup, Nix packaging, `probe` command, `clock` formatting + tests + fuzzing.
- **Session 2** (2026-09-29): assessment quiz; created this map.
