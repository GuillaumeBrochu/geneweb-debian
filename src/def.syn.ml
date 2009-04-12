(* camlp4r pa_extend.cmo q_MLast.cmo *)
(* $Id: def.syn.ml,v 4.2 2004/12/14 09:30:11 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Pcaml;

EXTEND
  expr: BEFORE "<"
    [ [ x = expr; "strictly_before"; y = expr ->
          <:expr< strictly_before $x$ $y$ >>
      | x = expr; "strictly_after"; y = expr ->
          <:expr< strictly_after $x$ $y$ >>
      | x = expr; "avant"; y = expr ->
          <:expr< not (strictly_after $x$ $y$) >>
      | x = expr; "apres"; y = expr ->
          <:expr< not (strictly_before $x$ $y$) >> ] ];
END;
