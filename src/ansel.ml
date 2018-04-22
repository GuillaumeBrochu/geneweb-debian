(* $Id: ansel.ml,v 5.3 2007-01-19 01:53:16 ddr Exp $ *)
(* Copyright (c) 1998-2007 INRIA *)

value no_accent =
  fun
  [ '�' | '�' | '�' | '�' | '�' | '�' -> 'a'
  | '�' -> 'c'
  | '�' | '�' | '�' | '�' -> 'e'
  | '�' | '�' | '�' | '�' -> 'i'
  | '�' -> 'n'
  | '�' | '�' | '�' | '�' | '�' | '�' -> 'o'
  | '�' | '�' | '�' | '�' -> 'u'
  | '�' | '�' -> 'y'
  | '�' | '�' | '�' | '�' | '�' | '�' -> 'A'
  | '�' -> 'C'
  | '�' | '�' | '�' | '�' -> 'E'
  | '�' | '�' | '�' | '�' -> 'I'
  | '�' -> 'N'
  | '�' | '�' | '�' | '�' | '�' | '�' -> 'O'
  | '�' | '�' | '�' | '�' -> 'U'
  | '�' -> 'Y'
  | c -> c ]
;

value accent_code =
  fun
    [ '�' | '�' | '�' | '�' | '�'
    | '�' | '�' | '�' | '�' | '�' -> 255
    | '�' | '�' | '�' | '�' | '�' | '�'
    | '�' | '�' | '�' | '�' | '�' | '�' -> 226
    | '�' | '�' | '�' | '�' | '�'
    | '�' | '�' | '�' | '�' | '�' -> 227
    | '�' | '�' | '�' | '�' | '�' | '�' -> 228
    | '�' | '�' | '�' | '�' | '�'
    | '�' | '�' | '�' | '�' | '�' | '�' -> 232
    | '�' | '�' -> 234
    | '�' | '�' -> 240
    | '�' -> 162
    | '�' -> 178
    | '�' -> 207
    | _ -> 0 ]
;

value of_iso_8859_1 s =
  let (len, identical) =
    loop 0 0 True where rec loop i len identical =
      if i = String.length s then (len, identical)
      else
        match s.[i] with
        [ '�'..'�' | '�'.. '�' | '�'..'�' | '�'..'�'
        | '�'..'�' | '�'.. '�' | '�'..'�' | '�'..'�' | '�' ->
            loop (i + 1) (len + 2) False
        | '�' | '�' | '�' -> loop (i + 1) (len + 1) False
        | _ -> loop (i + 1) (len + 1) identical ]
  in
  if identical then s
  else
    let s' = Bytes.create len in
    loop 0 0 where rec loop i i' =
      if i = String.length s then Bytes.unsafe_to_string s'
      else
        let i' =
          let a = accent_code s.[i] in
          if a > 0 then do {
            Bytes.set s' i' (Char.chr a);
            let n = no_accent s.[i] in
            if n = s.[i] then i'
            else do { Bytes.set s' (i'+1) n; i'+1 }
          } else do { Bytes.set s' i' s.[i]; i' } 
        in
        loop (i + 1) (i' + 1)
;

value grave =
  fun
  [ 'a' -> '�'
  | 'e' -> '�'
  | 'i' -> '�'
  | 'o' -> '�'
  | 'u' -> '�'
  | 'A' -> '�'
  | 'E' -> '�'
  | 'I' -> '�'
  | 'O' -> '�'
  | 'U' -> '�'
  | x -> x ]
;

value acute =
  fun
  [ 'a' -> '�'
  | 'e' -> '�'
  | 'i' -> '�'
  | 'o' -> '�'
  | 'u' -> '�'
  | 'y' -> '�'
  | 'A' -> '�'
  | 'E' -> '�'
  | 'I' -> '�'
  | 'O' -> '�'
  | 'U' -> '�'
  | 'Y' -> '�'
  | x -> x ]
;

value circum =
  fun
  [ 'a' -> '�'
  | 'e' -> '�'
  | 'i' -> '�'
  | 'o' -> '�'
  | 'u' -> '�'
  | 'A' -> '�'
  | 'E' -> '�'
  | 'I' -> '�'
  | 'O' -> '�'
  | 'U' -> '�'
  | x -> x ]
;

value uml =
  fun
  [ 'a' -> '�'
  | 'e' -> '�'
  | 'i' -> '�'
  | 'o' -> '�'
  | 'u' -> '�'
  | 'y' -> '�'
  | 'A' -> '�'
  | 'E' -> '�'
  | 'I' -> '�'
  | 'O' -> '�'
  | 'U' -> '�'
  | x -> x ]
;

value circle =
  fun
  [ 'a' -> '�'
  | 'A' -> '�'
  | x -> x ]
;

value tilde =
  fun
  [ 'a' -> '�'
  | 'n' -> '�'
  | 'o' -> '�'
  | 'A' -> '�'
  | 'N' -> '�'
  | 'O' -> '�'
  | x -> x ]
;

value cedil =
  fun
  [ 'c' -> '�'
  | 'C' -> '�'
  | x -> x ]
;

value to_iso_8859_1 s =
  let (len, identical) =
    loop 0 0 True where rec loop i len identical =
      if i = String.length s then (len, identical)
      else if i = String.length s - 1 then (len + 1, identical)
      else
        match Char.code s.[i] with
        [ 225 | 226 | 227 | 228 | 232 | 234 | 240 ->
            loop (i + 2) (len + 1) False
        | 162 | 178 | 207 -> loop (i + 1) (len + 1) False
        | _ -> loop (i + 1) (len + 1) identical]
  in
  if identical then s
  else
    let s' = Bytes.create len in
    loop 0 0 where rec loop i i' =
      if i = String.length s then Bytes.unsafe_to_string s'
      else if i = String.length s - 1 then
        do { Bytes.set s' i' s.[i]; Bytes.unsafe_to_string s' }
      else
        let (c, i) =
          match Char.code s.[i] with
          [ 162 -> ('�', i)
          | 178 -> ('�', i)
          | 207 -> ('�', i)
          | 225 -> (grave s.[i+1], i + 1)
          | 226 -> (acute s.[i+1], i + 1)
          | 227 -> (circum s.[i+1], i + 1)
          | 228 -> (tilde s.[i+1], i + 1)
          | 232 -> (uml s.[i+1], i + 1)
          | 234 -> (circle s.[i+1], i + 1)
          | 240 -> (cedil s.[i+1], i + 1)
          | _ -> (s.[i], i) ]
        in
        do { Bytes.set s' i' c;
             loop (i + 1) (i' + 1) }
;
