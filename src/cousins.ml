(* camlp4r ./pa_html.cmo *)
(* $Id: cousins.ml,v 4.13 2004/12/14 09:30:11 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Def;
open Gutil;
open Util;
open Config;

value default_max_lev = 5;
value default_max_cnt = 2000;

(* Utilities *)

value max_ancestor_level conf base ip max_lev =
  let x = ref 0 in
  let mark = Array.create base.data.persons.len False in
  let rec loop niveau ip =
    if mark.(Adef.int_of_iper ip) then ()
    else do {
      mark.(Adef.int_of_iper ip) := True;
      x.val := max x.val niveau;
      if x.val = max_lev then ()
      else
        match parents (aget conf base ip) with
        [ Some ifam ->
            let cpl = coi base ifam in
            do {
              loop (succ niveau) (father cpl); loop (succ niveau) (mother cpl)
            }
        | _ -> () ]
    }
  in
  do { loop 0 ip; x.val }
;

value brother_label conf x =
  match x with
  [ 1 -> transl conf "siblings"
  | 2 -> transl conf "cousins"
  | 3 -> transl conf "2nd cousins"
  | 4 -> transl conf "3rd cousins"
  | n ->
      Printf.sprintf (ftransl conf "%s cousins")
        (transl_nth conf "*nth (cousin)*" (n - 1)) ]
;

value rec except x =
  fun
  [ [] -> []
  | [y :: l] -> if x = y then l else [y :: except x l] ]
;

value children_of base u =
  List.fold_right
    (fun ifam list ->
       let des = doi base ifam in
       Array.to_list des.children @ list)
    (Array.to_list u.family) []
;

value siblings_by conf base iparent ip =
  let list = children_of base (uget conf base iparent) in
  except ip list
;

value merge_siblings l1 l2 =
  let l =
    rev_merge (List.rev l1) l2 where rec rev_merge r =
      fun
      [ [((v, _) as x) :: l] ->
          rev_merge (if List.mem_assoc v r then r else [x :: r]) l
      | [] -> r ]
  in
  List.rev l
;

value siblings conf base p =
  let ip = p.cle_index in
  match parents (aget conf base ip) with
  [ Some ifam ->
      let cpl = coi base ifam in
      let fath_sib =
        List.map (fun ip -> (ip, ((father cpl), Male)))
          (siblings_by conf base (father cpl) ip)
      in
      let moth_sib =
        List.map (fun ip -> (ip, ((mother cpl), Female)))
          (siblings_by conf base (mother cpl) ip)
      in
      merge_siblings fath_sib moth_sib
  | None -> [] ]
;

value rec has_desc_lev conf base lev u =
  if lev <= 1 then True
  else
    List.exists
      (fun ifam ->
         let des = doi base ifam in
         List.exists
           (fun ip -> has_desc_lev conf base (lev - 1) (uget conf base ip))
           (Array.to_list des.children))
      (Array.to_list u.family)
;

value br_inter_is_empty b1 b2 =
  List.for_all (fun (ip, _) -> not (List.mem_assoc ip b2)) b1
;

(* Algorithms *)

value print_choice conf base p niveau_effectif =
  tag "form" "method=get action=\"%s\"" conf.command begin
    Util.hidden_env conf;
    Wserver.wprint "<input type=hidden name=m value=C>\n";
    wprint_hidden_person conf base "" p;
    tag "select" "name=v1" begin
      let rec boucle i =
        if i > niveau_effectif then ()
        else do {
          Wserver.wprint "  <option value=%d%s> %s\n" i
            (if i == 2 then " selected" else "")
            (capitale (brother_label conf i));
          boucle (succ i)
        }
      in
      boucle 1;
    end;
    Wserver.wprint "<input type=submit value=\"Ok\">\n";
    Wserver.wprint "<br>\n";
    Wserver.wprint "<input type=checkbox name=csp value=on> %s\n"
      (capitale (transl conf "include spouses"));
  end
;

value cnt = ref 0;

value give_access conf base ia_asex p1 b1 p2 b2 =
  let reference _ _ p s =
    if is_hidden p then s
    else
    "<a href=\"" ^ commd conf ^ "m=RL;" ^ acces_n conf base "1" p1 ^ ";b1=" ^
      Num.to_string (Util.sosa_of_branch [ia_asex :: b1]) ^ ";" ^
      acces_n conf base "2" p2 ^ ";b2=" ^
      Num.to_string (Util.sosa_of_branch [ia_asex :: b2]) ^ ";spouse=on\">" ^
      s ^ "</a>"
  in
  let reference_sp p3 _ _ p s =
    if is_hidden p then s
    else
    "<a href=\"" ^ commd conf ^ "m=RL;" ^ acces_n conf base "1" p1 ^ ";b1=" ^
      Num.to_string (Util.sosa_of_branch [ia_asex :: b1]) ^ ";" ^
      acces_n conf base "2" p2 ^ ";b2=" ^
      Num.to_string (Util.sosa_of_branch [ia_asex :: b2]) ^ ";" ^
      acces_n conf base "4" p3 ^ ";spouse=on\">" ^ s ^ "</a>"
  in
  let print_nospouse _ =
    Wserver.wprint "%s%s"
      (gen_person_title_text reference std_access conf base p2)
      (Date.short_dates_text conf base p2)
  in
  let print_spouse sp first =
    do {
      if first then
        Wserver.wprint "%s"
          (gen_person_title_text reference std_access conf base p2)
      else Wserver.wprint "<br>%s" (person_title_text conf base p2);
      Wserver.wprint "%s & %s%s" (Date.short_dates_text conf base p2)
        (gen_person_title_text (reference_sp sp) std_access conf base sp)
        (Date.short_dates_text conf base sp)
    }
  in
  if match p_getenv conf.env "csp" with
     [ Some "on" -> False
     | _ -> True ]
  then
    print_nospouse ()
  else
    let u = Array.to_list (uget conf base p2.cle_index).family in
    match u with
    [ [] -> print_nospouse ()
    | _ ->
        let _ =
          List.fold_left
            (fun a ifam ->
               let cpl = coi base ifam in
               let sp =
                 if p2.sex = Female then pget conf base (father cpl)
                 else pget conf base (mother cpl)
               in
               let _ = print_spouse sp a in
               False)
            True u
        in
        () ]
;

value rec print_descend_upto conf base max_cnt ini_p ini_br lev children =
  if lev > 0 && cnt.val < max_cnt then do {
    if lev <= 2 then Wserver.wprint "<ul>\n" else ();
    List.iter
      (fun (ip, ia_asex, rev_br) ->
         let p = pget conf base ip in
         let u = uget conf base ip in
         let br = List.rev [(ip, p.sex) :: rev_br] in
         let is_valid_rel = br_inter_is_empty ini_br br in
         if is_valid_rel && cnt.val < max_cnt && has_desc_lev conf base lev u
         then do {
           if lev <= 2 then do {
             html_li conf;
             if lev = 1 then do {
               give_access conf base ia_asex ini_p ini_br p br; incr cnt
             }
             else do {
               let s =
                 transl_a_of_gr_eq_gen_lev conf
                   (transl_nth conf "child/children" 1)
                   (person_title_text conf base p)
               in
               Wserver.wprint "%s" (capitale s);
               Wserver.wprint ":"
             };
             Wserver.wprint "\n"
           }
           else ();
           let children =
             List.map
               (fun ip -> (ip, ia_asex, [(p.cle_index, p.sex) :: rev_br]))
               (children_of base u)
           in
           print_descend_upto conf base max_cnt ini_p ini_br (lev - 1)
             children
         }
         else ())
      children;
    if lev <= 2 then Wserver.wprint "</ul>\n" else ()
  }
  else ()
;

value sibling_has_desc_lev conf base lev (ip, _) =
  has_desc_lev conf base lev (uget conf base ip)
;

value print_cousins_side_of conf base max_cnt a ini_p ini_br lev1 lev2 =
  let sib = siblings conf base a in
  if List.exists (sibling_has_desc_lev conf base lev2) sib then do {
    if lev1 > 1 then do {
      html_li conf;
      Wserver.wprint "%s:\n"
        (capitale
           (cftransl conf "on %s's side"
              [gen_person_title_text no_reference raw_access conf base a]))
    }
    else ();
    let sib = List.map (fun (ip, ia_asex) -> (ip, ia_asex, [])) sib in
    print_descend_upto conf base max_cnt ini_p ini_br lev2 sib;
    True
  }
  else False
;

value print_cousins_lev conf base max_cnt p lev1 lev2 =
  let first_sosa =
    loop Num.one lev1 where rec loop sosa lev =
      if lev <= 1 then sosa else loop (Num.twice sosa) (lev - 1)
  in
  let last_sosa = Num.twice first_sosa in
  do {
    if lev1 > 1 then Wserver.wprint "<ul>\n" else ();
    let some =
      loop first_sosa False where rec loop sosa some =
        if cnt.val < max_cnt && Num.gt last_sosa sosa then
          let some =
            match Util.branch_of_sosa conf base p.cle_index sosa with
            [ Some ([(ia, _) :: _] as br) ->
                print_cousins_side_of conf base max_cnt (pget conf base ia) p
                  br lev1 lev2 ||
                some
            | _ -> some ]
          in
          loop (Num.inc sosa 1) some
        else some
    in
    if some then ()
    else do {
      html_li conf; Wserver.wprint "%s\n" (capitale (transl conf "no match"))
    };
    if lev1 > 1 then Wserver.wprint "</ul>\n" else ()
  }
;

(* HTML main *)

value print_cousins conf base p lev1 lev2 =
  let title h =
    let txt_fun = if h then gen_person_text_no_html else gen_person_text in
    if lev1 == lev2 then
      let s =
        transl_a_of_gr_eq_gen_lev conf
          (brother_label conf lev1) (txt_fun raw_access conf base p)
      in
      Wserver.wprint "%s" (capitale s)
    else if lev1 == 2 && lev2 == 1 then
      let s =
        transl_a_of_b conf (transl conf "uncles and aunts")
          (txt_fun raw_access conf base p)
      in
      Wserver.wprint "%s" (capitale s)
    else if lev1 == 1 && lev2 == 2 then
      let s =
        transl_a_of_gr_eq_gen_lev conf
          (transl conf "nephews and nieces") (txt_fun raw_access conf base p)
      in
      Wserver.wprint "%s" (capitale s)
    else
      Wserver.wprint "%s %d / %s %d" (capitale (transl conf "ancestors")) lev1
        (capitale (transl conf "descendants")) lev2
  in
  let max_cnt =
    try int_of_string (List.assoc "max_cousins" conf.base_env) with
    [ Not_found | Failure _ -> default_max_cnt ]
  in
  do {
    header conf title;
    cnt.val := 0;
    print_cousins_lev conf base max_cnt p lev1 lev2;
    if cnt.val >= max_cnt then Wserver.wprint "etc...\n"
    else if cnt.val > 1 then
      Wserver.wprint "%s: %d %s.\n" (capitale (transl conf "total")) cnt.val
        (nominative (transl_nth_def conf "person/persons" 2 1))
    else ();
    trailer conf
  }
;

value print_menu conf base p effective_level =
  let title h =
    let txt_fun = if h then gen_person_text_no_html else gen_person_text in
    let s =
      transl_a_of_gr_eq_gen_lev conf
        (transl conf "cousins (general term)")
        (txt_fun raw_access conf base p)
    in
    Wserver.wprint "%s" (capitale s)
  in
  do {
    header conf title;
    tag "ul" begin
      html_li conf;
      print_choice conf base p effective_level;
      html_li conf;
      Wserver.wprint "<a href=\"%s%s;m=C;v1=2;v2=1\">%s</a>\n" (commd conf)
        (acces conf base p) (capitale (transl conf "uncles and aunts"));
      if has_nephews_or_nieces conf base p then do {
        html_li conf;
        Wserver.wprint "<a href=\"%s%s;m=C;v1=1;v2=2\">%s</a>\n" (commd conf)
          (acces conf base p) (capitale (transl conf "nephews and nieces"))
      }
      else ();
    end;
    match p.death with
    [ NotDead | DontKnowIfDead when conf.wizard || conf.friend ->
        do {
          html_p conf;
          tag "ul" begin
            html_li conf;
            Wserver.wprint "<a href=\"%s%s;m=C;t=AN" (commd conf)
              (acces conf base p);
            Wserver.wprint "\">%s</a>\n" (capitale (transl conf "birthdays"));
          end
        }
    | _ -> () ];
    trailer conf
  }
;

value sosa_of_persons conf base =
  loop 1 where rec loop n =
    fun
    [ [] -> n
    | [ip :: list] ->
        loop (if (pget conf base ip).sex = Male then 2 * n else 2 * n + 1)
          list ]
;

value print_anniv conf base p level =
  let module S = Map.Make (struct type t = iper; value compare = compare; end)
  in
  let s_mem x m =
    try
      let _ = S.find x m in
      True
    with
    [ Not_found -> False ]
  in
  let rec insert_desc set up_sosa down_br n ip =
    if s_mem ip set then set
    else
      let set = S.add ip (up_sosa, down_br) set in
      if n = 0 then set
      else
        let u = (uget conf base ip).family in
        let down_br = [ip :: down_br] in
        let rec loop set i =
          if i = Array.length u then set
          else
            let chil = (doi base u.(i)).children in
            let set =
              loop set 0 where rec loop set i =
                if i = Array.length chil then set
                else
                  let set =
                    insert_desc set up_sosa down_br (n - 1) chil.(i)
                  in
                  loop set (i + 1)
            in
            loop set (i + 1)
        in
        loop set 0
  in
  let set =
    let module P =
      Pqueue.Make
        (struct
           type t = (iper * int * int);
           value leq (_, lev1, _) (_, lev2, _) = lev1 <= lev2;
         end)
    in
    let a = P.add (p.cle_index, 0, 1) P.empty in
    let rec loop set a =
      if P.is_empty a then set
      else
        let ((ip, n, up_sosa), a) = P.take a in
        let set = insert_desc set up_sosa [] (n + 3) ip in
        if n >= level then set
        else
          let a =
            match parents (aget conf base ip) with
            [ Some ifam ->
                let cpl = coi base ifam in
                let n = n + 1 in
                let up_sosa = 2 * up_sosa in
                let a = P.add ((father cpl), n, up_sosa) a in
                P.add ((mother cpl), n, up_sosa + 1) a
            | None -> a ]
          in
          loop set a
    in
    loop S.empty a
  in
  let set =
    S.fold
      (fun ip (up_sosa, down_br) set ->
         let u = (uget conf base ip).family in
         let set = S.add ip (up_sosa, down_br, None) set in
         if Array.length u = 0 then set
         else
           let rec loop set i =
             if i = Array.length u then set
             else
               let cpl = coi base u.(i) in
               let c = spouse ip cpl in
               loop (S.add c (up_sosa, down_br, Some ip) set) (i + 1)
           in
           loop set 0)
      set S.empty
  in
  let txt_of (up_sosa, down_br, spouse) conf base c =
    "<a href=\"" ^ commd conf ^ "m=RL;" ^ acces_n conf base "1" p ^ ";b1=" ^
      string_of_int up_sosa ^ ";" ^
      acces_n conf base "2"
        (match spouse with
         [ Some ip -> pget conf base ip
         | _ -> c ]) ^
      ";b2=" ^ string_of_int (sosa_of_persons conf base down_br) ^
      (match spouse with
       [ Some _ -> ";" ^ acces_n conf base "4" c
       | _ -> "" ]) ^
      ";spouse=on\">" ^ person_title_text conf base c ^ "</a>"
  in
  let f_scan =
    let list = ref (S.fold (fun ip b list -> [(ip, b) :: list]) set []) in
    fun () ->
      match list.val with
      [ [(x, b) :: l] -> do { list.val := l; (pget conf base x, txt_of b) }
      | [] -> raise Not_found ]
  in
  let mode () =
    do {
      Wserver.wprint "<input type=hidden name=m value=C>\n";
      Wserver.wprint "<input type=hidden name=i value=%d>\n"
        (Adef.int_of_iper p.cle_index);
      Wserver.wprint "<input type=hidden name=t value=AN>\n"
    }
  in
  match p_getint conf.env "v" with
  [ Some i -> Birthday.gen_print conf base i f_scan False
  | _ -> Birthday.gen_print_menu_birth conf base f_scan mode ]
;

value print conf base p =
  let max_lev =
    try int_of_string (List.assoc "max_cousins_level" conf.base_env) with
    [ Not_found | Failure _ -> default_max_lev ]
  in
  match (p_getint conf.env "v1", p_getenv conf.env "t") with
  [ (Some lev1, _) ->
      let lev1 = min (max 1 lev1) 10 in
      let lev2 =
        match p_getint conf.env "v2" with
        [ Some lev2 -> min (max 1 lev2) 10
        | None -> lev1 ]
      in
      print_cousins conf base p lev1 lev2
  | (_, Some "AN") when conf.wizard || conf.friend ->
      print_anniv conf base p max_lev
  | _ ->
      let effective_level =
        max_ancestor_level conf base p.cle_index max_lev + 1
      in
      if effective_level == 2 then print_cousins conf base p 2 2
      else print_menu conf base p effective_level ]
;
