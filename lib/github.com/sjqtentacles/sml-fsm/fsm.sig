signature FSM =
sig
  type ('s, 'e) t
  val make      : ''s list -> ''s -> (''s -> 'e -> ''s option) -> (''s, 'e) t
  val current   : (''s, 'e) t -> ''s
  val send      : (''s, 'e) t -> 'e -> (''s, 'e) t   (* NONE guard -> stay *)
  val inState   : (''s, 'e) t -> ''s -> bool
  val canSend   : (''s, 'e) t -> 'e -> bool          (* would the event cause a transition? *)
  val states    : (''s, 'e) t -> ''s list            (* declared state set *)
  val sendAll   : (''s, 'e) t -> 'e list -> (''s, 'e) t
  val history   : (''s, 'e) t -> ''s list            (* visited states, oldest first *)
  val toDot     : (''s -> string) -> (''s, 'e) t -> string  (* Graphviz of declared states + current *)
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
  val tick      : 'ctx tree -> 'ctx -> result
end
