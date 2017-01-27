fromList [("Bool",TyAlg "Bool" [("True",-5,TyConApp "Bool" [],[]),("False",-6,TyConApp "Bool" [],[])]),("Char",TyAlg "Char" [("Char!",-4,TyConApp "Char" [],[TyRawChar])]),("Double",TyAlg "Double" [("Double!",-3,TyConApp "Double" [],[TyRawDouble])]),("Float",TyAlg "Float" [("Float!",-2,TyConApp "Float" [],[TyRawFloat])]),("Int",TyAlg "Int" [("Int!",-1,TyConApp "Int" [],[TyRawInt])])]
fromList [("*!D",Const (COp "p_e_Mul!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("*!F",Const (COp "p_e_Mul!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("*!I",Const (COp "p_e_Mul!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("+!D",Const (COp "p_e_Add!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("+!F",Const (COp "p_e_Add!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("+!I",Const (COp "p_e_Add!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("-!D",Const (COp "p_e_Sub!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("-!F",Const (COp "p_e_Sub!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("-!I",Const (COp "p_e_Sub!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("/=!B",Const (COp "p_e_Ne!B" (TyFun (TyConApp "Bool" []) (TyFun (TyConApp "Bool" []) (TyConApp "Bool" []))))),("/=!C",Const (COp "p_e_Ne!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("/=!D",Const (COp "p_e_Ne!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("/=!F",Const (COp "p_e_Ne!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("/=!I",Const (COp "p_e_Ne!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("<!C",Const (COp "p_e_Lt!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("<!D",Const (COp "p_e_Lt!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("<!F",Const (COp "p_e_Lt!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("<!I",Const (COp "p_e_Lt!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("<=!C",Const (COp "p_e_Le!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("<=!D",Const (COp "p_e_Le!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("<=!F",Const (COp "p_e_Le!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("<=!I",Const (COp "p_e_Le!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("==!B",Const (COp "p_e_Eq!B" (TyFun (TyConApp "Bool" []) (TyFun (TyConApp "Bool" []) (TyConApp "Bool" []))))),("==!C",Const (COp "p_e_Eq!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("==!D",Const (COp "p_e_Eq!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("==!F",Const (COp "p_e_Eq!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("==!I",Const (COp "p_e_Eq!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),(">!C",Const (COp "p_e_Gt!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),(">!D",Const (COp "p_e_Gt!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),(">!F",Const (COp "p_e_Gt!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),(">!I",Const (COp "p_e_Gt!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),(">=!C",Const (COp "p_e_Ge!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),(">=!D",Const (COp "p_e_Ge!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),(">=!F",Const (COp "p_e_Ge!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),(">=!I",Const (COp "p_e_Ge!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("a",App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Const (CInt 123))),("b",App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Const (CInt 456))),("test",Case (Var "a" (TyConApp "Int" [])) [((("Int!",-1,TyConApp "Int" [],[TyRawInt]),["a"]),Case (Var "b" (TyConApp "Int" [])) [((("Int!",-1,TyConApp "Int" [],[TyRawInt]),["b"]),App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Var "a" TyRawInt))] (TyConApp "Int" []))] (TyConApp "Int" []))]
Case (Var "a" (TyConApp "Int" [])) [((("Int!",-1,TyConApp "Int" [],[TyRawInt]),["a"]),Case (Var "b" (TyConApp "Int" [])) [((("Int!",-1,TyConApp "Int" [],[TyRawInt]),["b"]),App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Var "a" TyRawInt))] (TyConApp "Int" []))] (TyConApp "Int" [])
[]
==============================================
fromList [("Bool",TyAlg "Bool" [("True",-5,TyConApp "Bool" [],[]),("False",-6,TyConApp "Bool" [],[])]),("Char",TyAlg "Char" [("Char!",-4,TyConApp "Char" [],[TyRawChar])]),("Double",TyAlg "Double" [("Double!",-3,TyConApp "Double" [],[TyRawDouble])]),("Float",TyAlg "Float" [("Float!",-2,TyConApp "Float" [],[TyRawFloat])]),("Int",TyAlg "Int" [("Int!",-1,TyConApp "Int" [],[TyRawInt])])]
fromList [("*!D",Const (COp "p_e_Mul!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("*!F",Const (COp "p_e_Mul!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("*!I",Const (COp "p_e_Mul!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("+!D",Const (COp "p_e_Add!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("+!F",Const (COp "p_e_Add!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("+!I",Const (COp "p_e_Add!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("-!D",Const (COp "p_e_Sub!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("-!F",Const (COp "p_e_Sub!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("-!I",Const (COp "p_e_Sub!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("/=!B",Const (COp "p_e_Ne!B" (TyFun (TyConApp "Bool" []) (TyFun (TyConApp "Bool" []) (TyConApp "Bool" []))))),("/=!C",Const (COp "p_e_Ne!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("/=!D",Const (COp "p_e_Ne!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("/=!F",Const (COp "p_e_Ne!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("/=!I",Const (COp "p_e_Ne!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("<!C",Const (COp "p_e_Lt!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("<!D",Const (COp "p_e_Lt!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("<!F",Const (COp "p_e_Lt!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("<!I",Const (COp "p_e_Lt!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("<=!C",Const (COp "p_e_Le!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("<=!D",Const (COp "p_e_Le!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("<=!F",Const (COp "p_e_Le!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("<=!I",Const (COp "p_e_Le!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("==!B",Const (COp "p_e_Eq!B" (TyFun (TyConApp "Bool" []) (TyFun (TyConApp "Bool" []) (TyConApp "Bool" []))))),("==!C",Const (COp "p_e_Eq!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),("==!D",Const (COp "p_e_Eq!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),("==!F",Const (COp "p_e_Eq!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),("==!I",Const (COp "p_e_Eq!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),(">!C",Const (COp "p_e_Gt!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),(">!D",Const (COp "p_e_Gt!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),(">!F",Const (COp "p_e_Gt!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),(">!I",Const (COp "p_e_Gt!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),(">=!C",Const (COp "p_e_Ge!C" (TyFun (TyConApp "Char" []) (TyFun (TyConApp "Char" []) (TyConApp "Char" []))))),(">=!D",Const (COp "p_e_Ge!D" (TyFun (TyConApp "Double" []) (TyFun (TyConApp "Double" []) (TyConApp "Double" []))))),(">=!F",Const (COp "p_e_Ge!F" (TyFun (TyConApp "Float" []) (TyFun (TyConApp "Float" []) (TyConApp "Float" []))))),(">=!I",Const (COp "p_e_Ge!I" (TyFun (TyConApp "Int" []) (TyFun (TyConApp "Int" []) (TyConApp "Int" []))))),("a",App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Const (CInt 123))),("aa",Const (CInt 123)),("b",App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Const (CInt 456))),("baa",Const (CInt 456)),("test",Case (Var "a" (TyConApp "Int" [])) [((("Int!",-1,TyConApp "Int" [],[TyRawInt]),["a"]),Case (Var "b" (TyConApp "Int" [])) [((("Int!",-1,TyConApp "Int" [],[TyRawInt]),["b"]),App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Var "a" TyRawInt))] (TyConApp "Int" []))] (TyConApp "Int" []))]
App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Const (CInt 123))
[(App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Const (CInt 456)),(("Int!",-1,TyConApp "Int" [],[TyRawInt]),["baa"])),(App (DCon ("Int!",-1,TyConApp "Int" [],[TyRawInt])) (Const (CInt 123)),(("Int!",-1,TyConApp "Int" [],[TyRawInt]),["aa"]))]
Compiles!
