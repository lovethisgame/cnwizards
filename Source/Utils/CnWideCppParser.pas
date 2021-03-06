{******************************************************************************}
{                       CnPack For Delphi/C++Builder                           }
{                     中国人自己的开放源码第三方开发包                         }
{                   (C)Copyright 2001-2016 CnPack 开发组                       }
{                   ------------------------------------                       }
{                                                                              }
{            本开发包是开源的自由软件，您可以遵照 CnPack 的发布协议来修        }
{        改和重新发布这一程序。                                                }
{                                                                              }
{            发布这一开发包的目的是希望它有用，但没有任何担保。甚至没有        }
{        适合特定目的而隐含的担保。更详细的情况请参阅 CnPack 发布协议。        }
{                                                                              }
{            您应该已经和开发包一起收到一份 CnPack 发布协议的副本。如果        }
{        还没有，可访问我们的网站：                                            }
{                                                                              }
{            网站地址：http://www.cnpack.org                                   }
{            电子邮件：master@cnpack.org                                       }
{                                                                              }
{******************************************************************************}

unit CnWideCppParser;
{* |<PRE>
================================================================================
* 软件名称：CnPack IDE 专家包
* 单元名称：C/C++ 源代码分析器
* 单元作者：刘啸 liuxiao@cnpack.org
* 备    注：CnCppCodeParser 的 Unicode/WideString 版本
* 开发平台：PWin2000Pro + Delphi 2009
* 兼容测试：
* 本 地 化：该单元中的字符串均符合本地化处理方式
* 单元标识：$Id$
* 修改记录：2015.04.25 V1.1
*               增加 WideString 实现
*           2015.04.11
*               创建单元
================================================================================
|</PRE>}

interface

{$I CnWizards.inc}

uses
  Windows, SysUtils, Classes, Contnrs, CnPasCodeParser, CnWidePasParser,
  mwBCBTokenList, CnBCBWideTokenList, CnCommon, CnFastList;
  
type
{$IFDEF UNICODE}
  CnWideString = string;
{$ELSE}
  CnWideString = WideString;
{$ENDIF}

//==============================================================================
// C/C++ 解析器封装类，目前只实现解析大括号层次与普通标识符位置的功能
//==============================================================================

{ TCnWideCppStructParser }

  TCnWideCppToken = class(TCnWidePasToken)
  {* 描述一 Token 的结构高亮信息}
  private

  public
    constructor Create;
  published

  end;

  TCnWideCppStructParser = class(TObject)
  {* 利用 CParser 进行语法解析得到各个 Token 和位置信息}
  private
    FSupportUnicodeIdent: Boolean;
    FBlockCloseToken: TCnWideCppToken;
    FBlockStartToken: TCnWideCppToken;
    FChildCloseToken: TCnWideCppToken;
    FChildStartToken: TCnWideCppToken;
    FCurrentChildMethod: CnWideString;
    FCurrentMethod: CnWideString;
    FList: TCnList;
    FMethodCloseToken: TCnWideCppToken;
    FMethodStartToken: TCnWideCppToken;
    FInnerBlockCloseToken: TCnWideCppToken;
    FInnerBlockStartToken: TCnWideCppToken;
    FCurrentClass: CnWideString;
    FSource: CnWideString;
    FBlockIsNamespace: Boolean;
    function GetCount: Integer;
    function GetToken(Index: Integer): TCnWideCppToken;
  public
    constructor Create(SupportUnicodeIdent: Boolean = False);
    destructor Destroy; override;
    procedure Clear;
    procedure ParseSource(ASource: PWideChar; Size: Integer; CurrLine: Integer = 0;
      CurCol: Integer = 0; ParseCurrent: Boolean = False);
    function IndexOfToken(Token: TCnWideCppToken): Integer;
    property Count: Integer read GetCount;
    property Tokens[Index: Integer]: TCnWideCppToken read GetToken;

    property MethodStartToken: TCnWideCppToken read FMethodStartToken;
    property MethodCloseToken: TCnWideCppToken read FMethodCloseToken;
    {* 上面俩未解析}

    property ChildStartToken: TCnWideCppToken read FChildStartToken;
    property ChildCloseToken: TCnWideCppToken read FChildCloseToken;
    {* 当前层次为 2 的大括号}

    property BlockStartToken: TCnWideCppToken read FBlockStartToken;
    property BlockCloseToken: TCnWideCppToken read FBlockCloseToken;
    {* 当前层次为 1 的大括号}
    property BlockIsNamespace: Boolean read FBlockIsNamespace;
    {* 当前层次为 1 的大括号是否是 namespace}

    property InnerBlockStartToken: TCnWideCppToken read FInnerBlockStartToken;
    property InnerBlockCloseToken: TCnWideCppToken read FInnerBlockCloseToken;
    {* 当前最内层次的大括号}

    property CurrentMethod: CnWideString read FCurrentMethod;
    property CurrentClass: CnWideString read FCurrentClass;
    property CurrentChildMethod: CnWideString read FCurrentChildMethod;

    property Source: CnWideString read FSource;
  end;

implementation

var
  TokenPool: TCnList;

// 用池方式来管理 PasTokens 以提高性能
function CreateCppToken: TCnWideCppToken;
begin
  if TokenPool.Count > 0 then
  begin
    Result := TCnWideCppToken(TokenPool.Last);
    TokenPool.Delete(TokenPool.Count - 1);
  end
  else
    Result := TCnWideCppToken.Create;
end;

procedure FreeCppToken(Token: TCnWideCppToken);
begin
  if Token <> nil then
  begin
    Token.Clear;
    TokenPool.Add(Token);
  end;
end;

procedure ClearTokenPool;
var
  I: Integer;
begin
  for I := 0 to TokenPool.Count - 1 do
    TObject(TokenPool[I]).Free;
end;

//==============================================================================
// C/C++ 解析器封装类
//==============================================================================

{ TCnWideCppStructParser }

constructor TCnWideCppStructParser.Create(SupportUnicodeIdent: Boolean);
begin
  inherited Create;
  FList := TCnList.Create;
  FSupportUnicodeIdent := SupportUnicodeIdent;
end;

destructor TCnWideCppStructParser.Destroy;
begin
  FList.Free;
  inherited;
end;

procedure TCnWideCppStructParser.Clear;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    FreeCppToken(TCnWideCppToken(FList[I]));
  FList.Clear;
  FMethodStartToken := nil;
  FMethodCloseToken := nil;
  FChildStartToken := nil;
  FChildCloseToken := nil;
  FBlockStartToken := nil;
  FBlockCloseToken := nil;
  FCurrentMethod := '';
  FCurrentChildMethod := '';
end;

function TCnWideCppStructParser.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TCnWideCppStructParser.GetToken(Index: Integer): TCnWideCppToken;
begin
  Result := TCnWideCppToken(FList[Index]);
end;

procedure TCnWideCppStructParser.ParseSource(ASource: PWideChar; Size: Integer;
  CurrLine: Integer; CurCol: Integer; ParseCurrent: Boolean);
const
  IdentToIgnore: array[0..2] of string = ('CATCH', 'CATCH_ALL', 'AND_CATCH_ALL');
var
  CParser: TCnBCBWideTokenList;
  Token: TCnWideCppToken;
  Layer: Integer;
  BraceStack: TStack;
  Brace1Stack: TStack;
  Brace2Stack: TStack;
  BraceStartToken: TCnWideCppToken;
  BeginBracePosition: Integer;
  FunctionName, OwnerClass: string;
  PrevIsOperator, RunReachedZero: Boolean;

  procedure NewToken;
  var
    Len: Integer;
  begin
    Token := CreateCppToken;
    Token.FTokenPos := CParser.RunPosition;

    Len := CParser.TokenLength;
    if Len > CN_TOKEN_MAX_SIZE then
      Len := CN_TOKEN_MAX_SIZE;
    FillChar(Token.FToken[0], SizeOf(Token.FToken), 0);
    CopyMemory(@Token.FToken[0], CParser.TokenAddr, Len * SizeOf(WideChar));

    Token.FLineNumber := CParser.LineNumber - 1;    // 1 开始变成 0 开始
    Token.FCharIndex := CParser.ColumnNumber - 1;   // 暂无 Tab 展开的机制，1 开始变成 0 开始
    Token.FCppTokenKind := CParser.RunID;
    Token.FItemLayer := Layer;
    Token.FItemIndex := FList.Count;
    FList.Add(Token);
  end;

  function CompareLineCol(Line1, Line2, Col1, Col2: Integer): Integer;
  begin
    if Line1 < Line2 then
      Result := -1
    else if Line1 = Line2 then
    begin
      if Col1 < Col2 then
        Result := -1
      else if Col1 > Col2 then
        Result := 1
      else
        Result := 0;
    end
    else
      Result := 1;
  end;

  // 碰到()时往回越过
  procedure SkipProcedureParameters;
  var
    RoundCount: Integer;
  begin
    RoundCount := 0;
    repeat
      CParser.Previous;
      case CParser.RunID of
        ctkroundclose: Inc(RoundCount);
        ctkroundopen: Dec(RoundCount);
        ctknull: Exit;
      end;
    until ((RoundCount <= 0) and ((CParser.RunID = ctkroundopen) or
      (CParser.RunID = ctkroundpair)));
    CParser.PreviousNonJunk; // 往回跳过圆括号中的声明
  end;

  function IdentCanbeIgnore(const Name: string): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := Low(IdentToIgnore) to High(IdentToIgnore) do
    begin
      if Name = IdentToIgnore[I] then
      begin
        Result := True;
        Break;
      end;
    end;
  end;

  // 碰到<>时往回越过
  procedure SkipTemplateArgs;
  var
    TemplateCount: Integer;
  begin
    if CParser.RunID <> ctkGreater then Exit;
    TemplateCount := 1;
    repeat
      CParser.Previous;
      case CParser.RunID of
        ctkGreater: Inc(TemplateCount);
        ctklower: Dec(TemplateCount);
        ctknull: Exit;
      end;
    until (((TemplateCount = 0) and (CParser.RunID = ctklower)) or
      (CParser.RunIndex = 0));
    CParser.PreviousNonJunk;
  end;

begin
  Clear;
  CParser := nil;
  BraceStack := nil;
  Brace1Stack := nil;
  Brace2Stack := nil;

  FInnerBlockStartToken := nil;
  FInnerBlockCloseToken := nil;
  FBlockStartToken := nil;
  FBlockCloseToken := nil;
  FBlockIsNamespace := False;

  FCurrentClass := '';
  FCurrentMethod := '';

  try
    BraceStack := TStack.Create;
    Brace1Stack := TStack.Create;
    Brace2Stack := TStack.Create;
    FSource := ASource;

    CParser := TCnBCBWideTokenList.Create(FSupportUnicodeIdent);
    CParser.DirectivesAsComments := False;
    CParser.SetOrigin(ASource, Size);

    Layer := 0; // 初始层次，最外层为 0
    while CParser.RunID <> ctknull do
    begin
      case CParser.RunID of
        ctkbraceopen:
          begin
            Inc(Layer);
            NewToken;

            if CompareLineCol(CParser.LineNumber, CurrLine,
              CParser.ColumnNumber, CurCol) <= 0 then // 在光标前
            begin
              BraceStack.Push(Token);
              if Layer = 1 then // 如果是第一层，又是 OuterBlock 的 Begin
                Brace1Stack.Push(Token)
              else if Layer = 2 then
                Brace2Stack.Push(Token);
            end
            else // 一旦在光标后了，就可以判断Start了
            begin
              if (FInnerBlockStartToken = nil) and (BraceStack.Count > 0) then
                FInnerBlockStartToken := TCnWideCppToken(BraceStack.Pop);
              if (FBlockStartToken = nil) and (Brace1Stack.Count > 0) then
                FBlockStartToken := TCnWideCppToken(Brace1Stack.Pop);
              if (FChildStartToken = nil) and (Brace2Stack.Count > 0) then
                FChildStartToken := TCnWideCppToken(Brace2Stack.Pop);
            end;
          end;
        ctkbraceclose:
          begin
            NewToken;
            if CompareLineCol(CParser.LineNumber, CurrLine,
              CParser.ColumnNumber, CurCol) >= 0 then // 一旦在光标后了就可判断
            begin
              if (FInnerBlockStartToken = nil) and (BraceStack.Count > 0) then
                FInnerBlockStartToken := TCnWideCppToken(BraceStack.Pop);
              if (FBlockStartToken = nil) and (Brace1Stack.Count > 0) then
                FBlockStartToken := TCnWideCppToken(Brace1Stack.Pop);
              if (FChildStartToken = nil) and (Brace2Stack.Count > 0) then
                FChildStartToken := TCnWideCppToken(Brace2Stack.Pop);

              if (FInnerBlockCloseToken = nil) and (FInnerBlockStartToken <> nil) then
              begin
                if Layer = FInnerBlockStartToken.ItemLayer then
                  FInnerBlockCloseToken := Token;
              end;

              if Layer = 1  then // 第一层，为 OuterBlock 的 End
              begin
                if FBlockCloseToken = nil then
                  FBlockCloseToken := Token;
              end
              else if Layer = 2 then  // 第二层的也记着
              begin
                if FChildCloseToken = nil then
                  FChildCloseToken := Token;
              end;
            end
            else // 在光标前
            begin
              if BraceStack.Count > 0 then
                BraceStack.Pop;
              if (Layer = 1) and (Brace1Stack.Count > 0) then
                Brace1Stack.Pop;
              if (Layer = 2) and (Brace2Stack.Count > 0) then
                Brace2Stack.Pop;
            end;
            Dec(Layer);
          end;
        ctkidentifier,        // Need these for flow control in source highlight
        ctkreturn, ctkgoto, ctkbreak, ctkcontinue:
          begin
            NewToken;
          end;
        ctkdirif, ctkdirifdef, // Need these for conditional compile directive
        ctkdirifndef, ctkdirelif, ctkdirelse, ctkdirendif:
          begin
            NewToken;
          end;
      end;

      CParser.NextNonJunk;
    end;

    if ParseCurrent then
    begin
      // 处理第一层或第二层（如果第一层是 namespace 的话）的内容
      if FBlockStartToken <> nil then
      begin
        BraceStartToken := FBlockStartToken;

        // 先到达最外层括号处
        if CParser.RunPosition > FBlockStartToken.TokenPos then
        begin
          while CParser.RunPosition > FBlockStartToken.TokenPos do
            CParser.PreviousNonJunk;
        end
        else if CParser.RunPosition < FBlockStartToken.TokenPos then
          while CParser.RunPosition < FBlockStartToken.TokenPos do
            CParser.NextNonJunk;

        RunReachedZero := False;
        while not (CParser.RunID in [ctkNull, ctkbraceclose, ctksemicolon])
          and (CParser.RunPosition >= 0) do               //  防止 using namespace std; 这种
        begin
          if RunReachedZero and (CParser.RunPosition = 0) then
            Break; // 曾经到 0，现在还是 0，表示出现了死循环
          if CParser.RunPosition = 0 then
            RunReachedZero := True;

          // 如果 namespace 是最开头，则 RunPosition 可以是 0
          if CParser.RunID in [ctknamespace] then
          begin
            // 本层是 namespace，处理第二层去
            BraceStartToken := FChildStartToken;
            FBlockIsNamespace := True;
            Break;
          end;
          CParser.PreviousNonJunk;
        end;

        if BraceStartToken = nil then
          Exit;

        // 回到最外层括号处
        if CParser.RunPosition > BraceStartToken.TokenPos then
        begin
          while CParser.RunPosition > BraceStartToken.TokenPos do
            CParser.PreviousNonJunk;
        end
        else if CParser.RunPosition < BraceStartToken.TokenPos then
          while CParser.RunPosition < BraceStartToken.TokenPos do
            CParser.NextNonJunk;

        // 查找这个需要的大括号之前的声明，类或函数等
        BeginBracePosition := CParser.RunPosition;
        // 记录左大括号的位置
        CParser.PreviousNonJunk;
        if CParser.RunID = ctkidentifier then // 如果左大括号前是标识符
        begin
          while not (CParser.RunID in [ctkNull, ctkbraceclose])
            and (CParser.RunPosition > 0) do
          begin
            if CParser.RunID in [ctkclass, ctkstruct] then
            begin
              // 找到个 class 或 struct，那么名称是紧靠 : 或 { 前的东西
              while not (CParser.RunID in [ctkcolon, ctkbraceopen, ctknull]) do
              begin
                FCurrentClass := string(CParser.RunToken); // 找到类名或者结构名
                CParser.NextNonJunk;
              end;
              if FCurrentClass <> '' then // 找到类名了，不会有其它名称了，退出
                Exit;
            end;
            CParser.PreviousNonJunk;
          end;
        end
        else if CParser.RunID in [ctkroundclose, ctkroundpair, ctkconst,
          ctkvolatile, ctknull] then
        begin
          // 左大括号前不是标识符而是这几个，则可能到达了一个函数体的末尾，大括号开头
          // 往回走，解出函数来
          CParser.Previous;

          // 往回找圆括号等
          while not ((CParser.RunID in [ctkSemiColon, ctkbraceclose,
            ctkbraceopen, ctkbracepair]) or (CParser.RunID in IdentDirect) or
            (CParser.RunIndex = 0)) do
          begin
            CParser.PreviousNonJunk;
            // 同时处理函数中的冒号，如 __fastcall TForm1::TForm1(TComponent* Owner) : TForm(Owner)
            if CParser.RunID = ctkcolon then
            begin
              CParser.PreviousNonJunk;
              if CParser.RunID in [ctkroundclose, ctkroundpair] then
                CParser.NextNonJunk
              else
              begin
                CParser.NextNonJunk;
                Break;
              end;
            end;
          end;

          // 这儿应该停在圆括号处
          if CParser.RunID in [ctkcolon, ctkSemiColon, ctkbraceclose,
            ctkbraceopen, ctkbracepair] then
            CParser.NextNonComment
          else if CParser.RunIndex = 0 then
          begin
            if CParser.IsJunk then
              CParser.NextNonJunk;
          end
          else // 越过编译指令
          begin
            while CParser.RunID <> ctkcrlf do
            begin
              if (CParser.RunID = ctknull) then
                Exit;
              CParser.Next;
            end;
            CParser.NextNonJunk;
          end;

          // 到达一个具体的函数开头
          while (CParser.RunPosition < BeginBracePosition) and
            (CParser.RunID <> ctkcolon) do
          begin
            if CParser.RunID = ctknull then
              Exit;
            CParser.NextNonComment;
          end;

          FunctionName := '';
          OwnerClass := '';
          SkipProcedureParameters;

          if CParser.RunID = ctknull then
            Exit
          else if CParser.RunID = ctkthrow then
            SkipProcedureParameters;

          CParser.PreviousNonJunk;
          PrevIsOperator := CParser.RunID = ctkoperator;
          CParser.NextNonJunk;

          if ((CParser.RunID = ctkidentifier) or (PrevIsOperator)) and not
            IdentCanbeIgnore(CParser.RunToken) then
          begin
            if PrevIsOperator then
              FunctionName := 'operator ';
            FunctionName := FunctionName + CParser.RunToken;
            CParser.PreviousNonJunk;

            if CParser.RunID = ctkcoloncolon then
            begin
              FCurrentClass := '';
              while CParser.RunID = ctkcoloncolon do
              begin
                CParser.PreviousNonJunk; // 类名或类名带尖括号
                if CParser.RunID = ctkGreater then
                  SkipTemplateArgs;

                OwnerClass := CParser.RunToken + OwnerClass;
                CParser.PreviousNonJunk;
                if CParser.RunID = ctkcoloncolon then
                  OwnerClass := CParser.RunToken + OwnerClass;
              end;
              FCurrentClass := string(OwnerClass);
            end;
            if OwnerClass <> '' then
              FCurrentMethod := string(OwnerClass + '::' + FunctionName)
            else
              FCurrentMethod := string(FunctionName);
          end;
        end;
      end;
    end;
  finally
    BraceStack.Free;
    Brace1Stack.Free;
    Brace2Stack.Free;
    CParser.Free;
  end;
end;

function TCnWideCppStructParser.IndexOfToken(Token: TCnWideCppToken): Integer;
begin
  Result := FList.IndexOf(Token);
end;

{ TCnWideCppToken }

constructor TCnWideCppToken.Create;
begin
  inherited;
  FUseAsC := True;
end;

initialization
  TokenPool := TCnList.Create;

finalization
  ClearTokenPool;
  FreeAndNil(TokenPool);

end.
