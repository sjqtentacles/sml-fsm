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
  `=` (so no function-typed states). The transition function is the single
  source of truth — `toDot` renders declared *nodes* but not edges (it has no
  way to enumerate every event).
- `history` grows unbounded as events are sent; trim it in long-running loops if
  memory matters. No-op events (transition returns `NONE`) are not recorded.
- Behavior-tree `tick` is a single synchronous evaluation; `Running` is reported
  but there is no built-in scheduler/blackboard — the caller drives re-ticking
  and owns all mutable context.
- Everything is pure/allocation-light and single-threaded; concurrency is out of
  scope.

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
```

## License

MIT
