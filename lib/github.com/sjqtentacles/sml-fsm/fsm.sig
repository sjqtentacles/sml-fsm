signature FSM =
sig
  type ('s, 'e) t
  val make      : ''s list -> ''s -> (''s -> 'e -> ''s option) -> (''s, 'e) t
  val current   : (''s, 'e) t -> ''s
  val send      : (''s, 'e) t -> 'e -> (''s, 'e) t   (* NONE guard -> stay *)
  val inState   : (''s, 'e) t -> ''s -> bool
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
  val tick      : 'ctx tree -> 'ctx -> result
end
