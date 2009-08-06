(* $Id: util.mli,v 4.32 2004/12/14 09:30:18 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Def;
open Config;

value add_lang_path : string -> unit;
value add_doc_path : string -> unit;
value set_base_dir : string -> unit;
value cnt_dir : ref string;
value images_url : ref string;
value image_prefix : config -> string;
value base_path : list string -> string -> string;

value search_in_lang_path : string -> string;
value search_in_doc_path : string -> string;

value escache_value : config -> string;
value commit_patches : config -> base -> unit;
value update_wf_trace : config -> string -> unit;

value secure : string -> string;

value nl : unit -> unit;
value html : config -> unit;
value html1 : config -> unit;
value html_br : config -> unit;
value html_p : config -> unit;
value html_li : config -> unit;
value unauthorized : config -> string -> unit;
value string_of_ctime : config -> string;

value commd : config -> string;
value code_varenv : string -> string;
value decode_varenv : string -> string;
value hidden_env : config -> unit;

value authorized_age : config -> base -> person -> bool;
value is_old_person : config -> person -> bool;
value fast_auth_age : config -> person -> bool;

value start_with_vowel : string -> bool;
value know : base -> person -> bool;
value acces_n : config -> base -> string -> person -> string;
value acces : config -> base -> person -> string;
value wprint_hidden_person : config -> base -> string -> person -> unit;

value geneweb_link : config -> string -> string -> string;
value wprint_geneweb_link : config -> string -> string -> unit;

value is_restricted : config -> base -> iper -> bool;
value is_hidden : person -> bool;

value pget : config -> base -> iper -> person;
value aget : config -> base -> iper -> ascend;
value uget : config -> base -> iper -> union;

type p_access = (base -> person -> string * base -> person -> string);
value std_access : p_access;
value raw_access : p_access;

value gen_person_text : p_access -> config -> base -> person -> string;
value gen_person_text_no_html : p_access -> config -> base -> person -> string;
value gen_person_text_without_title :
  p_access -> config -> base -> person -> string
;
value gen_person_title_text :
  (config -> base -> person -> string -> string) ->
    p_access -> config -> base -> person -> string
;

value reference : config -> base -> person -> string -> string;
value no_reference : config -> base -> person -> string -> string;
value person_text : config -> base -> person -> string;
value person_text_no_html : config -> base -> person -> string;
value person_text_without_surname : config -> base -> person -> string;
value person_text_without_title : config -> base -> person -> string;
value titled_person_text : config -> base -> person -> title -> string;
value one_title_text : config -> base -> person -> title -> string;
value person_title_text : config -> base -> person -> string;
value person_title : config -> base -> person -> string;

value referenced_person_title_text : config -> base -> person -> string;
value referenced_person_text : config -> base -> person -> string;
value referenced_person_text_without_surname :
  config -> base -> person -> string;

value main_title : base -> person -> option title;
value p_getenv : list (string * string) -> string -> option string;
value p_getint : list (string * string) -> string -> option int;
value create_env : string -> list (string * string);
value capitale : string -> string;

value header_no_page_title : config -> (bool -> unit) -> unit;
value header : config -> (bool -> unit) -> unit;
value rheader : config -> (bool -> unit) -> unit;
value trailer : config -> unit;
value gen_trailer : bool -> config -> unit;
value open_etc_file : string -> option in_channel;
value copy_from_etc :
  list (char * unit -> string) -> string -> string -> in_channel -> unit;
value string_with_macros :
  config -> bool -> list (char * unit -> string) -> string -> string;
value body_prop : config -> string;
value include_hed_trl : config -> option base -> string -> unit;
value url_no_index : config -> base -> string;
value setup_link : config -> string;
value message_to_wizard : config -> unit;

value print_alphab_list :
  config -> ('a -> string) -> ('a -> unit) -> list 'a -> unit;
value of_course_died : config -> person -> bool;

value surname_begin : string -> string;
value surname_end : string -> string;

value specify_homonymous : config -> base -> person -> unit;

value valid_format : format 'a 'b 'c -> string -> format 'a 'b 'c;

value transl : config -> string -> string;
value transl_nth : config -> string -> int -> string;
value transl_nth_def : config -> string -> int -> int -> string;
value transl_decline : config -> string -> string -> string;
value transl_a_of_b : config -> string -> string -> string;
value transl_a_of_gr_eq_gen_lev : config -> string -> string -> string;
value ftransl : config -> format 'a 'b 'c -> format 'a 'b 'c;
value ftransl_nth : config -> format 'a 'b 'c -> int -> format 'a 'b 'c;
value fdecline : config -> format 'a 'b 'c -> string -> format 'a 'b 'c;
value fcapitale : format 'a 'b 'c -> format 'a 'b 'c;
value nth_field : string -> int -> string;

value cftransl : config -> string -> list string -> string;

value std_color : config -> string -> string;

value index_of_sex : sex -> int;

value relation_txt :
  config -> sex -> family -> format (('a -> 'b) -> 'b) 'a 'b;

value incorrect_request : config -> unit;

value string_of_decimal_num : config -> float -> string;

value find_person_in_env : config -> base -> string -> option person;
value find_sosa_ref : config -> base -> option person;

value quote_escaped : string -> string;

value get_server_string : config -> string;
value get_request_string : config -> string;

value get_server_string_aux : bool -> list string -> string;
value get_request_string_aux : bool -> list string -> string;

value create_topological_sort : config -> base -> array int;

value branch_of_sosa :
  config -> base -> iper -> Num.t -> option (list (iper * sex));
value sosa_of_branch : list (iper * sex) -> Num.t;

value link_to_referer : config -> string;
value print_link_to_welcome : config -> bool -> unit;

value has_image : config -> base -> person -> bool;
value image_file_name : string -> string;
value source_image_file_name : string -> string -> string;

value image_size : string -> option (int * int);
value limited_image_size : int -> int -> string -> option (int * int)
  -> option (int * int);
value image_and_size :
  config -> base -> person ->
  (string -> option (int * int) -> option (int * int)) ->
    option (bool * string * option (int * int));

value default_image_name_of_key : string -> string -> int -> string;
value default_image_name : base -> person -> string;
value auto_image_file : config -> base -> person -> option string;

value only_printable : string -> string;

value relation_type_text : config -> relation_type -> int -> string;
value rchild_type_text : config -> relation_type -> int -> string;

value has_nephews_or_nieces : config -> base -> person -> bool;

value browser_doesnt_have_tables : config -> bool;

value start_with : string -> int -> string -> bool;

(* Printing for browsers without tables *)

value pre_text_size : string -> int;
value print_pre_center : int -> string -> unit;
value print_pre_left : int -> string -> unit;
value print_pre_right : int -> string -> unit;

(* List selection bullets *)

value print_selection_bullet : config -> option (string * bool) -> unit;
value unselected_bullets : config -> list int;

value short_f_month : int -> string;
