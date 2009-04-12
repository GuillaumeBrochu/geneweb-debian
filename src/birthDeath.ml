(* camlp4r ./def.syn.cmo ./pa_html.cmo *)
(* $Id: birthDeath.ml,v 4.14 2004/12/14 09:30:10 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Def;
open Gutil;
open Util;
open Config;

value before_date d d1 =
  if d1.year < d.year then True
  else if d1.year > d.year then False
  else if d1.month < d.month then True
  else if d1.month > d.month then False
  else if d1.prec > d.prec then True
  else if d1.prec < d.prec then False
  else if d1.day < d.day then True
  else if d1.day > d.day then False
  else True
;

value select conf base get_date find_oldest =
  let module Q =
    Pqueue.Make
      (struct
         type t = (Def.person * Def.dmy * Def.calendar);
         value leq (_, x, _) (_, y, _) =
           if find_oldest then before_date x y else before_date y x
         ;
       end)
  in
  let n =
    match p_getint conf.env "k" with
    [ Some x -> x
    | _ ->
        try int_of_string (List.assoc "latest_event" conf.base_env) with
        [ Not_found | Failure _ -> 20 ] ]
  in
  let n = min (max 0 n) base.data.persons.len in
  let ref_date =
    match p_getint conf.env "by" with
    [ Some by ->
        let bm =
          match p_getint conf.env "bm" with
          [ Some x -> x
          | None -> -1 ]
        in
        let bd =
          match p_getint conf.env "bd" with
          [ Some x -> x
          | None -> -1 ]
        in
        {day = bd; month = bm; year = by; prec = Sure; delta = 0}
    | None -> {(conf.today) with year = 9999} ]
  in
  let rec loop q len i =
    if i = base.data.persons.len then
      let rec loop list q =
        if Q.is_empty q then (list, len)
        else let (e, q) = Q.take q in loop [e :: list] q
      in
      loop [] q
    else
      let p = pget conf base (Adef.iper_of_int i) in
      match get_date p with
      [ Some (Dgreg d cal) ->
          if before_date d ref_date then loop q len (i + 1)
          else
            let e = (p, d, cal) in
            if len < n then loop (Q.add e q) (len + 1) (i + 1)
            else loop (snd (Q.take (Q.add e q))) len (i + 1)
      | _ -> loop q len (i + 1) ]
  in
  loop Q.empty 0 0
;

value select_family conf base get_date find_oldest =
  let module QF =
    Pqueue.Make
      (struct
         type t = (Def.family * Def.dmy * Def.calendar);
         value leq (_, x, _) (_, y, _) =
	   if find_oldest then before_date x y else before_date y x;
       end)
  in
  let n =
    match p_getint conf.env "k" with
    [ Some x -> x
    | _ ->
        try int_of_string (List.assoc "latest_event" conf.base_env) with
        [ Not_found | Failure _ -> 20 ] ]
  in
  let n = min (max 0 n) base.data.families.len in
  let rec loop q len i =
    if i = base.data.families.len then
      let rec loop list q =
        if QF.is_empty q then (list, len)
        else let (e, q) = QF.take q in loop [e :: list] q
      in
      loop [] q
    else
      let fam = base.data.families.get i in
      let (q, len) =
        if Gutil.is_deleted_family fam then (q, len)
        else
          match get_date fam with
          [ Some (Dgreg d cal) ->
              let e = (fam, d, cal) in
              if len < n then (QF.add e q, len + 1)
              else (snd (QF.take (QF.add e q)), len)
          | _ -> (q, len) ]
      in
      loop q len (i + 1)
  in
  loop QF.empty 0 0
;

value print_birth conf base =
  let (list, len) =
    select conf base (fun p -> Adef.od_of_codate p.birth) False
  in
  let title _ =
    Wserver.wprint (fcapitale (ftransl conf "the latest %d births")) len
  in
  do {
    header conf title;
    print_link_to_welcome conf True;
    Wserver.wprint "<ul>\n";
    let _ =
      List.fold_left
        (fun (last_month_txt, was_future) (p, d, cal) ->
           let month_txt =
             let d = {(d) with day = 0} in
             capitale (Date.string_of_date conf (Dgreg d cal))
           in
           let future = strictly_after_dmy d conf.today in
           do {
             if not future && was_future then do {
               Wserver.wprint "</ul>\n</ul>\n<p>\n<ul>\n";
               Wserver.wprint "<li>%s\n" month_txt;
               Wserver.wprint "<ul>\n";
             }
             else if month_txt <> last_month_txt then do {
               if last_month_txt = "" then () else Wserver.wprint "</ul>\n";
               Wserver.wprint "<li>%s\n" month_txt;
               Wserver.wprint "<ul>\n";
             }
             else ();
             Wserver.wprint "<li>\n";
             Wserver.wprint "<strong>\n";
             Wserver.wprint "\n%s" (referenced_person_text conf base p);
             Wserver.wprint "</strong>,\n";
             if future then
               Wserver.wprint "<em>%s</em>.\n"
                 (Date.string_of_date conf (Dgreg d cal))
             else
               Wserver.wprint "%s <em>%s</em>.\n"
                 (transl_nth conf "born" (index_of_sex p.sex))
                 (Date.string_of_ondate conf (Dgreg d cal));
             (month_txt, future)
           })
        ("", False) list
    in
    Wserver.wprint "</ul>\n</ul>\n";
    trailer conf;
  }
;

value get_death p =
  match p.death with
  [ Death _ cd -> Some (Adef.date_of_cdate cd)
  | _ -> None ]
;

value print_death conf base =
  let (list, len) = select conf base get_death False in
  let title _ =
    Wserver.wprint (fcapitale (ftransl conf "the latest %d deaths")) len
  in
  do {
    header conf title;
    print_link_to_welcome conf True;
    Wserver.wprint "<ul>\n";
    let _ =
      List.fold_left
        (fun last_month_txt (p, d, cal) ->
           let month_txt =
             let d = {(d) with day = 0} in
             capitale (Date.string_of_date conf (Dgreg d cal))
           in
           do {
             if month_txt <> last_month_txt then do {
               if last_month_txt = "" then () else Wserver.wprint "</ul>\n";
               Wserver.wprint "<li>%s\n" month_txt;
               Wserver.wprint "<ul>\n";
             }
             else ();
             Wserver.wprint "<li>\n";
             Wserver.wprint "<strong>\n";
             Wserver.wprint "\n%s" (referenced_person_text conf base p);
             Wserver.wprint "</strong>,\n";
             Wserver.wprint "%s <em>%s</em>"
               (transl_nth conf "died" (index_of_sex p.sex))
               (Date.string_of_ondate conf (Dgreg d cal));
             let sure d = d.prec = Sure in
             match Adef.od_of_codate p.birth with
             [ Some (Dgreg d1 _) ->
                 if sure d1 && sure d && d1 <> d then do {
                   let a = time_gone_by d1 d in
                   Wserver.wprint " <em>(%s)</em>"
                     (Date.string_of_age conf a);
                 }
                 else ()
             | _ -> () ];
             Wserver.wprint "\n";
             month_txt
           })
        "" list
    in
    Wserver.wprint "</ul>\n</ul>\n";
    trailer conf;
  }
;

value print_oldest_alive conf base =
  let limit =
    match p_getint conf.env "lim" with
    [ Some x -> x
    | _ -> 0 ]
  in
  let get_oldest_alive p =
    match p.death with
    [ NotDead -> Adef.od_of_codate p.birth
    | DontKnowIfDead when limit > 0 ->
        match Adef.od_of_codate p.birth with
        [ Some (Dgreg d _) as x when conf.today.year - d.year <= limit -> x
        | _ -> None ]
    | _ -> None ]
  in
  let (list, len) = select conf base get_oldest_alive True in
  let title _ =
    Wserver.wprint
      (fcapitale (ftransl conf "the %d oldest perhaps still alive")) len
  in
  do {
    header conf title;
    print_link_to_welcome conf True;
    Wserver.wprint "<ul>\n";
    List.iter
      (fun (p, d, cal) ->
         do {
           Wserver.wprint "<li>\n";
           Wserver.wprint "<strong>\n";
           Wserver.wprint "\n%s" (referenced_person_text conf base p);
           Wserver.wprint "</strong>,\n";
           Wserver.wprint "%s <em>%s</em>"
             (transl_nth conf "born" (index_of_sex p.sex))
             (Date.string_of_ondate conf (Dgreg d cal));
           if p.death = NotDead && d.prec = Sure then do {
             let a = time_gone_by d conf.today in
             Wserver.wprint " <em>(%s)</em>" (Date.string_of_age conf a);
           }
           else ();
           Wserver.wprint ".\n";
         })
      list;
    Wserver.wprint "</ul>\n\n";
    trailer conf;
  }
;

value print_longest_lived conf base =
  let get_longest p =
    if Util.fast_auth_age conf p then
      match (Adef.od_of_codate p.birth, p.death) with
      [ (Some (Dgreg bd _), Death _ cd) ->
          match Adef.date_of_cdate cd with
          [ Dgreg dd _ -> Some (Dgreg (time_gone_by bd dd) Dgregorian)
          | _ -> None ]
      | _ -> None ]
    else None
  in
  let (list, len) = select conf base get_longest False in
  let title _ =
    Wserver.wprint (fcapitale (ftransl conf "the %d who lived the longest"))
      len
  in
  do {
    header conf title;
    print_link_to_welcome conf True;
    Wserver.wprint "<ul>\n";
    List.iter
      (fun (p, d, cal) ->
         do {
           Wserver.wprint "<li>\n";
           Wserver.wprint "<strong>\n";
           Wserver.wprint "\n%s" (referenced_person_text conf base p);
           Wserver.wprint "</strong>%s" (Date.short_dates_text conf base p);
           Wserver.wprint "\n(%d %s)" d.year (transl conf "years old");
           Wserver.wprint ".\n";
         })
      list;
    Wserver.wprint "</ul>\n\n";
    trailer conf;
  }
;

value print_marr_or_eng conf base title list len =
  do {
    header conf title;
    print_link_to_welcome conf True;
    Wserver.wprint "<ul>\n";
    let _ =
      List.fold_left
        (fun (last_month_txt, was_future) (fam, d, cal) ->
           let month_txt =
             let d = {(d) with day = 0} in
             capitale (Date.string_of_date conf (Dgreg d cal))
           in
           let cpl = coi base fam.fam_index in
           let future = strictly_after_dmy d conf.today in
           do {
             if not future && was_future then do {
               Wserver.wprint "</ul>\n</ul>\n<p>\n<ul>\n";
               Wserver.wprint "<li>%s\n" month_txt;
               Wserver.wprint "<ul>\n";
             }
             else if month_txt <> last_month_txt then do {
               if last_month_txt = "" then () else Wserver.wprint "</ul>\n";
               Wserver.wprint "<li>%s\n" month_txt;
               Wserver.wprint "<ul>\n";
             }
             else ();
             Wserver.wprint "<li>\n";
             Wserver.wprint "<strong>\n";
             Wserver.wprint "\n%s"
               (referenced_person_text conf base
                  (pget conf base (father cpl)));
             Wserver.wprint "</strong>\n";
             Wserver.wprint "%s" (transl_nth conf "and" 0);
             Wserver.wprint "<strong>\n";
             Wserver.wprint "\n%s"
               (referenced_person_text conf base
                  (pget conf base (mother cpl)));
             Wserver.wprint "</strong>,\n";
             if future then
               Wserver.wprint "<em>%s</em>.\n"
                 (Date.string_of_date conf (Dgreg d cal))
             else
               Wserver.wprint "%s <em>%s</em>.\n"
                 (match fam.relation with
                  [ NotMarried -> transl_nth conf "relation/relations" 0
                  | Married | NoSexesCheck -> transl conf "married"
                  | Engaged -> transl conf "engaged"
		  | NoMention -> "" ])
                 (Date.string_of_ondate conf (Dgreg d cal));
             (month_txt, future)
           })
        ("", False) list
    in
    Wserver.wprint "</ul>\n</ul>\n";
    trailer conf;
  }
;

value print_marriage conf base =
  let (list, len) =
    select_family conf base
      (fun fam ->
         if fam.relation == Married then Adef.od_of_codate fam.marriage
         else None)
      False
  in
  let title _ =
    Wserver.wprint (fcapitale (ftransl conf "the latest %d marriages")) len
  in
  print_marr_or_eng conf base title list len
;

value print_oldest_engagements conf base =
  let (list, len) =
    select_family conf base
      (fun fam ->
         if fam.relation == Engaged then
           let cpl = coi base fam.fam_index in
           let husb = poi base (father cpl) in
           let wife = poi base (mother cpl) in
           match (husb.death, wife.death) with
           [ (NotDead | DontKnowIfDead, NotDead | DontKnowIfDead) ->
               Adef.od_of_codate fam.marriage
           | _ -> None ]
         else None)
      True
  in
  let title _ =
    Wserver.wprint
     (fcapitale
       (ftransl conf "the %d oldest couples perhaps still alive and engaged"))
     len
  in
  print_marr_or_eng conf base title list len
;

value print_statistics conf base =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "statistics")) in
  let n =
    try int_of_string (List.assoc "latest_event" conf.base_env) with
    [ Not_found | Failure _ -> 20 ]
  in
  do {
    header conf title;
    print_link_to_welcome conf True;
    tag "ul" begin
      if conf.wizard || conf.friend then do {
        Wserver.wprint "<li><a href=\"%sm=LB;k=%d\">" (commd conf) n;
        Wserver.wprint (ftransl conf "the latest %d births") n;
        Wserver.wprint "</a>\n";
        Wserver.wprint "<li><a href=\"%sm=LD;k=%d\">" (commd conf) n;
        Wserver.wprint (ftransl conf "the latest %d deaths") n;
        Wserver.wprint "</a>\n";
        Wserver.wprint "<li><a href=\"%sm=LM;k=%d\">" (commd conf) n;
        Wserver.wprint (ftransl conf "the latest %d marriages") n;
        Wserver.wprint "</a>\n";
        Wserver.wprint "<li><a href=\"%sm=OE;k=%d\">" (commd conf) n;
        Wserver.wprint
          (ftransl conf
             "the %d oldest couples perhaps still alive and engaged") n;
        Wserver.wprint "</a>\n";
        Wserver.wprint "<li><a href=\"%sm=OA;k=%d;lim=0\">" (commd conf) n;
        Wserver.wprint (ftransl conf "the %d oldest perhaps still alive") n;
        Wserver.wprint "</a>\n";
      }
      else ();
      Wserver.wprint "<li><a href=\"%sm=LL;k=%d\">" (commd conf) n;
      Wserver.wprint (ftransl conf "the %d who lived the longest") n;
      Wserver.wprint "</a>\n";
    end;
    trailer conf;
  }
;
