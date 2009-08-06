(* $Id: update.mli,v 4.7 2004/12/14 09:30:17 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Def;
open Config;

exception ModErr;
type create_info = (option date * string * death * option date * string);
type create = [ Create of sex and option create_info | Link ];
type key = (string * string * int * create * string);

value infer_death : config -> option date -> death;
value print_same_name : config -> base -> person -> unit;

value insert_person :
  config -> base -> string -> ref (list person) -> key -> Adef.iper
;
value insert_string : base -> string -> Adef.istr;
value add_misc_names_for_new_persons : base -> list person -> unit;
value update_misc_names_of_family : base -> person -> union -> unit;
value delete_topological_sort_v : config -> base -> unit;
value delete_topological_sort : config -> base -> unit;

value print_return : config -> unit;
value print_error : config -> base -> Gutil.base_error -> unit;
value print_warnings : config -> base -> list Gutil.base_warning -> unit;
value error : config -> base -> Gutil.base_error -> 'a;

value error_locked : config -> base -> unit;
value error_digest : config -> base -> 'a;

value digest_person : person -> Digest.t;
value digest_family : family -> couple -> descend -> Digest.t;

value reconstitute_date : config -> string -> option date;
value print_date : config -> base -> string -> string -> option date -> unit;

value print_src : config -> string -> string -> unit;
value print_someone : config -> base -> person -> unit;
value print : config -> base -> person -> unit;

value update_conf : config -> config;
