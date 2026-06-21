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

### Behavior tree

`tick` evaluates a tree against a context and returns `Success`, `Failure`, or
`Running`. `sequence` returns the first non-`Success`; `selector` returns the
first non-`Failure`; `invert` swaps `Success`/`Failure`; `repeat n` ticks `n`
times and fails on the first `Failure`.

```sml
open BehaviorTree

fun enemyInRange (ctx: {inRange: bool, log: string ref}) = #inRange ctx
val attack = action (fn ctx => (#log ctx := "attack"; Success))
val patrol = action (fn ctx => (#log ctx := "patrol"; Success))

val aiTree = selector [ sequence [condition enemyInRange, attack], patrol ]

val log = ref ""
val r   = tick aiTree {inRange = true, log = log}  (* Success; log = "attack" *)
```

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
```

## License

MIT
