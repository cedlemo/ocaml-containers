
(*
copyright (c) 2013-2014, simon cruanes
all rights reserved.

redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.  redistributions in binary
form must reproduce the above copyright notice, this list of conditions and the
following disclaimer in the documentation and/or other materials provided with
the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)

(** {1 Error Monad} *)

type 'a sequence = ('a -> unit) -> unit
type 'a equal = 'a -> 'a -> bool
type 'a ord = 'a -> 'a -> int
type 'a printer = Buffer.t -> 'a -> unit
type 'a formatter = Format.formatter -> 'a -> unit

(** {2 Basics} *)

type +'a t =
  [ `Ok of 'a
  | `Error of string
  ]

let return x = `Ok x

let fail s = `Error s

let of_exn e = `Error (Printexc.to_string e)

let map f e = match e with
  | `Ok x -> `Ok (f x)
  | `Error s -> `Error s

let flat_map f e = match e with
  | `Ok x -> f x
  | `Error s -> `Error s

let guard f =
  try
    return (f ())
  with e -> of_exn e

let (>|=) e f = map f e

let (>>=) e f = flat_map f e

let equal eq a b = match a, b with
  | `Ok x, `Ok y -> eq x y
  | `Error s, `Error s' -> s = s'
  | _ -> false

let compare cmp a b = match a, b with
  | `Ok x, `Ok y -> cmp x y
  | `Ok _, _  -> 1
  | _, `Ok _ -> -1
  | `Error s, `Error s' -> String.compare s s'

(** {2 Collections} *)

let map_l f l =
  let rec map acc l = match l with
  | [] -> `Ok (List.rev acc)
  | x::l' ->
      match f x with
      | `Error s -> `Error s
      | `Ok y -> map (y::acc) l'
  in map [] l

exception LocalExit of string

let fold_seq f acc seq =
  try
    let acc = ref acc in
    seq
      (fun x -> match f !acc x with
        | `Error s -> raise (LocalExit s)
        | `Ok y -> acc := y
      );
    `Ok !acc
  with LocalExit s -> `Error s

let fold_l f acc l = fold_seq f acc (fun k -> List.iter k l)

(** {2 Conversions} *)

let to_opt = function
  | `Ok x -> Some x
  | `Error _ -> None

let of_opt = function
  | None -> `Error "of_opt"
  | Some x -> `Ok x

let to_seq e k = match e with
  | `Ok x -> k x
  | `Error _ -> ()

(** {2 IO} *)

let pp pp_x buf e = match e with
  | `Ok x -> Printf.bprintf buf "ok(%a)" pp_x x
  | `Error s -> Printf.bprintf buf "error(%s)" s

let print pp_x fmt e = match e with
  | `Ok x -> Format.fprintf fmt "ok(%a)" pp_x x
  | `Error s -> Format.fprintf fmt "error(%s)" s