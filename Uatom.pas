unit Uatom;

interface
 const
  UniqueSignature  = '1_**XvR*_*_ProcessID_:';
  UniqueSignature2 = '2_**XvR*_*_ProcessID_:';
{}
 Function GetUniqueSignature (UI : Byte) : String;
 Procedure CleanAtoms(UI : Byte);
 Function ReadAtom(UI : Byte) : String;
 Procedure WriteAtom(UI : Byte; Str : String);
{}
 
implementation
  uses Windows, SysUtils;

Function GetUniqueSignature (UI : Byte) : String;
 Var
  S : String;
begin
{}
 S := '';
{}
 Case UI of
  0: S := UniqueSignature;
  1: S := UniqueSignature2;
 end;
{}
 result := S;
{} 
end;

Procedure CleanAtoms(UI : Byte);
var P:PChar;
  i:Word;
begin
 GetMem(p, 256);
{}
 For i := 0 to $FFFF do
  begin
   GlobalGetAtomName(i, p, 255);
   if StrPos(p, PChar(GetUniqueSignature(UI))) <> nil then
    GlobalDeleteAtom(i);
  end;
{}
 FreeMem(p);
{}
end;

Procedure WriteAtom(UI : Byte; Str:string);
begin 
 CleanAtoms(UI);
 GlobalAddAtom(PChar(GetUniqueSignature(UI) + Str));
end;

Function ReadAtom (UI : Byte) : string;
 var
  P : PChar;
  i : Word;
  F : Boolean;
begin
 result := '';
 F := false;
 GetMem(p, 256);
 For i := 0 to $FFFF do
  begin
   GlobalGetAtomName(i, p, 255);
   if StrPos(p, PChar(GetUniqueSignature(UI))) <> nil then
    begin
     F := true;
     break;
    end;
  end;
 if f then
  result := StrPas(P);
 FreeMem(p);
end;

end.
 