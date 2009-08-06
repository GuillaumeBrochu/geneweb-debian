(* $Id: dag2html.mli,v 1.4 2001/08/24 04:54:09 ddr Exp $ *)

type dag 'a = { dag : mutable array (node 'a) }
and node 'a =
  { pare : mutable list idag; valu : 'a; chil : mutable list idag }
and idag = 'x
;

external int_of_idag : idag -> int = "%identity";
external idag_of_int : int -> idag = "%identity";

type table 'a = { table : mutable array (array (data 'a)) }
and data 'a = { elem : mutable elem 'a; span : mutable span_id }
and elem 'a = [ Elem of 'a | Ghost of ghost_id | Nothing ]
and span_id = 'x
and ghost_id = 'x
;

type align = [ LeftA | CenterA | RightA ];
type table_data = [ TDstring of string | TDhr of align | TDbar of string ];
type html_table = array (array (int * align * table_data));

value html_table_struct :
  (node 'a -> string) -> (node 'a -> string) -> (node 'a -> bool) ->
    dag 'a -> table idag -> array (array (int * align * table_data));

value table_of_dag :
  (node 'a -> bool) -> bool -> bool -> bool -> dag 'a -> table idag;
