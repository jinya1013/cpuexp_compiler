let loop_recur_dict = ref M.empty
exception WriteDictErr of string

type closure = { entry : Id.l; actual_fv : Id.t list } (* トップレベル関数のラベル, 自由変数のリスト *)
type t = (* クロージャ変換後の式 (caml2html: closure_t) *)
  | Unit of Syntax.pos
  | Int of int * Syntax.pos
  | Float of float * Syntax.pos
  | Neg of Id.t * Syntax.pos
  | Add of Id.t * Id.t * Syntax.pos
  | Sub of Id.t * Id.t * Syntax.pos
  | FNeg of Id.t * Syntax.pos
  | FSqrt of Id.t * Syntax.pos
  | Floor of Id.t * Syntax.pos
  | FAdd of Id.t * Id.t * Syntax.pos
  | FSub of Id.t * Id.t * Syntax.pos
  | FMul of Id.t * Id.t * Syntax.pos
  | FDiv of Id.t * Id.t * Syntax.pos
  | IfEq of Id.t * Id.t * t * t * Syntax.pos
  | IfLE of Id.t * Id.t * t * t * Syntax.pos
  | Let of (Id.t * Type.t) * t * t * Syntax.pos
  | Loop of (Id.t * Type.t) * t * t * Syntax.pos
  | Recur of Id.t * Syntax.pos
  | Var of Id.t * Syntax.pos
  | MakeCls of (Id.t * Type.t) * closure * t * Syntax.pos  (*(関数名, 関数の型), クロージャ, 関数の本体 *)
  | AppCls of Id.t * Id.t list * Syntax.pos
  | AppDir of Id.l * Id.t list * Syntax.pos
  | Tuple of Id.t list * Syntax.pos
  | LetTuple of (Id.t * Type.t) list * Id.t * t * Syntax.pos
  | Get of Id.t * Id.t * Syntax.pos
  | Put of Id.t * Id.t * Id.t * Syntax.pos
  | ExtArray of Id.l * Syntax.pos
type fundef = { name : Id.l * Type.t; (* 多分これはシンプルに関数の型 *)
                args : (Id.t * Type.t) list;
                formal_fv : (Id.t * Type.t) list;
                body : t }
type prog = Prog of fundef list * t

let pos_of_t = function
  | Unit (p) -> p
  | Int (_, p) -> p
  | Float (_, p) -> p
  | Neg (_, p) -> p
  | FNeg (_, p) | FSqrt(_, p) | Floor(_, p) -> p
  | Add (_, _, p) -> p
  | Sub (_, _, p) -> p
  | FAdd(_, _, p) -> p
  | FSub(_, _, p) -> p
  | FMul (_, _, p) -> p 
  | FDiv (_, _, p) -> p
  | IfEq (_, _, _,_, p) -> p
  | IfLE (_, _,_, _, p) -> p 
  | Let  (_, _,_, p) -> p
  | Loop  (_, _,_, p) -> p
  | Recur  (_, p) -> p
  | Var  (_, p) -> p
  | MakeCls(_, _, _, p) -> p
  | AppCls( _, _, p) -> p
  | AppDir(_, _, p) -> p
  | Tuple (_, p) -> p
  | LetTuple(_, _, _, p) -> p
  | Get (_, _, p) -> p
  | Put (_, _, _, p) -> p  
  | ExtArray(_, p) -> p

let rec write_dict loop_xt = function
  | Unit _ -> ()
  | Int _ -> ()
  | Float _ -> ()
  | Neg _ -> ()
  | Add _ -> ()
  | Sub _ -> ()
  | FNeg _ -> ()
  | FSqrt _ -> ()
  | Floor _ -> ()
  | FAdd _ -> ()
  | FSub _ -> ()
  | FMul _ -> ()
  | FDiv _ -> ()
  | IfEq(x, y, e1, e2, _) -> write_dict loop_xt e1; write_dict loop_xt e2;
  | IfLE(x, y, e1, e2, _) -> write_dict loop_xt e1; write_dict loop_xt e2;
  | Let((x, t), e1, e2, _) -> write_dict loop_xt e1; write_dict loop_xt e2;
  | Loop((x, t), e1, e2, _) -> write_dict loop_xt e1; write_dict (x, t) e2;
  | Recur(x, _) -> 
    if (fst loop_id) = "dummy" then (raise (WriteDictErr "Recur exp appears outside of the Loop exp."))
    else (loop_recur_dict := M.add x loop_xt !loop_recur_dict);
  | Var _ -> ()
  | MakeCls(xt, c, e, _) -> write_dict loop_xt e; (*(関数名, 関数の型), クロージャ, 関数の本体 *)
  | AppCls _ -> ()
  | AppDir _ -> ()
  | Tuple _ -> ()
  | LetTuple(xts, e1, e2) -> write_dict loop_xt e2;
  | Get _ -> ()
  | Put _ -> ()
  | ExtArray _ -> ()

(*
    式sを受け取り，自由変数のMapSを返す

    Args
        s : Closure.t
          式

    Returns
      retval: S.t
        Id.tの集合
*)
let rec fv = function
(* 
    与えられたクロージャ変換後の式cの中に含まれる自由変数のリストを出力する.

    Args
        c : Closure.t
          自由変数の変数を計算したいクロージャ変換後の式

    Returns
        retval : S.t
          cが含む自由変数の集合            
*)
  | Unit(_) | Int(_) | Float(_) | ExtArray(_) -> S.empty
  | Neg(x, _) | FNeg(x, _) | FSqrt(x, _) | Floor(x, _) -> S.singleton x
  | Add(x, y, _) | Sub(x, y, _) | FAdd(x, y, _) | FSub(x, y, _) | FMul(x, y, _) | FDiv(x, y, _) | Get(x, y, _) -> S.of_list [x; y]
  | IfEq(x, y, e1, e2, _)| IfLE(x, y, e1, e2, _) -> S.add x (S.add y (S.union (fv e1) (fv e2)))
  | Let((x, t), e1, e2, _) -> S.union (fv e1) (S.remove x (fv e2))
  | Loop((x, t), e1, e2, _) -> S.union (fv e1) (S.remove x (fv e2))
  | Recur(x, _) -> S.singleton x
  | Var(x, _) -> S.singleton x
  | MakeCls((x, t), { entry = l; actual_fv = ys }, e, _) -> S.remove x (S.union (S.of_list ys) (fv e))
  | AppCls(x, ys, _) -> S.of_list (x :: ys)
  | AppDir(_, xs, _) | Tuple(xs, _) -> S.of_list xs
  | LetTuple(xts, y, e, _) -> S.add y (S.diff (fv e) (S.of_list (List.map fst xts)))
  | Put(x, y, z, _) -> S.of_list [x; y; z]

let toplevel : fundef list ref = ref []

(*
    与えられた式s中の関数定義について，トップレベルに持っていけないないものはクロージャーとして
    処理を行う．この際，関数定義は変数として参照されうるため，すぐにクロージャーとしては判定できない
    関数適用については，knownの中を探し，クロージャーの適用かそうでないかを区別する

    Args
        env : Id.t * Type.t list
          変数名と型の環境
        known : Id.t list
          自由変数を使わない関数の集合
        s : KNormal.t
          式
    
    Returns
        retval = Closure.t
          クロージャー返還後の式
*)
let rec g env known = function (* クロージャ変換ルーチン本体 (caml2html: closure_g) *)
(* 
    環境envと自由変数がないとわかっている関数の集合known, K正規化後の式kを受け取ってそれをクロージャ変換する.

    Args
        env : M.t
          現在の変数名と,その型のマッピング
        known : S.t
          自由変数を持たないことがわかっているトップレベル関数の集合

        k : KNormal.t
          変換したいK正規化後の式

    Returns
        retval : Closure.t
          クロージャ変換後の式   

*)
  | KNormal.Unit(p) -> Unit(p)
  | KNormal.Int(i, p) -> Int(i, p)
  | KNormal.Float(d, p) -> Float(d, p)
  | KNormal.Neg(x, p) -> Neg(x, p)
  | KNormal.Add(x, y, p) -> Add(x, y, p)
  | KNormal.Sub(x, y, p) -> Sub(x, y, p)
  | KNormal.FNeg(x, p) -> FNeg(x, p)
  | KNormal.FSqrt(x, p) -> FSqrt(x, p)
  | KNormal.Floor(x, p) -> Floor(x, p)
  | KNormal.FAdd(x, y, p) -> FAdd(x, y, p)
  | KNormal.FSub(x, y, p) -> FSub(x, y, p)
  | KNormal.FMul(x, y, p) -> FMul(x, y, p)
  | KNormal.FDiv(x, y, p) -> FDiv(x, y, p)
  | KNormal.IfEq(x, y, e1, e2, p) -> IfEq(x, y, g env known e1, g env known e2, p)
  | KNormal.IfLE(x, y, e1, e2, p) -> IfLE(x, y, g env known e1, g env known e2, p)
  | KNormal.Let((x, t), e1, e2, p) -> Let((x, t), g env known e1, g (M.add x t env) known e2, p)
  | KNormal.Loop((x, t), e1, e2, p) -> Loop((x, t), g env known e1, g (M.add x t env) known e2, p)
  | KNormal.Recur(x, p) -> Recur(x, p)
  | KNormal.Var(x, p) -> Var(x, p)
  | KNormal.LetRec({ KNormal.name = (x, t); KNormal.args = yts; KNormal.body = e1 }, e2, p) -> (* 関数定義の場合 (caml2html: closure_letrec) *)
      (* 関数定義let rec x y1 ... yn = e1 in e2の場合は、
         xに自由変数がない(closureを介さずdirectに呼び出せる)
         と仮定し、knownに追加してe1をクロージャ変換してみる *)
      let toplevel_backup = !toplevel in (* 試しにクロージャ変換するので, ダメだったらやり直すためのバックアップ *)
      let env' = M.add x t env in (* 変数xと型tの関係を環境に追加 *)
      let known' = S.add x known in (* とりあえず、クロージャがないとわかっている関数の集合にxを追加する *)
      let e1' = g (M.add_list yts env') known' e1 in (* 引数の集合を環境に加えた下で, e1'を評価する *)
      (* 本当に自由変数がなかったか、変換結果e1'を確認する *)
      (* 注意: e1'にx自身が変数として出現する場合はclosureが必要!
         (thanks to nuevo-namasute and azounoman; test/cls-bug2.ml参照) *)
      let zs = S.diff (fv e1') (S.of_list (List.map fst yts)) in (* e1'の自由変数と関数の引数のdiffをとる *)
      let known', e1' =
        if S.is_empty zs then known', e1' else (* 差分が空ならそのままでOK *)
        (* e1に自由変数が含まれるなら状態(toplevelの値)を戻して、クロージャ変換をやり直す *)
        (Format.eprintf "free variable(s) %s found in function %s@." (Id.pp_list (S.elements zs)) x;
         Format.eprintf "function %s cannot be directly applied in fact@." x;
         toplevel := toplevel_backup; (* バックアップによって復元 *)
         let e1' = g (M.add_list yts env') known e1 in (* 引数も環境に追加して, e1を評価 *)
         known, e1') in
      let zs = S.elements (S.diff (fv e1') (S.add x (S.of_list (List.map fst yts)))) in (* 自由変数のリスト *)
      let zts = List.map (fun z -> (z, M.find z env')) zs in (* ここで自由変数zの型を引くために引数envが必要 *)
      toplevel := { name = (Id.L(x), t); args = yts; formal_fv = zts; body = e1' } :: !toplevel; (* トップレベル関数を追加 *)
      let e2' = g env' known' e2 in
      if S.mem x (fv e2') then (* xが変数としてe2'に出現するか *)
        MakeCls((x, t), { entry = Id.L(x); actual_fv = zs }, e2', p) (* 出現していたら削除しない *)
      else
        (Format.eprintf "eliminating closure(s) %s@." x;
         e2') (* 出現しなければMakeClsを削除 *)
  | KNormal.App(x, ys, p) when S.mem x known -> (* 関数適用の場合 (caml2html: closure_app) *)
      Format.eprintf "directly applying %s@." x;
      AppDir(Id.L(x), ys, p)
  | KNormal.App(f, xs, p) -> AppCls(f, xs, p)
  | KNormal.Tuple(xs, p) -> Tuple(xs, p)
  | KNormal.LetTuple(xts, y, e, p) -> LetTuple(xts, y, g (M.add_list xts env) known e, p)
  | KNormal.Get(x, y, p) -> Get(x, y, p)
  | KNormal.Put(x, y, z, p) -> Put(x, y, z, p)
  | KNormal.ExtArray(x, p) -> ExtArray(Id.L(x), p)
  | KNormal.ExtFunApp(x, ys, p) -> 
      AppDir(Id.L("min_caml_" ^ x), ys, p)

(*
  処理の主要部分．toplevelは関数定義の集合
*)
let f e =
(*
  モジュール内の変数toplevelを空リストで初期化して, Closure.gを呼ぶ.
  この空リストはトップレベル関数を記録するのに使われる.

  Args
    e : KNormal.t
    変換前の式(プログラム)

  Returns
    retval : Closure.plog
      変換後のプログラム(トップレベル関数のリストと変換後の式の組) 
*)
  toplevel := [];
  let e' = g M.empty S.empty e in
  List.iter (fun { name = (l, t); args = xts; formal_fv = yts; body = e } -> write_dict ("dummy", Type.Unit) e) !toplevel;
  write_dict ("dummy", Type.Unit) e';
  Prog(List.rev !toplevel, e')

let rec output_closure outchan e depth = 
(* 
    与えられた正規化後の式kをチャネルoutchanに出力する.

    Args
        outchan : out_channel
          出力先のチャンネル
        e : Closure.t
          出力するクロージャ変換後の式
        depth : int
          構文解析木の深さ

    Returns
        retval : unit
          なし            
*)
  match e with
  | Unit(p) -> 
  (
    Id.output_tab2 outchan (depth + 1) p
  )
  | Int (i, p) -> 
  (
    Id.output_tab2 outchan depth p;
    output_string outchan ("INT " ^ (string_of_int i))
  )
  | Float (f, p) -> 
  (
    Id.output_tab2 outchan depth p;
    output_string outchan ("FLOAT " ^ (string_of_float f))
  )
  | Neg (t, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "NEG ";
    Id.output_id outchan t;
  )
  | Add (t1, t2, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "ADD ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
  )
  | Sub (t1, t2, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "SUB ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
  )
  | FNeg (t, p) -> 
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "FNEG ";
    Id.output_id outchan t;
  )
  | FSqrt (t, p) -> 
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "FSQRT ";
    Id.output_id outchan t;
  )
  | Floor (t, p) -> 
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "Floor ";
    Id.output_id outchan t;
  )
  | FAdd (t1, t2, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "FADD ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
  )
  | FSub (t1, t2, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "FSUB ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
  )
  | FMul (t1, t2, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "FMUL ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
  )
  | FDiv (t1, t2, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "FDIV ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
  )
  | IfEq (t1, t2, t3, t4, p) -> (* 比較 + 分岐 (caml2html: knormal_branch) *)
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "IFEQ ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
    output_closure outchan t3 (depth + 1);
    output_closure outchan t4 (depth + 1);
  )
  | IfLE (t1, t2, t3, t4, p) -> (* 比較 + 分岐 (caml2html: knormal_branch) *)
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "IFLE ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
    output_closure outchan t3 (depth + 1);
    output_closure outchan t4 (depth + 1);
  )
  | Let (t1, t2, t3, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "LET ";
    Id.output_id outchan (fst t1);
    output_closure outchan t2 (depth + 1);
    output_closure outchan t3 (depth + 1);
  )
  | Loop (t1, t2, t3, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "LOOP ";
    Id.output_id outchan (fst t1);
    output_closure outchan t2 (depth + 1);
    output_closure outchan t3 (depth + 1);
  )
  | Recur (x, p) -> 
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "RECUR ";
    Id.output_id outchan x;
  )
  | Var (x, p) -> 
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "VAR ";
    Id.output_id outchan x;
  )
  | MakeCls ((funname, funtype), funclosure, funbody, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "MAKECLS";
    Id.output_tab2 outchan depth p;
    output_string outchan "{";
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "funname = ";
    Id.output_id outchan funname;
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "funtype = ";
    Type.output_type outchan funtype;
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "funclosure = ";
    output_funclosure outchan funclosure;
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "funcbody =";
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "{";
    output_closure outchan funbody (depth + 2);
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "}";
    Id.output_tab2 outchan depth p;
    output_string outchan "}";
  )
  | AppCls (funname, funargs, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "APPCLS ";
    Id.output_id outchan funname;
    output_string outchan " "; 
    Id.output_id_list outchan funargs;
  )
  | AppDir (funlabel, funargs, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "APPDIR ";
    Id.output_label outchan funlabel;
    output_string outchan " "; 
    Id.output_id_list outchan funargs;
  )
  | Tuple (ts, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "(";
    Id.output_id_list outchan ts;
    output_string outchan ")"
  )
  | LetTuple (t1s, t2, t3, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "LET ";
    output_string outchan "(";
    Id.output_id_list outchan (fst (List.split t1s));
    output_string outchan ")";
    output_string outchan " ";
    Id.output_id outchan t2;
    output_closure outchan t3 (depth + 1);
  )
  | Get (t1, t2, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "GET ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
  )
  | Put (t1, t2, t3, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "PUT ";
    Id.output_id outchan t1;
    output_string outchan " ";
    Id.output_id outchan t2;
    output_string outchan " ";
    Id.output_id outchan t3;
  )
  | ExtArray (t, p) ->
  (
    Id.output_tab2 outchan depth p;
    output_string outchan "EXTARRAY ";
    Id.output_label outchan t;
  )

and output_funclosure outchan { entry = funlabel; actual_fv = funfv } = 
    output_string outchan "{ entry : ";
    Id.output_label outchan funlabel;
    output_string outchan " , actual_fv : ";
    Id.output_id_list outchan funfv;
    output_string outchan " }";

and output_fundef outchan { name = funname; args = funargs; formal_fv = funfv; body = funbody } depth = 
    let p = pos_of_t funbody in
    Id.output_tab2 outchan depth p;
    output_string outchan "{";
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "name : ";
    Id.output_label outchan (fst(funname));
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "args : ";
    Id.output_id_list outchan (fst (List.split funargs));
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "formal_fv : ";
    Id.output_id_list outchan (fst (List.split funfv));
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "body :";
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "{";
    output_closure outchan funbody (depth + 2);
    Id.output_tab2 outchan (depth + 1) p;
    output_string outchan "}";
    Id.output_tab2 outchan depth p;
    output_string outchan "}";

and output_fundef_list outchan ds depth = 
  let f d =
      output_fundef outchan d depth
  in List.iter f ds;

and output_prog outchan (Prog (top, e)) = 
  output_string outchan (" \t");
  output_string outchan "TOPLEVEL";
  output_fundef_list outchan top 1;
  Id.output_tab2 outchan 0 (-1);
  output_string outchan "MAIN";
  output_closure outchan e 1;
  output_string outchan "\n";