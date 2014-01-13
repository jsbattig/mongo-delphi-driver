unit TestMongoStream;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit 
  being tested.

}

interface

uses
  TestFramework, Classes, MongoStream, MongoDB, GridFS, TestMongoDB, TestGridFS, MongoAPI;

{$I ..\MongoC_defines.inc}

type
  // Test methods for class TMongoStream

  TestTMongoStream = class(TestGridFSBase)
  private
    FMongoStream: TMongoStream;
    procedure CheckMongoStreamPointer;
    procedure CreateTestFile(ACreateMode: Boolean = True; const AEncryptionKey:
        String = ''; ACompressed: Boolean = True; AEncryptionBits: TAESKeyLength =
        akl128);
    procedure Internal_TestSetSize(NewSize: Integer);
    procedure OpenStreamReadOnly;
    procedure RecreateStream;
    procedure TestRead_Internal(const AEncrypted: Boolean; ACompressed: Boolean;
        MultiChunkData: Boolean = False; VerySmallBlock: Boolean = False;
        AEncryptionBits: TAESKeyLength = akl128);
    {$IFDEF DELPHI2007}
    procedure TestSeek_Int64(AOrigin: TSeekOrigin; AOffset, AbsExpected: Int64);
    {$ENDIF}
    procedure TestSeek_Int32(AOrigin: Word; AOffset: Longint; AbsExpected: Int64);
    procedure TestWriteCloseOverwriteAndReadSmallFile_Internal(const
        AEncryptionKey: String);
  protected
    procedure InternalRunMultiThreaded(AMethodAddr: Pointer; ALoops: Integer);
    procedure Internal_TestEmptyFile;
    function StandardRemoteFileName: UTF8String; override;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestGetSizeInt32;
    procedure TestSetSizeInt32;
    {$IFDEF DELPHI2007}
    procedure TestSetSizeInt64;
    {$ENDIF}
    procedure TestCreateStream;
    procedure TestCreateStreamAndOpenWithDifferentCase;
    procedure TestCreateStreamWithPrefix;
    procedure TestEmptyFile;
    procedure TestEmptyFileThenWriteSomeBytes;
    procedure TestParallelRecreateMongoStream;
    procedure TestRead;
    procedure TestReadEncryptedEnabledAndCompressionEnabled;
    procedure TestReadEncryptedEnabledAndCompressionDisabled;
    procedure TestReadEncryptedDisabledAndCompressionDisabled;
    procedure TestReadEncryptedDisabledAndCompressionDisabledOneMegOfData;
    procedure TestReadEncryptedDisabledAndCompressionEnabled;
    procedure TestReadEncryptedDisabledAndCompressionEnabledOneMegOfData;
    procedure TestReadEncryptedEnabledAndCompressionDisabled6Bytes;
    procedure TestReadEncryptedEnabledAndCompressionEnabled6Bytes;
    procedure TestReadEncryptedEnabledAndCompressionDisabledOneMegOfData;
    procedure TestReadEncryptedDisabledAndCompressionEnabled6Bytes;
    procedure TestReadEncryptedDisabledAndCompressionDisabled6Bytes;
    procedure TestReadEncryptedEnabledAndCompressionDisabled_256Bits;
    procedure TestReadEncryptedEnabledAndCompressionDisabled_192Bits;
    procedure TestReadEncryptedEnabledAndCompressionEnabledOneMegOfData;
    procedure TestReadEncryptedEnabledAndCompressionEnabledOneMegOfData256Bits;
    procedure TestReadEncryptedEnabledAndCompressionEnabledOneMegOfData192Bits;
    procedure TestSeekFromCurrentInt32;
    procedure TestSeekFromEndInt32;
    procedure TestSeekFromBeginningInt32;
    {$IFDEF DELPHI2007}
    procedure TestSeekFromBeginningInt64;
    procedure TestSeekFromCurrentInt64;
    procedure TestSeekFromEndInt64;
    {$ENDIF}
    procedure TestSeekPastTheEndOfFile;
    procedure TestSetSizeMakeFileLarger;
    procedure TestSetSizeMakeFileLargerOverOneChunk;
    procedure TestSetSizeMakeFileLargerOverThreeChunks;
    procedure TestStreamStatusFlag;
    procedure TestStressEmptyFile;
    procedure TestStressFourThreads;
    procedure TestStressWriteReads;
    procedure TestWrite;
    procedure TestWriteEncryptedEnabled;
    procedure TestWriteInALoopSerializedWithJournal;
    procedure TestWriteInALoopNotSerializedWithJournal;
    procedure TestWriteRead23MB;
    procedure TestWriteRead23MBFourThreadsThreeLoops;
    procedure TestWriteAndReadFromSameChunk;
    procedure TestWriteAndReadBackSomeChunks;
    procedure TestWriteAndReadBackSomeChunksTryBoundaries;
    procedure TestWriteCloseOverwriteAndReadSmallFileEncrypted;
    procedure TestWriteCloseOverwriteAndReadSmallFile;
  end;

implementation

uses
  uFileManagement, FileCtrl, SysUtils, MongoBson, Dialogs{$IFNDEF VER130}, Variants{$EndIf}, Windows;

const
  FILESIZE = 512 * 1024;
  SMALLER_SIZE = 1024;
  FEW_BYTES_OF_DATA : UTF8String = 'this is just a few bytes of data';

type
  TTestProc = procedure of object;
  TMongoStreamThread = class(TThread)
  private
    FErrorMessage: UTF8String;
    FLoops: Integer;
    FTestMongoStream: TestTMongoStream;
    FTestProc: Pointer;
  public
    constructor Create(ATestProc: Pointer; ALoops: Integer);
    destructor Destroy; override;
    procedure Execute; override;
    property ErrorMessage: UTF8String read FErrorMessage;
  end;

var
  FOpenReadonlyLoops: Integer;
  FRecreateLoops: Integer;

procedure TestTMongoStream.CheckMongoStreamPointer;
begin
  Check(FMongoStream <> nil, 'FMongoStream should be <> nil');
end;

procedure TestTMongoStream.CreateTestFile(ACreateMode: Boolean = True; const
    AEncryptionKey: String = ''; ACompressed: Boolean = True; AEncryptionBits:
    TAESKeyLength = akl128);
var
  AMode : TMongoStreamModeSet;
begin
  if ACreateMode then
    AMode := [msmWrite, msmCreate]
  else AMode := [msmWrite];
  FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, AMode, ACompressed, AEncryptionKey, AEncryptionBits);
end;

procedure TestTMongoStream.InternalRunMultiThreaded(AMethodAddr: Pointer;
    ALoops: Integer);
var
  AThreads : array [0..3] of TMongoStreamThread;
  i : integer;
  AErrorMessages : UTF8String;
begin
  AErrorMessages := '';
  for i := Low(AThreads) to High(AThreads) do
    AThreads[i] := nil;
  for i := Low(AThreads) to High(AThreads) do
    AThreads[i] := TMongoStreamThread.Create(AMethodAddr, ALoops);
  try
    for i := Low(AThreads) to High(AThreads) do
      AThreads[i].Resume;
    for i := Low(AThreads) to High(AThreads) do
      AThreads[i].WaitFor;
    for i := Low(AThreads) to High(AThreads) do
      if AThreads[i].ErrorMessage <> '' then
        AErrorMessages := AErrorMessages + AThreads[i].ErrorMessage + #13#10;
    if AErrorMessages <> '' then
      Fail(AErrorMessages);
  finally
    for i := Low(AThreads) to High(AThreads) do
      if AThreads[i] <> nil then
        AThreads[i].Free;
  end;
end;

procedure TestTMongoStream.SetUp;
begin
  inherited;
end;

function TestTMongoStream.StandardRemoteFileName: UTF8String;
begin
  Result := IntToStr(Int64(Self)) + inherited StandardRemoteFileName;
end;

procedure TestTMongoStream.TearDown;
begin
  if FMongoStream <> nil then
    begin
      FMongoStream.Free;
      FMongoStream := nil;
    end;
  inherited;
end;

procedure TestTMongoStream.TestGetSizeInt32;
var
  ReturnValue: Int64;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, length(FEW_BYTES_OF_DATA));
  ReturnValue := FMongoStream.Size;
  CheckEquals(length(FEW_BYTES_OF_DATA), ReturnValue, 'Expected file size doesn''t match');
end;

procedure TestTMongoStream.TestSetSizeInt32;
var
  NewSize: Integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, length(FEW_BYTES_OF_DATA));
  NewSize := length(FEW_BYTES_OF_DATA) - 2;
  FMongoStream.Size := NewSize;
  CheckEquals(NewSize, FMongoStream.Position, 'Position should be at the end of the file');
  FreeAndNil(FMongoStream);
  FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, [], True);
  CheckEquals(NewSize, FMongoStream.Size, 'New size was not taken by MongoStream');
end;

{$IFDEF DELPHI2007}
procedure TestTMongoStream.TestSetSizeInt64;
var
  NewSize: Int64;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, length(FEW_BYTES_OF_DATA));
  NewSize := length(FEW_BYTES_OF_DATA) - 2;
  FMongoStream.Size := NewSize;
  CheckEquals(NewSize, FMongoStream.Position, 'Position should be at the end of the file');
  FreeAndNil(FMongoStream);
  FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, [], True);
  CheckEquals(NewSize, FMongoStream.Size, 'New size was not taken by MongoStream');
end;
{$ENDIF}

procedure TestTMongoStream.TestCreateStream;
var
  AFileName: UTF8String;
  ADB: UTF8String;
begin
  ADB := FSDB;
  AFileName := StandardRemoteFileName;
  FMongoStream := TMongoStream.Create(FMongo, ADB, AFileName, [msmCreate, msmWrite], False);
  CheckMongoStreamPointer;
end;

procedure TestTMongoStream.TestCreateStreamAndOpenWithDifferentCase;
var
  AFileName: UTF8String;
  ADB: UTF8String;
begin
  ADB := FSDB;
  AFileName := StandardRemoteFileName;
  FMongoStream := TMongoStream.Create(FMongo, ADB, AFileName, [msmCreate, msmWrite], False);
  CheckMongoStreamPointer;
  FreeAndNil(FMongoStream);
  FMongoStream := TMongoStream.Create(FMongo, ADB, LowerCase(AFileName), [], False);
end;

procedure TestTMongoStream.TestCreateStreamWithPrefix;
var
  AFileName: UTF8String;
  APrefix: UTF8String;
  ADB: UTF8String;
begin
  ADB := FSDB;
  AFileName := StandardRemoteFileName;
  APrefix := 'prefix_test';
  FMongoStream := TMongoStream.Create(FMongo, ADB, AFileName, APrefix, [msmCreate], True, False);
  CheckMongoStreamPointer;
end;

procedure TestTMongoStream.TestRead;
var
  ReturnValue: Integer;
  Count: Integer;
  Buffer: array [0..SMALLER_SIZE - 1] of AnsiChar;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  Count := length(FEW_BYTES_OF_DATA);
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, Count);
  FMongoStream.Position := 0;
  ReturnValue := FMongoStream.Read(Buffer, Count);
  CheckEquals(Count, ReturnValue, 'Number of bytes read dont''t match');
  Check(CompareMem(@Buffer, PAnsiChar(FEW_BYTES_OF_DATA), Count), 'Memory read don''t match data written');
end;

procedure TestTMongoStream.TestSeekFromCurrentInt32;
begin
  TestSeek_Int32(soFromCurrent, -1, length(FEW_BYTES_OF_DATA) - 1);
end;

procedure TestTMongoStream.TestSeekFromEndInt32;
begin
   TestSeek_Int32(soFromEnd, -2, length(FEW_BYTES_OF_DATA) - 2);
end;

procedure TestTMongoStream.TestSeekFromBeginningInt32;
begin
  TestSeek_Int32(soFromBeginning, 5, 5);
end;

procedure TestTMongoStream.TestSeek_Int32(AOrigin: Word; AOffset: Longint;
    AbsExpected: Int64);
var
  ReturnValue: Integer;
  Origin: Word;
  Offset: Integer;
  Buffer: array [0..SMALLER_SIZE - 1] of AnsiChar;
  Count : integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  Count := length(FEW_BYTES_OF_DATA);
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, Count);
  Offset := AOffset;
  Origin := AOrigin;
  ReturnValue := FMongoStream.Seek(Offset, Origin);
  CheckEquals(AbsExpected, ReturnValue, 'Return value from Seek not what expected');
  CheckEquals(Count - AbsExpected, FMongoStream.Read(Buffer, Count), 'Number of bytes read after first Seek not what expected');
  Check(CompareMem(@Buffer, @PAnsiChar(FEW_BYTES_OF_DATA)[AbsExpected], Count - AbsExpected), 'Data read doesn''t match');
end;

{$IFDEF DELPHI2007}
procedure TestTMongoStream.TestSeekFromBeginningInt64;
begin
  TestSeek_Int64(soBeginning, 5, 5);
end;

procedure TestTMongoStream.TestSeekFromCurrentInt64;
begin
  TestSeek_Int64(soCurrent, -1, length(FEW_BYTES_OF_DATA) - 1);
end;

procedure TestTMongoStream.TestSeekFromEndInt64;
begin
  TestSeek_Int64(soEnd, -2, length(FEW_BYTES_OF_DATA) - 2);
end;
{$ENDIF}

procedure TestTMongoStream.TestSeekPastTheEndOfFile;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  CheckEquals(length(FEW_BYTES_OF_DATA), FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, length(FEW_BYTES_OF_DATA)), 'Write didn''t return that I wrote the same amount of bytes written');
  CheckEquals(length(FEW_BYTES_OF_DATA), FMongoStream.Seek(length(FEW_BYTES_OF_DATA) + 1, {$IFDEF DELPHI2007} soBeginning {$ELSE} soFromBeginning {$ENDIF}), 'Should not allow seeking past the end of file');
  CheckEquals(length(FEW_BYTES_OF_DATA), FMongoStream.Position, 'Should not allow seeking past the end of file');
end;

{$IFDEF DELPHI2007}
procedure TestTMongoStream.TestSeek_Int64(AOrigin: TSeekOrigin; AOffset,
    AbsExpected: Int64);
var
  ReturnValue: Int64;
  Origin: TSeekOrigin;
  Offset: Int64;
  Buffer: array [0..SMALLER_SIZE - 1] of AnsiChar;
  Count : integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  Count := length(FEW_BYTES_OF_DATA);
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, Count);
  Offset := AOffset;
  Origin := AOrigin;
  ReturnValue := FMongoStream.Seek(Offset, Origin);
  CheckEquals(AbsExpected, ReturnValue, 'Return value from Seek not what expected');
  CheckEquals(Count - AbsExpected, FMongoStream.Read(Buffer, Count), 'Number of bytes read after first Seek not what expected');
  Check(CompareMem(@Buffer, @PAnsiChar(FEW_BYTES_OF_DATA)[AbsExpected], Count - AbsExpected), 'Data read doesn''t match');
end;
{$ENDIF}

procedure TestTMongoStream.TestStreamStatusFlag;
var
  q : IBson;
  fileid : IBsonOID;
  buf : IBsonBuffer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  CheckEquals(length(FEW_BYTES_OF_DATA), FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, length(FEW_BYTES_OF_DATA)), 'Write didn''t return that I wrote the same amount of bytes written');
  fileid := FMongoStream.ID;
  FreeAndNil(FMongoStream);
  FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, [], False);
  Check(FMongoStream.Status = mssOk, 'Status of file should report OK status');
  FreeAndNil(FMongoStream);
  buf := NewBsonBuffer;
  buf.Append('files_id', fileid);
  q := buf.finish;
  FMongo.remove('fsdb.fs.chunks', q);
  FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, [], False);
  Check(FMongoStream.Status = mssMissingChunks, 'Status of file should report missing chunks');
end;

procedure TestTMongoStream.TestStressFourThreads;
begin
  InternalRunMultiThreaded(@TestTMongoStream.TestStressWriteReads, 5);
end;

procedure TestTMongoStream.TestStressWriteReads;
const
  RE_WRITE_POS : array [0..5] of integer = (1024, 1024 * 128, 523, 1024 * 256 + 33, 0, 1024 * 100 + 65);
  RE_WRITE_LEN : array [0..5] of integer = ( 512, 1024 * 300, 1024 * 128, 45, 1024 * 64 + 5, 1024 * 313);
var
  Buffer : PAnsiChar;
  i, j : integer;
  ReadBuf : PAnsiChar;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  GetMem(Buffer, FILESIZE);
  try
    GetMem(ReadBuf, FILESIZE);
    try
      for i := 0 to FILESIZE - 1 do
        Buffer[i] := AnsiChar(Random(256));
      CheckEquals(FILESIZE, FMongoStream.Write(Buffer^, FILESIZE), 'Call to Write should have written all data requested');
      FreeAndNil(FMongoStream);
      FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, [msmWrite], True); // Reopen the file
      Check(FMongoStream.Status = mssOk, 'Status of file should be mssOk');
      for i := Low(RE_WRITE_POS) to High(RE_WRITE_POS) do
        begin
          FMongoStream.Position := RE_WRITE_POS[i];
          for j := RE_WRITE_POS[i] to RE_WRITE_POS[i] + RE_WRITE_LEN[i] do
            Buffer[j] := AnsiChar(Random(256));
          CheckEquals(RE_WRITE_LEN[i], FMongoStream.Write(Buffer[RE_WRITE_POS[i]], RE_WRITE_LEN[i]), 'Amount of data overriden don''t match count');
          FMongoStream.Position := RE_WRITE_POS[i];
          CheckEquals(RE_WRITE_LEN[i], FMongoStream.Read(ReadBuf^, RE_WRITE_LEN[i]), 'Amount of data read after overriding don''t match');
          Check(CompareMem(@Buffer[RE_WRITE_POS[i]], ReadBuf, RE_WRITE_LEN[i]), 'Data read from stream don''t match data written');
        end;
    finally
      FreeMem(ReadBuf);
    end;
  finally
    FreeMem(Buffer);
  end;
end;

procedure TestTMongoStream.TestWrite;
var
  ReturnValue: Integer;
  Count: Integer;
  Buffer: Pointer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  Count := length(FEW_BYTES_OF_DATA);
  Buffer := PAnsiChar(FEW_BYTES_OF_DATA);
  ReturnValue := FMongoStream.Write(Buffer^, Count);
  CheckEquals(Count, ReturnValue, 'Write didn''t return that I wrote the same amount of bytes written');
end;

procedure TestTMongoStream.TestWriteInALoopSerializedWithJournal;
var
  ReturnValue : Integer;
  Count, n : Integer;
  i : Cardinal;
  Buffer: Pointer;
  it : IBsonIterator;
  LastGetLastErrorResult : IBson;
  bytesWritten : Cardinal;
begin
  n := 0;
  bytesWritten := 0;
  CreateTestFile;
  CheckMongoStreamPointer;
  FMongoStream.SerializedWithJournal := True;
  LastGetLastErrorResult := nil;
  FMongoStream.SerializeWithJournalByteWritten := 50;
  Check(FMongoStream.SerializedWithJournal, 'FMongoStream.SerializedWithJournal should be equals to true');
  Check(FMongoStream.SerializeWithJournalByteWritten > 0, 'FMongoStream.SerializeWithJournalByteWritten should be higher than zero');
  for i := 1 to 100 do
    begin
      Count := length(FEW_BYTES_OF_DATA);
      Buffer := PAnsiChar(FEW_BYTES_OF_DATA);
      ReturnValue := FMongoStream.Write(Buffer, Count);
      inc(bytesWritten, Count);
      if bytesWritten > FMongoStream.SerializeWithJournalByteWritten  then
        begin
          bytesWritten := 0;
          Check(FMongoStream.LastSerializeWithJournalResult <> nil, 'Serialize with journal command should had to been called');
          Check(LastGetLastErrorResult <> FMongoStream.LastSerializeWithJournalResult, 'GetLastError result bson object should have changed from last iteration set');
          LastGetLastErrorResult := FMongoStream.LastSerializeWithJournalResult;
          it := LastGetLastErrorResult.iterator;
          n := 0;
          while it.Next do
            if it.Key = 'ok' then
              begin
               Check(it.Value = 1, 'ok return value from call to getLastError should return 1');
               inc(n);
              end
            else if it.key = 'err' then
              begin
                Check(VarIsNull(it.Value), 'Value of err property of return value for getLastError should be null');
                inc(n);
              end;
          CheckEquals(2, n, 'Nunber of matching properties on result of getLastError should be equals to 2');
        end
        else Check(LastGetLastErrorResult = FMongoStream.LastSerializeWithJournalResult, 'Last cached getLastError bson object should still be the same on Stream object');
      CheckEquals(Count, ReturnValue, 'Write didn''t return that I wrote the same amount of bytes written');
    end;
  CheckEquals(2, n, 'At least code should have passed one time for branch that controls sync with journal');
end;

procedure TestTMongoStream.TestWriteInALoopNotSerializedWithJournal;
var
  ReturnValue : Integer;
  Count : Integer;
  i : Cardinal;
  Buffer: Pointer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  FMongoStream.SerializedWithJournal := False;
  FMongoStream.SerializeWithJournalByteWritten := 50;
  Check(not FMongoStream.SerializedWithJournal, 'FMongoStream.SerializedWithJournal should be equals to true');
  Check(FMongoStream.SerializeWithJournalByteWritten > 0, 'FMongoStream.SerializeWithJournalWriteOpCount should be higher than zero');
  for i := 1 to 100 do
    begin
      Count := length(FEW_BYTES_OF_DATA);
      Buffer := PAnsiChar(FEW_BYTES_OF_DATA);
      ReturnValue := FMongoStream.Write(Buffer, Count);
      CheckEquals(Count, ReturnValue, 'Write didn''t return that I wrote the same amount of bytes written');
    end;
  Check(FMongoStream.LastSerializeWithJournalResult = nil, 'Serialize with journal command result be equals to nil');
end;

procedure TestTMongoStream.TestWriteRead23MB;
type
  PBuffer = ^TBuffer;
  TBuffer = array [0..1024 * 1024 - 1 + 123] of AnsiChar; // I added 123 bytes to "complicate" buffering
const
  TWENTYTHREEMEGS = 23 * 1024 * 1024;
var
  ReturnValue: Integer;
  Buffer, Buffer2: PBuffer;
  i : integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  GetMem(Buffer, sizeof(TBuffer));
  try
    GetMem(Buffer2, sizeof(TBuffer));
    try
      for i := Low(Buffer^) to High(Buffer^) do
        Buffer[i] := AnsiChar(Random(256));
      i := 0;
      while i <= TWENTYTHREEMEGS div sizeof(Buffer^) do
        begin
          FMongoStream.Position := i * sizeof(TBuffer);
          PInt64(Buffer)^ := i * sizeof(TBuffer);
          FMongoStream.Write(Buffer^, sizeof(Buffer^));
          if i mod 3 = 0 then
            begin
              FMongoStream.Free;
              CreateTestFile(False);
            end;
          if i > 0 then
            begin
              FMongoStream.Position := (i - 1) * sizeof(TBuffer);
              ReturnValue := FMongoStream.Read(Buffer2^, sizeof(TBuffer));
              CheckEquals(Sizeof(Buffer^), ReturnValue, 'Number of bytes read dont''t match');
              PInt64(Buffer)^ := (i - 1) * sizeof(TBuffer);
              Check(CompareMem(Buffer, Buffer2, sizeof(Buffer^)), 'Memory read don''t match data written');
              FMongoStream.Position := (i + 1) * sizeof(TBuffer);
            end;
          inc(i, 1);
        end;
      FMongoStream.Position := 0;
      i := 0;
      while i <= TWENTYTHREEMEGS div sizeof(Buffer^) do
        begin
          ReturnValue := FMongoStream.Read(Buffer2^, sizeof(Buffer^));
          CheckEquals(Sizeof(Buffer^), ReturnValue, 'Number of bytes read dont''t match');
          PInt64(Buffer)^ := i * sizeof(TBuffer);
          Check(CompareMem(Buffer, Buffer2, sizeof(Buffer^)), 'Memory read don''t match data written');
          inc(i, 1);
        end;
    finally
      FreeMem(Buffer2);
    end;
  finally
    FreeMem(Buffer);
  end;
end;

procedure TestTMongoStream.TestWriteRead23MBFourThreadsThreeLoops;
begin
  InternalRunMultiThreaded(@TestTMongoStream.TestWriteRead23MB, 3);
end;

{ TMongoStreamThread }

constructor TMongoStreamThread.Create(ATestProc: Pointer; ALoops: Integer);
begin
  inherited Create(True);
  FTestMongoStream := TestTMongoStream.Create('TestStressWriteReads');
  FTestProc := ATestProc;
  FLoops := ALoops;
end;

destructor TMongoStreamThread.Destroy;
begin
  FTestMongoStream.Free;
  inherited;
end;

procedure TMongoStreamThread.Execute;
var
  i : integer;
  AMethod : TMethod;
begin
  try
    AMethod.Data := FTestMongoStream;
    AMethod.Code := FTestProc;
    for I := 0 to FLoops - 1 do
      begin
        FTestMongoStream.SetUp;
        TTestProc(AMethod);
        FTestMongoStream.MustDropDatabase := False;
        FTestMongoStream.TearDown;
      end;
  except
    on E : Exception do FErrorMessage := E.Message;
  end;
end;

procedure TestTMongoStream.Internal_TestEmptyFile;
const
  STR_EMPTYFILENAME : UTF8String = 'TestEmptyFile';
var
  FName : UTF8String;
begin
  FName := STR_EMPTYFILENAME + IntToStr(Random(MaxInt));
  FGridFS.removeFile(FName);
  Check(FGridFS.find(FName, False) = nil, 'File to create should not exist');
  try
    FMongoStream := TMongoStream.Create(FMongo, FSDB, FName, [], True); // Try to open file for read, should raise exception
  except
    // This segment of the test verifies the behavior that GridFS doesn't allow creating a stream NOT for "create" mode if the file
    // doesn't exist in DB
    on E : Exception do Check(pos('not found', E.Message) > 0, E.Message);
  end;
  FMongoStream.Free;
  FMongoStream := TMongoStream.Create(FMongo, FSDB, FName, [msmCreate], True); // Let's create an empty file
  FMongoStream.Free;
  FMongoStream := TMongoStream.Create(FMongo, FSDB, FName, [msmWrite], True); // Let's open the empty file
  CheckEquals(0, FMongoStream.Size, 'Size of stream should be zero');
end;

procedure TestTMongoStream.Internal_TestSetSize(NewSize: Integer);
var
  Buffer : Pointer;
  i : integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, length(FEW_BYTES_OF_DATA));
  FMongoStream.Size := NewSize;
  CheckEquals(NewSize, FMongoStream.Position, 'Position should be at the end of the file');
  FreeAndNil(FMongoStream);
  FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, [], True);
  CheckEquals(NewSize, FMongoStream.Size, 'New size was not taken by MongoStream');
  GetMem(Buffer, NewSize);
  try
    CheckEquals(NewSize, FMongoStream.Read(Buffer^, NewSize), 'Didn''t read all data as it should have');
    CheckEqualsString(FEW_BYTES_OF_DATA, PAnsiChar(Buffer), 'Initial part of data didn''t match');
    for i := length(FEW_BYTES_OF_DATA) to NewSize - 1 do
      CheckEquals(0, byte(PAnsiChar(Buffer)[i]), 'Every byte used to expand file should be a zero');
  finally
    FreeMem(Buffer);
  end;
end;

const
  ConcurrentReCreateOpenReadOnlyFileName = 'SpecialFileToTestConcurrency';

procedure TestTMongoStream.OpenStreamReadOnly;
var
  s : TStream;
begin
  s := TMongoStream.Create(FMongo, FSDB, ConcurrentReCreateOpenReadOnlyFileName, [], True);
  s.Free;
  inc(FOpenReadonlyLoops);
end;

procedure TestTMongoStream.RecreateStream;
var
  s : TStream;
begin
  s := TMongoStream.Create(FMongo, FSDB, ConcurrentReCreateOpenReadOnlyFileName, [msmCreate], True);
  s.Free;
  InterlockedIncrement(FRecreateLoops);
end;

procedure TestTMongoStream.TestEmptyFile;
begin
  Internal_TestEmptyFile;
end;

procedure TestTMongoStream.TestEmptyFileThenWriteSomeBytes;
var
  LittleData : UTF8String;
  ReadData : UTF8String;
begin
  Internal_TestEmptyFile;
  LittleData := 'LittleData';
  FMongoStream.Write(PAnsiChar(LittleData)^, length(LittleData));
  FMongoStream.Position := 0;
  SetLength(ReadData, length(LittleData));
  FMongoStream.Read(PAnsiChar(ReadData)^, length(ReadData));
  CheckEqualsString(LittleData, ReadData, 'Data read doesn''t match');
end;

procedure TestTMongoStream.TestParallelRecreateMongoStream;
const
  LOOPS = 200;
var
  ThreadRecreateStream : TMongoStreamThread;
  ThreadOpenReadonly : TMongoStreamThread;
  AErrorMessages : UTF8String;
begin
  FRecreateLoops := 0;
  FOpenReadonlyLoops := 0;
  FGridFS.removeFile(ConcurrentReCreateOpenReadOnlyFileName);
  ThreadRecreateStream := nil;
  ThreadOpenReadonly := nil;
  try
    ThreadRecreateStream := TMongoStreamThread.Create(@TestTMongoStream.RecreateStream, LOOPS);
    ThreadOpenReadonly := TMongoStreamThread.Create(@TestTMongoStream.OpenStreamReadOnly, LOOPS);
    ThreadRecreateStream.Resume;
    while FRecreateLoops <= 0 do Sleep(5);
    ThreadOpenReadonly.Resume;
    ThreadRecreateStream.WaitFor;
    ThreadOpenReadonly.WaitFor;
    AErrorMessages := '';
    if ThreadRecreateStream.ErrorMessage <> '' then
      AErrorMessages := AErrorMessages + ThreadRecreateStream.ErrorMessage + #13#10;
    if ThreadOpenReadonly.ErrorMessage <> '' then
      AErrorMessages := AErrorMessages + ThreadOpenReadonly.ErrorMessage + #13#10;
    if AErrorMessages <> '' then
      Fail(AErrorMessages + Format(' Recreate loops completed: %d. Open readonly loops completed: %d', [FRecreateLoops, FOpenReadonlyLoops]));
    CheckEquals(LOOPS, FRecreateLoops);
    CheckEquals(LOOPS, FOpenReadonlyLoops);
  finally
    if ThreadRecreateStream <> nil then
      ThreadRecreateStream.Free;
    if ThreadOpenReadonly <> nil then
      ThreadOpenReadonly.Free;
  end;
end;

procedure TestTMongoStream.TestReadEncryptedEnabledAndCompressionEnabled;
begin
  TestRead_Internal(True, True);
end;

procedure TestTMongoStream.TestRead_Internal(const AEncrypted: Boolean;
    ACompressed: Boolean; MultiChunkData: Boolean = False; VerySmallBlock:
    Boolean = False; AEncryptionBits: TAESKeyLength = akl128);
var
  ReturnValue: Integer;
  i, Count : Integer;
  AEncryptionKey : String;
  Data, Buffer, p : Pointer;
begin
  GetMem(Data, 1024 * 1024);
  try
    GetMem(Buffer, 1024 * 1024);
    try
      if MultiChunkData then
        begin
          Count := 1024 * 1024;
          p := Data;
          for i := 1 to Count div length(FEW_BYTES_OF_DATA) do
            begin
              move(PAnsiChar(FEW_BYTES_OF_DATA)^, p^, length(FEW_BYTES_OF_DATA));
              inc(PByte(p), length(FEW_BYTES_OF_DATA));
            end;
        end
        else
        begin
          if VerySmallBlock then
            Count := 6
          else Count := length(FEW_BYTES_OF_DATA);
          move(PAnsiChar(FEW_BYTES_OF_DATA)^, Data^, Count);
        end;
      if AEncrypted then
        AEncryptionKey := 'TestEncryptionKey'
      else AEncryptionKey := '';
      CreateTestFile(True, AEncryptionKey, ACompressed, AEncryptionBits);
      CheckMongoStreamPointer;
      CheckEquals(Count, FMongoStream.Write(Data^, Count), 'Number of bytes written don''t match');
      FreeAndNil(FMongoStream);
      CreateTestFile(False, AEncryptionKey, ACompressed, AEncryptionBits);
      ReturnValue := FMongoStream.Read(Buffer^, Count);
      CheckEquals(Count, ReturnValue, 'Number of bytes read dont''t match');
      Check(CompareMem(Buffer, Data, Count), 'Memory read don''t match data written');
    finally
      FreeMem(Buffer);
    end;
  finally
    FreeMem(Data);
  end;
end;

procedure TestTMongoStream.TestReadEncryptedEnabledAndCompressionDisabled;
begin
  TestRead_Internal(True, False);
end;

procedure TestTMongoStream.TestReadEncryptedDisabledAndCompressionDisabled;
begin
  TestRead_Internal(False, False);
end;

procedure
    TestTMongoStream.TestReadEncryptedDisabledAndCompressionDisabledOneMegOfData;
begin
  TestRead_Internal(False, False, True);
end;

procedure TestTMongoStream.TestReadEncryptedDisabledAndCompressionEnabled;
begin
  TestRead_Internal(False, True);
end;

procedure
    TestTMongoStream.TestReadEncryptedDisabledAndCompressionEnabledOneMegOfData;
begin
  TestRead_Internal(False, True, True);
end;

procedure TestTMongoStream.TestReadEncryptedEnabledAndCompressionDisabled6Bytes;
begin
  TestRead_Internal(True, False, False, True);
end;

procedure TestTMongoStream.TestReadEncryptedEnabledAndCompressionEnabled6Bytes;
begin
  TestRead_Internal(True, True, False, True);
end;

procedure
    TestTMongoStream.TestReadEncryptedEnabledAndCompressionDisabledOneMegOfData;
begin
  TestRead_Internal(True, False, True);
end;

procedure TestTMongoStream.TestReadEncryptedDisabledAndCompressionEnabled6Bytes;
begin
  TestRead_Internal(False, True, False, True);
end;

procedure
    TestTMongoStream.TestReadEncryptedDisabledAndCompressionDisabled6Bytes;
begin
  TestRead_Internal(False, False, False, True);
end;

procedure
    TestTMongoStream.TestReadEncryptedEnabledAndCompressionDisabled_256Bits;
begin
  TestRead_Internal(True, False, False, False, akl256);
end;

procedure
    TestTMongoStream.TestReadEncryptedEnabledAndCompressionDisabled_192Bits;
begin
  TestRead_Internal(True, False, False, False, akl192);
end;

procedure
    TestTMongoStream.TestReadEncryptedEnabledAndCompressionEnabledOneMegOfData;
begin
  TestRead_Internal(True, True, True);
end;

procedure
    TestTMongoStream.TestReadEncryptedEnabledAndCompressionEnabledOneMegOfData256Bits;
begin
  TestRead_Internal(True, True, True, False, akl256);
end;

procedure
    TestTMongoStream.TestReadEncryptedEnabledAndCompressionEnabledOneMegOfData192Bits;
begin
  TestRead_Internal(True, True, True, False, akl192);
end;

procedure TestTMongoStream.TestSetSizeMakeFileLarger;
var
  NewSize: Integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  FMongoStream.Write(PAnsiChar(FEW_BYTES_OF_DATA)^, length(FEW_BYTES_OF_DATA));
  NewSize := length(FEW_BYTES_OF_DATA) * 2;
  FMongoStream.Size := NewSize;
  CheckEquals(NewSize, FMongoStream.Position, 'Position should be at the end of the file');
  CheckEquals(NewSize, FMongoStream.Size, 'Size should be equals to NewSize');
  FreeAndNil(FMongoStream);
  FMongoStream := TMongoStream.Create(FMongo, FSDB, StandardRemoteFileName, [], True);
  CheckEquals(NewSize, FMongoStream.Size, 'New size was not taken by MongoStream');
end;

procedure TestTMongoStream.TestSetSizeMakeFileLargerOverOneChunk;
begin
  Internal_TestSetSize(256 * 1024 + 1024);
end;

procedure TestTMongoStream.TestSetSizeMakeFileLargerOverThreeChunks;
begin
  Internal_TestSetSize(256 * 1024 * 3 + 1024);
end;

procedure TestTMongoStream.TestStressEmptyFile;
var
  i : integer;
begin
  for i := 1 to 200 do
    TestEmptyFile;
end;

procedure TestTMongoStream.TestWriteEncryptedEnabled;
var
  ReturnValue: Integer;
  Count: Integer;
  Buffer: Pointer;
begin
  CreateTestFile(True, 'TestKey');
  CheckMongoStreamPointer;
  Count := length(FEW_BYTES_OF_DATA);
  Buffer := PAnsiChar(FEW_BYTES_OF_DATA);
  ReturnValue := FMongoStream.Write(Buffer^, Count);
  CheckEquals(Count, ReturnValue, 'Write didn''t return that I wrote the same amount of bytes written');
end;

procedure TestTMongoStream.TestWriteAndReadFromSameChunk;
var
  ReturnValue: Integer;
  Count: Integer;
  Buffer: Pointer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  Count := length(FEW_BYTES_OF_DATA);
  Buffer := PAnsiChar(FEW_BYTES_OF_DATA);
  ReturnValue := FMongoStream.Write(Buffer^, Count);
  CheckEquals(Count, ReturnValue, 'Write didn''t return that I wrote the same amount of bytes written');
  FMongoStream.Seek(1, soFromBeginning);
  GetMem(Buffer, length(FEW_BYTES_OF_DATA));
  try
    PAnsiChar(Buffer)[Count - 1] := #0;
    FMongoStream.Read(Buffer^, Count - 1);
    CheckEqualsString(copy(FEW_BYTES_OF_DATA, 2, length(FEW_BYTES_OF_DATA)), PAnsiChar(Buffer), 'String read after writing didn''t match');
  finally
    FreeMem(Buffer);
  end;
end;

procedure TestTMongoStream.TestWriteAndReadBackSomeChunks;
const
  BufSize = 1024 * 1024;
  ReadStart = 123;
  ReadReduction = 123 * 2;
var
  ReturnValue: Integer;
  Buffer, Buffer2: PAnsiChar;
  i : integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  GetMem(Buffer, BufSize + 1);
  try
    Buffer[BufSize] := #0;
    for i := 0 to BufSize - 1 do
      if (i + 1) mod 128 <> 0 then
        Buffer[i] := AnsiChar(Random(29) + ord('A'))
      else Buffer[i] := #13;
    ReturnValue := FMongoStream.Write(Buffer^, BufSize - 1);
    CheckEquals(BufSize - 1, ReturnValue, 'Write didn''t return that I wrote the same amount of bytes written');
    FMongoStream.Seek(ReadStart, soFromBeginning);
    Buffer[ReadStart] := 'Z';
    Buffer[ReadStart + 1] := 'A';
    Buffer[ReadStart + 2] := 'P';
    FMongoStream.Write(Buffer[ReadStart], 3);
    FMongoStream.Seek(ReadStart, soFromBeginning);
    GetMem(Buffer2, BufSize + 1);
    try
      Buffer2[BufSize - ReadStart - ReadReduction] := #0;
      FMongoStream.Read(Buffer2^, BufSize - ReadReduction - ReadStart);
      CheckEqualsString(copy(UTF8String(PAnsiChar(@Buffer[ReadStart])), 1, BufSize - ReadReduction - ReadStart), UTF8String(PAnsiChar(Buffer2)), 'String read after writing didn''t match');
    finally
      FreeMem(Buffer2);
    end;
  finally
    FreeMem(Buffer);
  end;
end;

procedure TestTMongoStream.TestWriteAndReadBackSomeChunksTryBoundaries;
const
  BufSize = 1024 * 1024;
  ReadStart = 123;
  ReadReduction = 123 * 2;
var
  ReturnValue: Integer;
  Buffer, Buffer2: PAnsiChar;
  i : integer;
begin
  CreateTestFile;
  CheckMongoStreamPointer;
  GetMem(Buffer, BufSize + 1);
  try
    Buffer[BufSize] := #0;
    for i := 0 to BufSize - 1 do
      if (i + 1) mod 128 <> 0 then
        Buffer[i] := AnsiChar(Random(29) + ord('A'))
      else Buffer[i] := #13;
    ReturnValue := FMongoStream.Write(Buffer^, BufSize - 1);
    CheckEquals(BufSize - 1, ReturnValue, 'Write didn''t return that I wrote the same amount of bytes written');
    FMongoStream.Seek(ReadStart, soFromBeginning);
    Buffer[ReadStart] := 'Z';
    Buffer[ReadStart + 1] := 'A';
    Buffer[ReadStart + 2] := 'P';
    Buffer[256 * 1024 - 1] := '+';
    FMongoStream.Write(Buffer[ReadStart], 3);
    FMongoStream.Seek(256 * 1024 - 1, soFromBeginning);
    FMongoStream.Write(Buffer[256 * 1024 - 1], 1);
    FMongoStream.Seek(ReadStart, soFromBeginning);
    FMongoStream.Write(Buffer[ReadStart], 3);
    FMongoStream.Seek(256 * 1024, soFromBeginning);
    FMongoStream.Seek(ReadStart, soFromBeginning);
    GetMem(Buffer2, BufSize + 1);
    try
      Buffer2[BufSize - ReadStart - ReadReduction] := #0;
      FMongoStream.Read(Buffer2^, BufSize - ReadReduction - ReadStart);
      CheckEqualsString(copy(UTF8String(PAnsiChar(@Buffer[ReadStart])), 1, BufSize - ReadReduction - ReadStart), UTF8String(PAnsiChar(Buffer2)), 'String read after writing didn''t match');
    finally
      FreeMem(Buffer2);
    end;
  finally
    FreeMem(Buffer);
  end;
end;

procedure TestTMongoStream.TestWriteCloseOverwriteAndReadSmallFileEncrypted;
begin
  TestWriteCloseOverwriteAndReadSmallFile_Internal('TestOfKey');
end;

procedure TestTMongoStream.TestWriteCloseOverwriteAndReadSmallFile;
begin
  TestWriteCloseOverwriteAndReadSmallFile_Internal('');
end;

procedure TestTMongoStream.TestWriteCloseOverwriteAndReadSmallFile_Internal(
    const AEncryptionKey: String);
const
  s : UTF8String = 'sss';
  s2 : UTF8String = 'new data';
var
  Readbuff : UTF8String;
begin
  CreateTestFile(True, AEncryptionKey, True, akl256);
  FMongoStream.Write(PAnsiChar(s)^, length(s));
  FreeAndNil(FMongoStream);
  CreateTestFile(False, AEncryptionKey, True, akl256);
  CheckEquals(length(s), FMongoStream.Size, 'Size of stream should match length of s2');
  SetLength(Readbuff, FMongoStream.Size);
  FMongoStream.Read(PAnsiChar(ReadBuff)^, FMongoStream.Size);
  CheckEqualsString(s, ReadBuff, 'Read data doesn''t match expected data');
  FMongoStream.Position := 0;
  FMongoStream.Write(PAnsiChar(s2)^, length(s2));
  FreeAndNil(FMongoStream);
  CreateTestFile(False, AEncryptionKey, True, akl256);
  CheckEquals(length(s2), FMongoStream.Size, 'Size of stream should match length of s2');
  SetLength(Readbuff, FMongoStream.Size);
  FMongoStream.Read(PAnsiChar(ReadBuff)^, FMongoStream.Size);
  CheckEqualsString(s2, ReadBuff, 'Read data doesn''t match expected data');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTMongoStream.Suite);
end.

