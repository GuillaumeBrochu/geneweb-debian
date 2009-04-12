(* $Id: select.ml,v 4.11 2004/12/14 09:30:17 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Def;
open Gutil;

value is_censored_person threshold p =
  match Adef.od_of_codate p.birth with
  [ Some date ->
      match date with
      [ Dgreg dmy _ -> dmy.year >= threshold && p.access != Public
      | _ -> False ]
  | None -> False ]
;

value is_censored_couple base threshold cpl =
  let fath = poi base (father cpl) in
  let moth = poi base (mother cpl) in
  is_censored_person threshold fath || is_censored_person threshold moth
;

value censor_person base per_tab fam_tab flag threshold p no_check =
  let ps = base.data.persons.get p in
  if no_check || is_censored_person threshold ps then
    per_tab.(p) := per_tab.(p) lor flag
  else ()
;

value rec censor_family base per_tab fam_tab flag threshold i no_check =
  let censor_unions p =
    let uni = base.data.unions.get p in
    Array.iter
      (fun ifam ->
         let f = Adef.int_of_ifam ifam in
         do {
           censor_family base per_tab fam_tab flag threshold f True;
           censor_person base per_tab fam_tab flag threshold p True
         })
      uni.family
  in
  let censor_descendants f =
    let des = base.data.descends.get f in
    Array.iter
      (fun iper ->
         let ip = Adef.int_of_iper iper in
         if per_tab.(ip) <> 0 then () else censor_unions ip)
      des.children
  in
  let all_families_censored p =
    let uni = base.data.unions.get p in
    Array.fold_left
      (fun check ifam -> fam_tab.(Adef.int_of_ifam ifam) = 0 && check) True
      uni.family
  in
  let censor_spouse iper =
    let p = Adef.int_of_iper iper in
    if all_families_censored p then per_tab.(p) := per_tab.(p) lor flag
    else ()
  in
  if fam_tab.(i) <> 0 then ()
  else
    let fam = base.data.families.get i in
    if is_deleted_family fam then ()
    else
      let cpl = base.data.couples.get i in
      if no_check || is_censored_couple base threshold cpl then do {
        fam_tab.(i) := fam_tab.(i) lor flag;
        censor_spouse (father cpl);
        censor_spouse (mother cpl);
        censor_descendants i
      }
      else ()
;

value censor_base base per_tab fam_tab flag threshold =
  do {
    for i = 0 to base.data.families.len - 1 do {
      censor_family base per_tab fam_tab flag threshold i False
    };
    for i = 0 to base.data.persons.len - 1 do {
      censor_person base per_tab fam_tab flag threshold i False
    }
  }
;

value restrict_base base per_tab fam_tab flag =
  do {
    for i = 0 to base.data.persons.len - 1 do {
      let fct p = False in
      if base.data.visible.v_get fct i then
        let _ = per_tab.(i) := per_tab.(i) lor flag in ()
      else ()
    };
    for i = 0 to base.data.families.len - 1 do {
      let des = base.data.descends.get i in
      let cpl = base.data.couples.get i in
      let des_visible =
        Array.fold_left
          (fun check iper -> check || per_tab.(Adef.int_of_iper iper) = 0)
          False des.children
      in
      let cpl_not_visible =
        per_tab.(Adef.int_of_iper (father cpl)) <> 0 ||
        per_tab.(Adef.int_of_iper (mother cpl)) <> 0
      in
      if not des_visible && cpl_not_visible then
        let _ = fam_tab.(i) := fam_tab.(i) lor flag in ()
      else ();
    }
  }
;

value flag_family base per_tab fam_tab flag ifam =
  let i = Adef.int_of_ifam ifam in
  let cpl = coi base ifam in
  do {
    fam_tab.(i) := fam_tab.(i) lor flag;
    let i = Adef.int_of_iper (father cpl) in
    per_tab.(i) := per_tab.(i) lor flag;
    let i = Adef.int_of_iper (mother cpl) in
    per_tab.(i) := per_tab.(i) lor flag
  }
;

value select_ancestors base per_tab fam_tab with_siblings flag iper =
  let rec add_ancestors iper =
    let i = Adef.int_of_iper iper in
    if per_tab.(i) land flag <> 0 then ()
    else do {
      per_tab.(i) := per_tab.(i) lor flag;
      match parents (aoi base iper) with
      [ Some ifam ->
          let i = Adef.int_of_ifam ifam in
          if fam_tab.(i) land flag <> 0 then ()
          else do {
            fam_tab.(i) := fam_tab.(i) lor flag;
            let cpl = coi base ifam in
            add_ancestors (father cpl);
            add_ancestors (mother cpl)
          }
      | None -> () ]
    }
  in
  do {
    add_ancestors iper;
    if with_siblings then do {
      let add_sibling_spouse_parents ip =
        match parents (aoi base ip) with
        [ Some ifam -> flag_family base per_tab fam_tab flag ifam
        | None -> () ]
      in
      let add_siblings_marriages ifam =
        let des = doi base ifam in
        Array.iter
          (fun ip ->
             let i = Adef.int_of_iper ip in
             do {
               per_tab.(i) := per_tab.(i) lor flag;
               Array.iter
                 (fun ifam ->
                    let i = Adef.int_of_ifam ifam in
                    let cpl = coi base ifam in
                    do {
                      fam_tab.(i) := fam_tab.(i) lor flag;
                      List.iter
                        (fun ip ->
                           let i = Adef.int_of_iper ip in
                           do {
                             per_tab.(i) := per_tab.(i) lor flag;
                             add_sibling_spouse_parents ip;
                             ()
                           })
                        [(father cpl); (mother cpl)]
                    })
                 (uoi base ip).family
             })
          des.children
      in
      let add_siblings iparent =
        Array.iter
          (fun ifam ->
             do {
               flag_family base per_tab fam_tab flag ifam;
               add_siblings_marriages ifam
             })
          (uoi base iparent).family
      in
      let anc_flag = 4 in
      let rec ancestors_loop iper =
        let i = Adef.int_of_iper iper in
        if per_tab.(i) land anc_flag <> 0 then ()
        else do {
          per_tab.(i) := per_tab.(i) lor anc_flag;
          match parents (aoi base iper) with
          [ Some ifam ->
              let i = Adef.int_of_ifam ifam in
              if fam_tab.(i) land anc_flag <> 0 then ()
              else do {
                fam_tab.(i) := fam_tab.(i) lor anc_flag;
                let cpl = coi base ifam in
                add_siblings (father cpl);
                add_siblings (mother cpl);
                ancestors_loop (father cpl);
                ancestors_loop (mother cpl)
              }
          | None -> () ]
        }
      in
      let rec remove_anc_flag iper =
        let i = Adef.int_of_iper iper in
        if per_tab.(i) land anc_flag <> 0 then do {
          per_tab.(i) := per_tab.(i) land lnot anc_flag;
          match parents (aoi base iper) with
          [ Some ifam ->
              let i = Adef.int_of_ifam ifam in
              if fam_tab.(i) land anc_flag <> 0 then do {
                fam_tab.(i) := fam_tab.(i) land lnot anc_flag;
                let cpl = coi base ifam in
                remove_anc_flag (father cpl);
                remove_anc_flag (mother cpl)
              }
              else ()
          | None -> () ]
        }
        else ()
      in
      ancestors_loop iper;
      remove_anc_flag iper
    }
    else ()
  }
;

value select_descendants
  base per_tab fam_tab no_spouses_parents flag iper maxlev
=
  let mark = Array.create base.data.families.len False in
  let select_family ifam cpl =
    let i = Adef.int_of_ifam ifam in
    do {
      fam_tab.(i) := fam_tab.(i) lor flag;
      let i = Adef.int_of_iper (father cpl) in
      per_tab.(i) := per_tab.(i) lor flag;
      let i = Adef.int_of_iper (mother cpl) in
      per_tab.(i) := per_tab.(i) lor flag
    }
  in
  let rec loop lev iper =
    if maxlev >= 0 && lev > maxlev then ()
    else
      let i = Adef.int_of_iper iper in
      do {
        per_tab.(i) := per_tab.(i) lor flag;
        Array.iter
          (fun ifam ->
             let i = Adef.int_of_ifam ifam in
             if mark.(i) then ()
             else do {
               let cpl = coi base ifam in
               mark.(i) := True;
               select_family ifam cpl;
               if not no_spouses_parents then
                 let sp = spouse iper cpl in
                 match parents (aoi base sp) with
                 [ Some ifam -> select_family ifam (coi base ifam)
                 | None -> () ]
               else ();
               Array.iter (loop (succ lev)) (doi base ifam).children
             })
          (uoi base iper).family
      }
  in
  loop 0 iper
;

value select_descendants_ancestors base per_tab fam_tab no_spouses_parents ip =
  let new_mark = let r = ref 0 in fun () -> do { incr r; r.val } in
  let tab = Array.create base.data.persons.len (new_mark ()) in
  let anc_mark = new_mark () in
  let anclist =
    loop [] ip where rec loop list ip =
      if tab.(Adef.int_of_iper ip) = anc_mark then list
      else do {
        tab.(Adef.int_of_iper ip) := anc_mark;
        match parents (aoi base ip) with
        [ Some ifam ->
            let cpl = coi base ifam in
            let list = loop list (father cpl) in
            loop list (mother cpl)
        | None ->
            [ip :: list] ]
      }
  in
  let des_mark = new_mark () in
  List.iter
    (fun ip ->
       loop ip where rec loop ip =
         if tab.(Adef.int_of_iper ip) = des_mark then ()
         else do {
           let u = uoi base ip in
           for i = 0 to Array.length u.family - 1 do {
             let ifam = u.family.(i) in
             fam_tab.(Adef.int_of_ifam ifam) :=
               fam_tab.(Adef.int_of_ifam ifam) lor 1;
             let des = doi base ifam in
             for i = 0 to Array.length des.children - 1 do {
               loop des.children.(i);
             };
           };
           tab.(Adef.int_of_iper ip) := des_mark;
           per_tab.(Adef.int_of_iper ip) :=
             per_tab.(Adef.int_of_iper ip) lor 1;
         })
    anclist
;

value select_surname base per_tab fam_tab no_spouses_parents surname =
  let surname = Name.strip_lower surname in
  for i = 0 to base.data.families.len - 1 do {
    let fam = base.data.families.get i in
    let cpl = base.data.couples.get i in
    if is_deleted_family fam then ()
    else
      let des = base.data.descends.get i in
      let fath = poi base (father cpl) in
      let moth = poi base (mother cpl) in
      if Name.strip_lower (sou base fath.surname) = surname ||
         Name.strip_lower (sou base moth.surname) = surname
      then do {
        fam_tab.(i) := True;
        per_tab.(Adef.int_of_iper (father cpl)) := True;
        per_tab.(Adef.int_of_iper (mother cpl)) := True;
        Array.iter
          (fun ic ->
             let p = poi base ic in
             if not per_tab.(Adef.int_of_iper ic) &&
                Name.strip_lower (sou base p.surname) = surname
             then
               per_tab.(Adef.int_of_iper ic) := True
             else ())
          des.children;
        if no_spouses_parents then ()
        else
          List.iter
            (fun x ->
               match parents (aoi base x) with
               [ Some ifam when not fam_tab.(Adef.int_of_ifam ifam) ->
                   let cpl = coi base ifam in
                   do {
                     fam_tab.(Adef.int_of_ifam ifam) := True;
                     per_tab.(Adef.int_of_iper (father cpl)) := True;
                     per_tab.(Adef.int_of_iper (mother cpl)) := True
                   }
               | _ -> () ])
            [(father cpl); (mother cpl)]
      }
      else ()
  }
;

value select_ancestors_descendants base anc desc ancdesc no_spouses_parents
    censor with_siblings maxlev =
  let tm = Unix.localtime (Unix.time ()) in
  let threshold = 1900 + tm.Unix.tm_year - censor in
  match (anc, desc, ancdesc) with
  [ (None, None, None) ->
      if censor <> 0 || censor == -1 then
        let per_tab = Array.create base.data.persons.len 0 in
        let fam_tab = Array.create base.data.families.len 0 in
        let _ =
          if censor == -1 then restrict_base base per_tab fam_tab 1      
          else censor_base base per_tab fam_tab 1 threshold
        in
        (fun i -> per_tab.(Adef.int_of_iper i) == 0,
         fun i -> fam_tab.(Adef.int_of_ifam i) == 0)
      else (fun _ -> True, fun _ -> True)
  | (None, None, Some iadper) ->
      let per_tab = Array.create base.data.persons.len 0 in
      let fam_tab = Array.create base.data.families.len 0 in
      let _ =
        if censor == -1 then restrict_base base per_tab fam_tab 4
        else if censor <> 0 then censor_base base per_tab fam_tab 4 threshold
        else ()
      in
      do {
        select_descendants_ancestors base per_tab fam_tab no_spouses_parents
          iadper;
        (fun i ->
           let fl = per_tab.(Adef.int_of_iper i) in
           fl < 4 && fl > 0,
         fun i ->
           let fl = fam_tab.(Adef.int_of_ifam i) in
           fl < 4 && fl > 0)
      }
  | _ ->
      let per_tab = Array.create base.data.persons.len 0 in
      let fam_tab = Array.create base.data.families.len 0 in
      let _ =
        if censor == -1 then restrict_base base per_tab fam_tab 4
        else if censor <> 0 then censor_base base per_tab fam_tab 4 threshold
        else ()
      in
      match (anc, desc) with
      [ (Some iaper, None) ->
          do {
            select_ancestors base per_tab fam_tab with_siblings 1 iaper;
            (fun i -> per_tab.(Adef.int_of_iper i) == 1,
             fun i -> fam_tab.(Adef.int_of_ifam i) == 1)
          }
      | (None, Some idper) ->
          do {
            select_descendants base per_tab fam_tab no_spouses_parents 1
              idper maxlev;
            (fun i -> per_tab.(Adef.int_of_iper i) == 1,
             fun i -> fam_tab.(Adef.int_of_ifam i) == 1)
          }
      | (Some iaper, Some idper) ->
          do {
            select_ancestors base per_tab fam_tab False 1 iaper;
            select_descendants base per_tab fam_tab no_spouses_parents 2
              idper maxlev;
            (fun i -> per_tab.(Adef.int_of_iper i) == 3,
             fun i -> fam_tab.(Adef.int_of_ifam i) == 3)
          }
      | _ -> assert False ] ]
;

value select_surnames base surnames no_spouses_parents =
  let per_tab = Array.create base.data.persons.len False in
  let fam_tab = Array.create base.data.families.len False in
  do {
    List.iter (select_surname base per_tab fam_tab no_spouses_parents)
      surnames;
    (fun i -> per_tab.(Adef.int_of_iper i),
     fun i -> fam_tab.(Adef.int_of_ifam i))
  }
;

value functions
    base anc desc surnames ancdesc no_spouses_parents censor with_siblings
    maxlev =
  let (per_sel1, fam_sel1) =
    select_ancestors_descendants base anc desc ancdesc no_spouses_parents
      censor with_siblings maxlev
  in
  let (per_sel2, fam_sel2) =
    select_surnames base surnames no_spouses_parents
  in
  match (censor, anc, desc, ancdesc, surnames) with
  [ (0, None, None, None, [_ :: _]) -> (per_sel2, fam_sel2)
  | (_, _, _, _, []) -> (per_sel1, fam_sel1)
  | (0, _, _, _, _) ->
      (fun i -> per_sel1 i || per_sel2 i,
       fun i -> fam_sel1 i || fam_sel2 i)
  | _ ->
      (fun i -> per_sel1 i && per_sel2 i,
       fun i -> fam_sel1 i && fam_sel2 i) ]
;
