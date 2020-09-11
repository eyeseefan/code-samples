(* Author: Fan Bu
 * Below are both a sequential and a parallel implementation of the Breadth-First Search algorithm
 * using a functional programming language Standard ML. The sequential algorithm has a work of
 * O(E+V). The parallel algorithm has a work of O(E+V) and a span of O(D*logV), where D is the
 * diameter of the graph. This piece of code was written for the course 15-210 at Carnegie
 * Mellon University. S in the code below is a structure for mutable sequence. P.for is a function
 * that implements for-loops, and P.parfor is similar to P.for, but with parallel execution.
 *)

functor MkBFS
  (structure S : INT_ARRAY_SLICE
   structure Graph : GRAPH where type S.t = S.t) :>
sig
  type slice = S.t
  val bfs : Graph.t -> int -> slice
end =
struct

  structure P = Primitives
  type slice = S.t


  fun bfs (g : Graph.t) (s : Graph.vertex) =
  let
    (* GRAIN: Parameter for Granularity Control *)
    val GRAIN = 8192
    val n = Graph.numVertices g

    (* R: Visited vertices indicated by the diameter, ~1 if the vertex is not visited *)
    val R = S.tabulate (fn _ => ~1) n
    val _ = S.set R (s, 0)

    (* F0: Initial Frontier *)
    val F0 = S.tabulate (fn _ => s) 1
    
    (* NF_seq: Next Frontier for Sequential Implementation *)
    val NF_seq = S.allocate n
    fun seq_visit F d =
      if S.length F = 0
      then ()
      else
        let
          val endNF = ref 0
        in
          (P.for (0, S.length F)
           (fn i =>
            let
              val neighbors = Graph.neighbors g (S.get F i)
            in
              P.for (0, S.length neighbors)
              (fn j =>
               let
                 val v = S.get neighbors j
                 (* If R[v] = ~1, then S.cas R (v, ~1, d) sets R[v] to d atomically and outputs True
                    Else, S.cas R (v, ~1, d) outputs False *)
                 val inNF = S.cas R (v, ~1, d)
               in
                 if inNF
                 then (S.set NF_seq (!endNF, v); endNF := (!endNF) + 1)
                 else ()
               end)
            end);
            seq_visit (S.subslice NF_seq (0, !endNF)) (d + 1))
        end
    
    (* NF_par: Next Frontier for Parallel Implementation *)
    val NF_par = S.tabulate (fn _ => ~1) n
    fun par_visit F d =
      if S.length F = 0
      then ()
      else
        let
          val _ = P.parfor GRAIN (0, S.length F)
                  (fn i => S.set NF_par (S.get F i, ~1))
        in
          (P.parfor GRAIN (0, S.length F)
           (fn i =>
            let
              val neighbors = Graph.neighbors g (S.get F i)
            in
              P.parfor GRAIN (0, S.length neighbors)
              (fn j =>
               let
                 val v = S.get neighbors j
                 (* If R[v] = ~1, then S.cas R (v, ~1, d) sets R[v] to d atomically and outputs True
                    Else, S.cas R (v, ~1, d) outputs False *)
                 val inNF = S.cas R (v, ~1, d)
               in
                 if inNF then S.set NF_par (v,v) else ()
               end)
            end);
            par_visit (S.filter (fn v => v <> ~1) NF_par) (d+1))
        end
  in
    (if n <= GRAIN
     then seq_visit F0 1
     else par_visit F0 1;
     R)
  end
end