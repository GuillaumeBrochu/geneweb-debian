(* $Id: check.ml,v 4.15 2004/12/14 09:30:11 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Def;
open Gutil;
open Printf;

value feminin =
  fun
  [ Male -> ""
  | Female -> "e"
  | Neuter -> "(e)" ]
;

(* Printing check errors *)

value print_base_error oc base =
  fun
  [ AlreadyDefined p ->
      fprintf oc "%s\nis defined several times\n" (designation base p)
  | OwnAncestor p ->
      fprintf oc "%s\nis his/her own ancestor\n" (designation base p)
  | BadSexOfMarriedPerson p ->
      fprintf oc "%s\n  bad sex for a married person\n" (designation base p) ]
;

value print_base_warning oc base =
  fun
  [ BirthAfterDeath p ->
      fprintf oc "%s\n  born after his/her death\n" (designation base p)
  | IncoherentSex p fixed not_fixed ->
      do {
        fprintf oc "%s\n  sex not coherent with relations"
          (designation base p);
        if fixed > 0 then
          if not_fixed > 0 then
            fprintf oc " (fixed in %d of the %d cases)" fixed
              (fixed + not_fixed)
          else
            fprintf oc " (fixed)"
        else ();
        fprintf oc "\n";
      }
  | ChangedOrderOfChildren ifam des _ ->
      let cpl = coi base ifam in
      fprintf oc "Changed order of children of %s and %s\n"
        (designation base (poi base (father cpl)))
        (designation base (poi base (mother cpl)))
  | ChildrenNotInOrder ifam des elder x ->
      let cpl = coi base ifam in
      do {
        fprintf oc
          "The following children of\n  %s\nand\n  %s\nare not in order:\n"
          (designation base (poi base (father cpl)))
          (designation base (poi base (mother cpl)));
        fprintf oc "- %s\n" (designation base elder);
        fprintf oc "- %s\n" (designation base x)
      }
  | DeadTooEarlyToBeFather father child ->
      do {
        fprintf oc "%s\n" (designation base child);
        fprintf oc
          "  is born more than 2 years after the death of his/her father\n";
        fprintf oc "%s\n" (designation base father)
      }
  | MarriageDateAfterDeath p ->
      do {
        fprintf oc "%s\n" (designation base p);
        fprintf oc "married after his/her death\n"
      }
  | MarriageDateBeforeBirth p ->
      do {
        fprintf oc "%s\n" (designation base p);
        fprintf oc "married before his/her birth\n"
      }
  | MotherDeadAfterChildBirth mother child ->
      fprintf oc "%s\n  is born after the death of his/her mother\n%s\n"
        (designation base child) (designation base mother)
  | ParentBornAfterChild parent child ->
      fprintf oc "%s born after his/her child %s\n"
        (designation base parent) (designation base child)
  | ParentTooYoung p a ->
      fprintf oc "%s was parent at age of %d\n" (designation base p)
        (year_of a)
  | TitleDatesError p t ->
      do {
        fprintf oc "%s\n" (designation base p);
        fprintf oc "has incorrect title dates as:\n";
        fprintf oc "  %s %s\n" (sou base t.t_ident) (sou base t.t_place)
      }
  | UndefinedSex _ ->
      ()
  | YoungForMarriage p a ->
      fprintf oc "%s married at age %d\n" (designation base p) (year_of a) ]
;      

type stats =
  { men : mutable int;
    women : mutable int;
    neutre : mutable int;
    noname : mutable int;
    oldest_father : mutable (int * person);
    oldest_mother : mutable (int * person);
    youngest_father : mutable (int * person);
    youngest_mother : mutable (int * person);
    oldest_dead : mutable (int * person);
    oldest_still_alive : mutable (int * person) }
;

value birth_year p =
  match Adef.od_of_codate p.birth with
  [ Some d ->
      match d with
      [ Dgreg {year = y; prec = Sure} _ -> Some y
      | _ -> None ]
  | _ -> None ]
;

value death_year current_year p =
  match p.death with
  [ Death _ d ->
      match Adef.date_of_cdate d with
      [ Dgreg {year = y; prec = Sure} _ -> Some y
      | _ -> None ]
  | NotDead -> Some current_year
  | _ -> None ]
;

value update_stats base current_year s p =
  do {
    match p.sex with
    [ Male -> s.men := s.men + 1
    | Female -> s.women := s.women + 1
    | Neuter -> s.neutre := s.neutre + 1 ];
    if p_first_name base p = "?" && p_surname base p = "?" then
      s.noname := s.noname + 1
    else ();
    match (birth_year p, death_year current_year p) with
    [ (Some y1, Some y2) ->
        let age = y2 - y1 in
        do {
          if age > fst s.oldest_dead && p.death <> NotDead then
            s.oldest_dead := (age, p)
          else ();
          if age > fst s.oldest_still_alive && p.death = NotDead then
            s.oldest_still_alive := (age, p)
          else ();
        }
    | _ -> () ];
    match (birth_year p, parents (aoi base p.cle_index)) with
    [ (Some y2, Some ifam) ->
        let cpl = coi base ifam in
        do {
          match birth_year (poi base (father cpl)) with
          [ Some y1 ->
              let age = y2 - y1 in
              do {
                if age > fst s.oldest_father then
                  s.oldest_father := (age, poi base (father cpl))
                else ();
                if age < fst s.youngest_father then
                  s.youngest_father := (age, poi base (father cpl))
                else ();
              }
          | _ -> () ];
          match birth_year (poi base (mother cpl)) with
          [ Some y1 ->
              let age = y2 - y1 in
              do {
                if age > fst s.oldest_mother then
                  s.oldest_mother := (age, poi base (mother cpl))
                else ();
                if age < fst s.youngest_mother then
                  s.youngest_mother := (age, poi base (mother cpl))
                else ();
              }
          | _ -> () ];
          ()
        }
    | _ -> () ];
  }
;

value check_base_aux base error warning =
  do {
    Printf.eprintf "check persons\n";
    ConsangAll.start_progr_bar ();
    for i = 0 to base.data.persons.len - 1 do {
      ConsangAll.run_progr_bar i base.data.persons.len;
      let p = base.data.persons.get i in check_person base error warning p
    };
    ConsangAll.finish_progr_bar ();
    Printf.eprintf "check families\n";
    ConsangAll.start_progr_bar ();
    for i = 0 to base.data.families.len - 1 do {
      ConsangAll.run_progr_bar i base.data.families.len;
      let fam = base.data.families.get i in
      if is_deleted_family fam then ()
      else
        let cpl = base.data.couples.get i in
        let des = base.data.descends.get i in
        check_family base error warning fam cpl des
    };
    ConsangAll.finish_progr_bar ();
    check_noloop base error;
  }
;

value check_base base error warning def pr_stats =
  let s =
    let y = (1000, base.data.persons.get 0) in
    let o = (0, base.data.persons.get 0) in
    {men = 0; women = 0; neutre = 0; noname = 0; oldest_father = o;
     oldest_mother = o; youngest_father = y; youngest_mother = y;
     oldest_dead = o; oldest_still_alive = o}
  in
  let current_year = (Unix.localtime (Unix.time ())).Unix.tm_year + 1900 in
  do {
    check_base_aux base error warning;
    for i = 0 to base.data.persons.len - 1 do {
      let p = base.data.persons.get i in
      if not (def i) then
        printf "Undefined: %s\n" (designation base p)
      else ();
      if pr_stats then update_stats base current_year s p else ();
      flush stdout;
    };
    if pr_stats then do {
      printf "\n";
      printf "%d men\n" s.men;
      printf "%d women\n" s.women;
      printf "%d unknown sex\n" s.neutre;
      printf "%d unnamed\n" s.noname;
      printf "Oldest: %s, %d\n" (designation base (snd s.oldest_dead))
        (fst s.oldest_dead);
      printf "Oldest still alive: %s, %d\n"
        (designation base (snd s.oldest_still_alive))
        (fst s.oldest_still_alive);
      printf "Youngest father: %s, %d\n"
        (designation base (snd s.youngest_father)) (fst s.youngest_father);
      printf "Youngest mother: %s, %d\n"
        (designation base (snd s.youngest_mother)) (fst s.youngest_mother);
      printf "Oldest father: %s, %d\n"
        (designation base (snd s.oldest_father)) (fst s.oldest_father);
      printf "Oldest mother: %s, %d\n"
        (designation base (snd s.oldest_mother)) (fst s.oldest_mother);
      printf "\n";
      flush stdout;
    }
    else ();
  }
;
