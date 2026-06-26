signature FSM =
sig
  type ('s, 'e) t

  (* Function-backed constructor: transitions are an opaque function. *)
  val make      : ''s list -> ''s -> (''s -> 'e -> ''s option) -> (''s, 'e) t

  (* Data-driven constructor: transitions are a table of (from, event, to)
     triples. Forces an equality event type so events can be matched. The
     table representation enables introspection (toDotFull/reachableStates/
     validate) that the opaque function form cannot provide. *)
  val makeTable : ''s list -> ''s -> (''s * ''e * ''s) list -> (''s, ''e) t

  val current   : (''s, 'e) t -> ''s
  val send      : (''s, 'e) t -> 'e -> (''s, 'e) t   (* NONE guard -> stay *)
  val inState   : (''s, 'e) t -> ''s -> bool
  val canSend   : (''s, 'e) t -> 'e -> bool          (* would the event cause a transition? *)
  val states    : (''s, 'e) t -> ''s list            (* declared state set *)
  val sendAll   : (''s, 'e) t -> 'e list -> (''s, 'e) t
  val history   : (''s, 'e) t -> ''s list            (* visited states, oldest first *)
  val toDot     : (''s -> string) -> (''s, 'e) t -> string  (* Graphviz of declared states + current *)

  (* History bound. Default is unbounded; a bound of n keeps the most recent n
     visited states (n <= 0 means unbounded). Returns a new machine. *)
  val setHistoryLimit : (''s, 'e) t -> int -> (''s, 'e) t

  (* Return to the initial state (first entry of history), keeping the machine's
     transitions; history is reset to just that state. *)
  val reset     : (''s, 'e) t -> (''s, 'e) t
  (* Step back to the previous state in history (state-only; events are not
     stored). NONE if already at the initial state. *)
  val rewind    : (''s, 'e) t -> (''s, 'e) t option

  (* Recognizer helpers over an accepting-state set. accepts checks the current
     state; run feeds events from the initial state and reports acceptance. *)
  val accepts   : (''s, 'e) t -> ''s list -> bool
  val run       : (''s, 'e) t -> 'e list -> ''s list -> bool

  (* Table-only introspection. These require a machine built with makeTable;
     a function-backed machine has no inspectable table, so they treat it as
     having no edges. *)
  val toDotFull      : (''s -> string) -> (''e -> string) -> (''s, ''e) t -> string
  val reachableStates : (''s, ''e) t -> ''s list   (* reachable from current via the table *)
  (* validate returns the list of problems: table edges whose endpoints are not
     in the declared state set. Empty list means the table is well-formed. *)
  val validate       : (''s, ''e) t -> string list
end

signature MEALY_FSM =
sig
  (* A Mealy machine: each transition emits an output. Kept separate from FSM
     so FSM's type and send stay unchanged. *)
  type ('s, 'e, 'out) t
  val make    : ''s list -> ''s -> (''s -> 'e -> (''s * 'out) option) -> (''s, 'e, 'out) t
  val current : (''s, 'e, 'out) t -> ''s
  (* step returns the new machine and the emitted output (NONE if no transition). *)
  val step    : (''s, 'e, 'out) t -> 'e -> (''s, 'e, 'out) t * 'out option
  val run     : (''s, 'e, 'out) t -> 'e list -> (''s, 'e, 'out) t * 'out list
  val outputs : (''s, 'e, 'out) t -> 'e list -> 'out list
  val states  : (''s, 'e, 'out) t -> ''s list
end

signature BEHAVIOR_TREE =
sig
  type 'ctx tree
  datatype result = Success | Failure | Running
  val action    : ('ctx -> result) -> 'ctx tree
  val condition : ('ctx -> bool)   -> 'ctx tree
  val sequence  : 'ctx tree list   -> 'ctx tree
  val selector  : 'ctx tree list   -> 'ctx tree
  val invert    : 'ctx tree        -> 'ctx tree
  val repeat    : int              -> 'ctx tree -> 'ctx tree
  val parallel  : int              -> 'ctx tree list -> 'ctx tree (* succeeds when >= n children succeed *)
  val succeeder : 'ctx tree        -> 'ctx tree   (* Success unless Running *)
  val failer    : 'ctx tree        -> 'ctx tree   (* Failure unless Running *)
  val repeatUntilSuccess : int     -> 'ctx tree -> 'ctx tree (* up to n attempts *)
  (* Time-gated decorators. Since tick is stateless, elapsed time must be read
     from the context via a getTime accessor (e.g. a clock field on 'ctx).
     cooldown getTime period child: ticks the child only if at least `period`
     has elapsed since the provided last-fire time; otherwise Failure.
     timeout getTime startTime limit child: Failure once the elapsed time from
     startTime exceeds `limit`, else ticks the child.
     Times are plain reals (e.g. seconds); the accessor decides the unit. *)
  val cooldown  : ('ctx -> real) -> real -> real -> 'ctx tree -> 'ctx tree
                  (* getTime, lastFire, period, child *)
  val timeout   : ('ctx -> real) -> real -> real -> 'ctx tree -> 'ctx tree
                  (* getTime, startTime, limit, child *)
  val tick      : 'ctx tree -> 'ctx -> result
end
