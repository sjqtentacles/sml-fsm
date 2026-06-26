# sml-fsm

Finite state machine and behavior tree for game AI in pure Standard ML

## Installation

```
smlpkg add github.com/sjqtentacles/sml-fsm
smlpkg sync
```

## Usage

### Finite state machine

States are equality-typed values (strings here for simplicity). The transition
function returns `NONE` to mean "no transition, stay put".

```sml
fun trafficTransition st ev =
  case (st, ev) of
      ("Red",    "go")   => SOME "Green"
    | ("Green",  "slow") => SOME "Yellow"
    | ("Yellow", "stop") => SOME "Red"
    | _                  => NONE

val light  = FSM.make ["Red", "Green", "Yellow"] "Red" trafficTransition
val green  = FSM.send light "go"        (* current = "Green" *)
val stayed = FSM.send light "stop"      (* no rule -> stays "Red" *)

val isRed  = FSM.inState light "Red"    (* true *)
```

The machine also tracks its declared state set and visit history, and answers
guard questions without transitioning:

```sml
FSM.canSend light "go"                   (* true  — would transition *)
FSM.canSend light "stop"                 (* false — no rule from Red *)
FSM.states light                         (* ["Red","Green","Yellow"] *)

val cycled = FSM.sendAll light ["go","slow","stop"]
FSM.current cycled                       (* "Red" *)
FSM.history cycled                       (* ["Red","Green","Yellow","Red"] *)

(* Export a Graphviz diagram (current state drawn double-circled) *)
val dot = FSM.toDot (fn s => s) light    (* "digraph fsm { ... }" *)
```

#### Data-driven machines (`makeTable`)

When you build the machine from an explicit transition table, the library can
introspect it — render full edge diagrams, compute reachability, and validate
the table. (A function-backed `make` machine cannot be introspected, so these
operations treat it as edgeless.)

```sml
val light =
  FSM.makeTable ["Red","Green","Yellow"] "Red"
    [ ("Red",    "go",   "Green")
    , ("Green",  "slow", "Yellow")
    , ("Yellow", "stop", "Red") ]

FSM.reachableStates light          (* ["Red","Green","Yellow"] from current *)
FSM.validate light                 (* [] — every edge endpoint is declared *)
val dot = FSM.toDotFull (fn s => s) (fn e => e) light  (* nodes AND labelled edges *)
```

#### History, reset, rewind, recognizers

```sml
val walked = FSM.sendAll light ["go","slow"]   (* Red -> Green -> Yellow *)
FSM.reset walked                                (* back to "Red", history = ["Red"] *)
valOf (FSM.rewind walked)                       (* step back to "Green" *)
FSM.setHistoryLimit light 2                     (* keep only the 2 most recent states *)

(* Treat the FSM as a recognizer over an accepting-state set. *)
FSM.accepts walked ["Yellow"]                   (* true *)
FSM.run light ["go","slow","stop"] ["Red"]      (* run word from start, accept? -> true *)
```

#### Mealy machines (`MealyFSM`)

A separate structure for machines that emit an output on each transition (kept
apart so `FSM`'s type and `send` are unchanged):

```sml
fun trans st ev =
  case (st, ev) of
      ("Idle", "coin")     => SOME ("Paid", "thanks")
    | ("Paid", "dispense") => SOME ("Idle", "drink")
    | _ => NONE

val m = MealyFSM.make ["Idle","Paid"] "Idle" trans
val (m', out) = MealyFSM.step m "coin"          (* state "Paid", out = SOME "thanks" *)
MealyFSM.outputs m ["coin","dispense"]          (* ["thanks","drink"] *)
```

### Behavior tree

`tick` evaluates a tree against a context and returns `Success`, `Failure`, or
`Running`. `sequence` returns the first non-`Success`; `selector` returns the
first non-`Failure`; `invert` swaps `Success`/`Failure`; `repeat n` ticks `n`
times and fails on the first `Failure`.

Additional composites and decorators:

- `parallel n ts` ticks every child and succeeds when at least `n` of them
  return `Success` (`Running` if the threshold is unmet but a child is running).
- `succeeder t` / `failer t` force the result to `Success` / `Failure` (unless
  the child is `Running`).
- `repeatUntilSuccess n t` retries `t` up to `n` times, stopping at the first
  `Success`.
- `cooldown getTime lastFire period t` ticks `t` only once at least `period`
  has elapsed since `lastFire`, otherwise returns `Failure`. `timeout getTime
  startTime limit t` returns `Failure` once the elapsed time from `startTime`
  exceeds `limit`. Because `tick` is stateless, both read the current time from
  the context via a `getTime` accessor (e.g. a clock field on the context).

```sml
open BehaviorTree

fun enemyInRange (ctx: {inRange: bool, log: string ref}) = #inRange ctx
val attack = action (fn ctx => (#log ctx := "attack"; Success))
val patrol = action (fn ctx => (#log ctx := "patrol"; Success))

val aiTree = selector [ sequence [condition enemyInRange, attack], patrol ]

val log = ref ""
val r   = tick aiTree {inRange = true, log = log}  (* Success; log = "attack" *)

(* succeed if any 2 of 3 sub-behaviors succeed *)
val any2 = parallel 2 [scanLeft, scanRight, scanAhead]
```

## Scope and limitations

- FSM states and events use SML equality types; states must be comparable with
  `=` (so no function-typed states). For a `make` machine the transition
  function is the single source of truth — `toDot` renders declared *nodes* but
  not edges (it cannot enumerate every event). Use `makeTable` when you want
  `toDotFull`/`reachableStates`/`validate`, which operate over the explicit
  table; on a function-backed machine they behave as if there were no edges.
- `history` grows unbounded by default; call `setHistoryLimit` to cap it in
  long-running loops. No-op events (transition returns `NONE`) are not recorded.
  `rewind` steps back over recorded *states* only — events are not stored.
- `MealyFSM` is a separate structure from `FSM`; its `step` returns the new
  machine plus an optional emitted output.
- Behavior-tree `tick` is a single synchronous evaluation; `Running` is reported
  but there is no built-in scheduler/blackboard — the caller drives re-ticking
  and owns all mutable context. `cooldown`/`timeout` are stateless and read the
  clock from the context, so the caller must supply the current time.
- Everything is pure/allocation-light and single-threaded; concurrency is out of
  scope.

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
```

## License

MIT
