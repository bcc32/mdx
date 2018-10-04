(*
 *  This file originates from OCamlFormat.
 *
 *  Copyright (c) 2017-present, Facebook, Inc.  All rights reserved.
 *
 *  This source code is licensed under the MIT license.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 *  in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *)

(* original modules *)
module Asttypes_ = Asttypes
module Parsetree_ = Parsetree

include (
  Ast_406 :
    module type of struct
      include Ast_406
    end
    with module Location := Ast_406.Location
     and module Outcometree := Ast_406.Outcometree
     and module Asttypes := Ast_406.Asttypes
     and module Ast_helper := Ast_406.Ast_helper
     and module Parsetree := Ast_406.Parsetree
 )

module Asttypes = Ast_406.Asttypes
module Ast_helper = Ast_406.Ast_helper
module Parsetree = Ast_406.Parsetree

module Parse = struct
  open Migrate_parsetree

  let implementation = Parse.implementation Versions.ocaml_406

  let interface = Parse.interface Versions.ocaml_406

  let toplevel_phrase lexbuf =
    Parse.toplevel_phrase Versions.ocaml_406 lexbuf
end

let to_current =
  Migrate_parsetree.Versions.(migrate ocaml_406 ocaml_current)

let to_406 =
  Migrate_parsetree.Versions.(migrate ocaml_current ocaml_406)

module Printast = struct
  open Printast

  let implementation f x = implementation f (to_current.copy_structure x)

  let interface f x = interface f (to_current.copy_signature x)

  let expression n f x = expression n f (to_current.copy_expression x)

  let payload n f (x : Parsetree.payload) =
    payload n f
      ( match x with
      | PStr x -> PStr (to_current.copy_structure x)
      | PSig x -> PSig (to_current.copy_signature x)
      | PTyp x -> PTyp (to_current.copy_core_type x)
      | PPat (x, y) ->
          PPat
            ( to_current.copy_pattern x
            , match y with
              | Some y -> Some (to_current.copy_expression y)
              | None -> None ) )

  let copy_directive_argument (x : Parsetree.directive_argument) =
    let open Migrate_parsetree.Versions.OCaml_current.Ast.Parsetree in
    match x with
    | Pdir_none -> Pdir_none
    | Pdir_string s -> Pdir_string s
    | Pdir_int (s, c) -> Pdir_int (s, c)
    | Pdir_ident i -> Pdir_ident i
    | Pdir_bool b -> Pdir_bool b

  let top_phrase f (x : Parsetree.toplevel_phrase) =
    match x with
    | Ptop_def s ->
       top_phrase f (Ptop_def (to_current.copy_structure s))
    | Ptop_dir (d, a) ->
       top_phrase f (Ptop_dir (d, copy_directive_argument a))
end

module Pprintast = struct
  open Pprintast

  let structure f x = structure f (to_current.copy_structure x)

  let signature f x = signature f (to_current.copy_signature x)

  let core_type f x = core_type f (to_current.copy_core_type x)

  let expression f x = expression f (to_current.copy_expression x)

  let pattern f x = pattern f (to_current.copy_pattern x)

  let top_phrase f x = top_phrase f (to_current.copy_toplevel_phrase x)
end

(* Missing from ocaml_migrate_parsetree *)
let map_use_file mapper use_file =
  let open Parsetree in
  List.map (fun toplevel_phrase ->
      match (toplevel_phrase : toplevel_phrase) with
      | Ptop_def structure ->
          Ptop_def (mapper.Ast_mapper.structure mapper structure)
      | Ptop_dir _ as d -> d ) use_file

module Printtyp = struct
  include Printtyp

  let wrap_printing_env e f =
    wrap_printing_env
#if OCAML_MAJOR >= 4 && OCAML_MINOR >= 7
      ~error:false
#endif
      e f
end

module Pparse = struct
  open Pparse

  let apply_rewriters_str ~tool_name s =
    apply_rewriters_str ~tool_name (to_current.copy_structure s)
    |> to_406.copy_structure
end

module Position = struct
  open Lexing

  let column {pos_fname=_; pos_lnum=_; pos_bol; pos_cnum} = pos_cnum - pos_bol

  let fmt fs {pos_fname=_; pos_lnum; pos_bol; pos_cnum} =
    if pos_lnum = -1 then Format.fprintf fs "[%d]" pos_cnum
    else Format.fprintf fs "[%d,%d+%d]" pos_lnum pos_bol (pos_cnum - pos_bol)

  let compare_col p1 p2 = (column p1) - (column p2)

  let equal p1 p2 =
    String.equal p1.pos_fname p2.pos_fname
    && p1.pos_lnum = p2.pos_lnum
    && p1.pos_bol = p2.pos_bol
    && p1.pos_cnum = p2.pos_cnum

  let compare p1 p2 =
    if equal p1 p2 then 0 else p1.pos_cnum - p2.pos_cnum

  let distance p1 p2 = p2.pos_cnum - p1.pos_cnum
end

module Location = struct
  include Ast_406.Location

  let fmt fs {loc_start; loc_end; loc_ghost} =
    Format.fprintf fs "(%a..%a)%s" Position.fmt loc_start Position.fmt
      loc_end
      (if loc_ghost then " ghost" else "")

  let to_string x = Format.asprintf "%a" fmt x

  let compare x y =
    let compare_start = Position.compare x.loc_start y.loc_start in
    if compare_start = 0 then Position.compare x.loc_end y.loc_end
    else compare_start

  let hash = Hashtbl.hash

  let is_single_line x = x.loc_start.pos_lnum = x.loc_end.pos_lnum

  let compare_start x y = Position.compare x.loc_start y.loc_start

  let compare_start_col x y = Position.compare_col x.loc_start y.loc_start

  let compare_end x y = Position.compare x.loc_end y.loc_end

  let compare_end_col x y = Position.compare_col x.loc_end y.loc_end

  let contains l1 l2 = compare_start l1 l2 <= 0 && compare_end l1 l2 >= 0

  let width x = Position.distance x.loc_start x.loc_end

  let compare_width_decreasing l1 l2 = (width l2) - (width l1)
end
