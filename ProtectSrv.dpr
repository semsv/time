program ProtectSrv;

// {$APPTYPE CONSOLE}

uses
  Windows,
  WinSvc,
  sysutils,
  forms,
  Uatom,
  ShellApi,
  Registry,
  inifiles,
  classes,
  DateUtils;

const ServiceName = 'ProtectSrv';

   var
    DispatchTable       : array [0..1] of _SERVICE_TABLE_ENTRYA;
    ServiceStatus       : SERVICE_STATUS;
    ServiceStatusHandle : SERVICE_STATUS_HANDLE;
    ServicePath         : String;

procedure LogError(text: string);
begin
{}
end;

function read_run_details(file_name : string; key : string; partition : string; defvalue : string) : string;
 var
  fn     : string;
  ls     : tstringlist;
  Ini_f  : Tinifile;
begin
      fn    := ServicePath + file_name;
      ini_f := TIniFile.Create(fn);
      ini_f.UpdateFile;
      if not fileexists(fn) then
       begin
        ls := TStringList.Create;
        ls.SaveToFile(fn);
        ls.Destroy;
        ini_f.WriteString(key, partition, defvalue);
       end;
      if not ini_f.ValueExists(key, partition) then
       ini_f.WriteString(key, partition, defvalue);
      result := ini_f.ReadString(key, partition, defvalue);
      ini_f.Destroy;
end;

procedure write_run_details(file_name : string; key : string; partition : string; value : string);
 var
  fn     : string;
  ls     : tstringlist;
  Ini_f  : Tinifile;
begin
      fn    := ServicePath + file_name;
      ini_f := TIniFile.Create(fn);
      ini_f.UpdateFile;
      if not fileexists(fn) then
       begin
        ls := TStringList.Create;
        ls.SaveToFile(fn);
        ls.Destroy;
       end;
      ini_f.WriteString(key, partition, value);
      ini_f.Destroy;
end;

function check_shutdown : boolean;
 Var
  i : integer;
  s : string;
begin
 result := false;
for i:= 1 to 10 do
  begin
   {}
     Application.ProcessMessages;
     s := read_run_details('Option.ini',
                           'ShutDownTimeEnableIndex',
                           'Index_' + inttostr(i),
                           'false');
     if s = 'cancel' then
      begin
        ShellExecute(0, nil, 'shutdown',' -a','', SW_SHOWNORMAL);
        write_run_details(
             'Option.ini',
             'ShutDownTimeEnableIndex',
             'Index_' + inttostr(i),
             'false');
        continue;
      end;
     if s = 'false' then continue;
   {}
   Application.ProcessMessages;
   s := read_run_details('Option.ini', 'ShutDownTime', 'Init_' + inttostr(i), '');
   if Length(s) <= 0 then break;
   if (s <> '00:00') and (StrToTimeDef(S, strtotime('00:00')) = strtotime('00:00')) then continue;
   if (StrToTimeDef(S, strtotime('00:00')) >= strtotime('00:00')) and
      (StrToTimeDef(S, strtotime('00:00')) <  strtotime('11:59')) then
   if (StrToTimeDef(timetostr(time), strtotime('00:00')) >= strtotime('00:00')) and
      (StrToTimeDef(timetostr(time), strtotime('00:00')) <  strtotime('11:59')) then
    begin
     if (StrToTime(s) < TimeOf(time)) and (TimeOf(time) - StrToTime(s) < strtotime('00:05:30')) then
      begin
       write_run_details(
          'Option.ini',
          'ShutDownTimeEnableIndex',
          'Index_' + inttostr(i),
          'false');
       result := true;
       break;
      end;
    end;

   if (StrToTimeDef(S, strtotime('00:00')) >= strtotime('11:59')) and
      (StrToTimeDef(S, strtotime('00:00')) <  strtotime('23:59')) then
   if (StrToTimeDef(timetostr(time), strtotime('00:00')) >= strtotime('11:59')) and
      (StrToTimeDef(timetostr(time), strtotime('00:00')) <  strtotime('23:59')) then
    begin
     if (StrToTime(s) < TimeOf(time)) and (TimeOf(time) - StrToTime(s) < strtotime('00:05:30')) then
      begin
       write_run_details(
          'Option.ini',
          'ShutDownTimeEnableIndex',
          'Index_' + inttostr(i),
          'false');
       result := true;
       break;
      end;
    end;
 end;   
end;

procedure ServiceCtrlHandler(Opcode: Cardinal); stdcall;
var
  Status: Cardinal;
begin
  case Opcode of
    SERVICE_CONTROL_PAUSE:
      begin
        ServiceStatus.dwCurrentState := SERVICE_PAUSED;
        {}
      end;
    SERVICE_CONTROL_CONTINUE:
      begin
        ServiceStatus.dwCurrentState := SERVICE_RUNNING;
        {}
      end;
    SERVICE_CONTROL_SHUTDOWN:
     begin

     end;
    SERVICE_CONTROL_STOP:
      begin
        {}
         ServiceStatus.dwWin32ExitCode := 0;
         ServiceStatus.dwCurrentState  := SERVICE_STOPPED;
         ServiceStatus.dwCheckPoint    := 0;
         ServiceStatus.dwWaitHint      := 0;
        {}
        if not SetServiceStatus(ServiceStatusHandle, ServiceStatus) then
        begin
          Status := GetLastError;
          LogError('SetServiceStatus:' + inttostr(Status));
          Exit;
        end;
        exit; {}
      end;

    SERVICE_CONTROL_INTERROGATE: ;
  end;

  if not SetServiceStatus(ServiceStatusHandle, ServiceStatus) then
  begin
    Status := GetLastError;
    LogError('SetServiceStatus:' + inttostr(Status));
    Exit;
  end;
end;

function ServiceInitialization(argc: DWORD; var argv: array of PChar; se: DWORD): integer;
 Var
  REESTOR : TREGISTRY;
  i       : integer;
begin
{-- Здесь выполняем инициализацию --}
   result           := 1;
{}
   REESTOR          := TREGISTRY.Create;
   REESTOR.RootKey  := HKEY_LOCAL_MACHINE;
   if REESTOR.OpenKey('\SYSTEM\CurrentControlSet\Services\' + ServiceName + '\', false) then
    begin
     ServicePath      := ExtractFilePath(REESTOR.ReadString('ImagePath'));
     if Length(ServicePath) > 0 then result := 0;
    end;
   REESTOR.CloseKey;
{}
 if result <> 0 then exit;
{}
 for i := 1 to 10 do
  begin
    write_run_details('Option.ini',
                      'ShutDownTimeEnableIndex',
                      'Index_' + inttostr(i),
                      'true');
  end;
{}
end;

procedure ServiceProc(argc: DWORD; var argv: array of PChar); stdcall;
var
  Status        : DWORD;
  SpecificError : DWORD;
  handle        : cardinal;
begin
 {}
  SpecificError := 0;
  ServiceStatus.dwServiceType := SERVICE_WIN32;
  ServiceStatus.dwCurrentState := SERVICE_START_PENDING;
  ServiceStatus.dwControlsAccepted := SERVICE_ACCEPT_STOP
    or SERVICE_ACCEPT_PAUSE_CONTINUE;
  ServiceStatus.dwWin32ExitCode := 0;
  ServiceStatus.dwServiceSpecificExitCode := 0;
  ServiceStatus.dwCheckPoint := 0;
  ServiceStatus.dwWaitHint := 0;

  ServiceStatusHandle :=
    RegisterServiceCtrlHandler(ServiceName, @ServiceCtrlHandler);
  if ServiceStatusHandle = 0 then
    WriteLn('RegisterServiceCtrlHandler Error');

  Status := ServiceInitialization(argc, argv, SpecificError);
  if Status <> NO_ERROR then
  begin
    ServiceStatus.dwCurrentState := SERVICE_STOPPED;
    ServiceStatus.dwCheckPoint := 0;
    ServiceStatus.dwWaitHint := 0;
    ServiceStatus.dwWin32ExitCode := Status;
    ServiceStatus.dwServiceSpecificExitCode := SpecificError;

    SetServiceStatus(ServiceStatusHandle, ServiceStatus);
    LogError('ServiceInitialization');
    exit;
  end;
  {}
   ServiceStatus.dwCurrentState := SERVICE_RUNNING;
  {}
  ServiceStatus.dwCheckPoint := 0;
  ServiceStatus.dwWaitHint   := 0;
  {}
  if not SetServiceStatus(ServiceStatusHandle, ServiceStatus) then
  begin
    Status := GetLastError;
    LogError('SetServiceStatus:' + IntToStr(Status));
    exit;
  end;
  {}
  handle := CreateEvent(nil, false, false, nil);
  repeat {--- Главный цикл работы программы ---}
   {}
   if check_shutdown then
    begin
      ShellExecute(0, nil, 'shutdown',' -s -t 180','', SW_SHOWNORMAL);
    end;
   {}
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   WaitForSingleObject(handle, 50);
   Application.ProcessMessages;
   {}
  until false;
{}


end;

function CreateNTService(ExecutablePath, ServiceName: string): boolean;
var
  hNewService, hSCMgr: SC_HANDLE;
  FuncRetVal: Boolean;
begin
  FuncRetVal := False;
  hSCMgr := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if (hSCMgr <> 0) then
  begin
  //  OpenService(hSCMgr, PChar(ServiceName), STANDARD_RIGHTS_REQUIRED);
    hNewService := CreateService(hSCMgr, PChar(ServiceName), PChar(ServiceName),
      STANDARD_RIGHTS_REQUIRED, SERVICE_WIN32_OWN_PROCESS,
      SERVICE_AUTO_START, SERVICE_ERROR_NORMAL,
      PChar(ExecutablePath), nil, nil, nil, nil, nil);
    CloseServiceHandle(hSCMgr);
    if (hNewService <> 0) then
      FuncRetVal := true
    else
      FuncRetVal := false;
  end;
  CreateNTService := FuncRetVal;
end;

function OpenNTService(ServiceName: string): boolean;
var
  hNewService, hSCMgr: SC_HANDLE;
  FuncRetVal: Boolean;
begin
  FuncRetVal := False;
  hSCMgr := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if (hSCMgr <> 0) then
  begin
    hNewService := OpenService(hSCMgr, PChar(ServiceName), STANDARD_RIGHTS_REQUIRED);
    CloseServiceHandle(hSCMgr);
    if (hNewService <> 0) then
      FuncRetVal := true
    else
      FuncRetVal := false;
  end;
  OpenNTService := FuncRetVal;
end;

function DeleteNTService(ServiceName: string): boolean;
var
  hServiceToDelete, hSCMgr: SC_HANDLE;
  RetVal: LongBool;
  FunctRetVal: Boolean;
begin
  FunctRetVal := false;
  hSCMgr := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if (hSCMgr <> 0) then
  begin
    hServiceToDelete := OpenService(hSCMgr, PChar(ServiceName),
      SERVICE_ALL_ACCESS);
    RetVal := DeleteService(hServiceToDelete);
    CloseServiceHandle(hSCMgr);
    FunctRetVal := RetVal;
  end;
  DeleteNTService := FunctRetVal;
end;

function ServiceStart(aMachine, aServiceName: string ): boolean;
// aMachine yoi UNC ioou, eeai eieaeuiue eiiiu?oa? anee ionoi
var
  h_manager,h_svc: SC_Handle;
  svc_status: TServiceStatus;
  Temp: PChar;
  dwCheckPoint: DWord;
begin
  svc_status.dwCurrentState := 1;
  h_manager := OpenSCManager(PChar(aMachine), nil, SC_MANAGER_CONNECT);
  if h_manager > 0 then
  begin
    h_svc := OpenService(h_manager, PChar(aServiceName),
    SERVICE_START or SERVICE_QUERY_STATUS);
    if h_svc > 0 then
    begin
      temp := nil;
      if (StartService(h_svc,0,temp)) then // exit else exit;
        if (QueryServiceStatus(h_svc,svc_status)) then
        begin
          while (SERVICE_RUNNING <> svc_status.dwCurrentState) do
          begin
            dwCheckPoint := svc_status.dwCheckPoint;
            Sleep(svc_status.dwWaitHint);
            if (not QueryServiceStatus(h_svc,svc_status)) then
              break;
            if (svc_status.dwCheckPoint < dwCheckPoint) then
            begin
              // QueryServiceStatus ia oaaee?eaaao dwCheckPoint
              break;
            end;
          end;
        end;
      CloseServiceHandle(h_svc);
    end;
    CloseServiceHandle(h_manager);
  end;
  Result := SERVICE_RUNNING = svc_status.dwCurrentState;
end;

function IS_ServiceStart(aMachine, aServiceName: string ): boolean;
// aMachine yoi UNC ioou, eeai eieaeuiue eiiiu?oa? anee ionoi
var
  h_manager,h_svc: SC_Handle;
  svc_status: TServiceStatus;
//  Temp: PChar;
//  dwCheckPoint: DWord;
begin
  svc_status.dwCurrentState := 1;
  h_manager := OpenSCManager(PChar(aMachine), nil, SC_MANAGER_CONNECT);
  if h_manager > 0 then
  begin
    h_svc := OpenService(h_manager, PChar(aServiceName), SERVICE_QUERY_STATUS);
    if h_svc > 0 then
    begin
//      temp := nil;
       if (QueryServiceStatus(h_svc,svc_status)) then
        begin
         {} 
        end;
      CloseServiceHandle(h_svc);
    end;
    CloseServiceHandle(h_manager);
  end;
  Result := SERVICE_RUNNING = svc_status.dwCurrentState;
end;

function ServiceStop(aMachine,aServiceName: string ): boolean;
// aMachine yoi UNC ioou, eeai eieaeuiue eiiiu?oa? anee ionoi
var
  h_manager, h_svc: SC_Handle;
  svc_status: TServiceStatus;
  dwCheckPoint: DWord;
begin
  h_manager:=OpenSCManager(PChar(aMachine),nil, SC_MANAGER_CONNECT);
  if h_manager > 0 then
  begin
    h_svc := OpenService(h_manager,PChar(aServiceName),
    SERVICE_STOP or SERVICE_QUERY_STATUS);
    if h_svc > 0 then
    begin
      if(ControlService(h_svc,SERVICE_CONTROL_STOP, svc_status))then
      begin
        if(QueryServiceStatus(h_svc,svc_status))then
        begin
          while(SERVICE_STOPPED <> svc_status.dwCurrentState)do
          begin
            dwCheckPoint := svc_status.dwCheckPoint;
            Sleep(svc_status.dwWaitHint);
            if(not QueryServiceStatus(h_svc,svc_status))then
            begin
              // couldn't check status
              break;
            end;
            if(svc_status.dwCheckPoint < dwCheckPoint)then
              break;
          end;
        end;
      end;
      CloseServiceHandle(h_svc);
    end;
    CloseServiceHandle(h_manager);
  end;
  Result := SERVICE_STOPPED = svc_status.dwCurrentState;
end;
{}
 Var
  REESTOR : TREGISTRY;
{}
begin
{}
 Sleep(300);
{}
 if OpenNTService(ServiceName) then
  if IS_ServiceStart('', ServiceName) then
   begin
    MessageBox(0, 'Сервис уже запущен, запуск нового сервиса невозможен до завершения работы старого!', 'Сообщение',0);
    exit;
   end;
{}
  DispatchTable[0].lpServiceName := ServiceName;
  DispatchTable[0].lpServiceProc := @ServiceProc;

  DispatchTable[1].lpServiceName := nil;
  DispatchTable[1].lpServiceProc := nil;

  if not StartServiceCtrlDispatcher(DispatchTable[0]) then
   else exit;
{--- Режим установки сервиса (сервис устанавливает сам себя)  ---}
 if OpenNTService(ServiceName) then
  if DeleteNTService(ServiceName) then
   begin
    {}
    ShellExecute(0, 'open', PChar(ExtractFilePath(paramstr(0)) + ServiceName + '.exe'),
                     nil, PChar(ExtractFilePath(paramstr(0))), SW_HIDE);
    {}                 
    Exit;
   end;
{}
 CreateNTService( ExtractFilePath(paramstr(0)) + ServiceName + '.exe', ServiceName);
 if ServiceStart('', ServiceName) then
  MessageBox(0, 'Инсталляция сервиса завершена успешно!', 'Сообщение',0) else
  MessageBox(0, 'Инсталляция сервиса завершена с ошибкой!', 'Сообщение',0);
{--- Добавляем описание к установленному сервису ---}
 REESTOR := TRegistry.Create;
 REESTOR.RootKey := HKEY_LOCAL_MACHINE;
 if REESTOR.OpenKey('\SYSTEM\CurrentControlSet\Services\' + ServiceName + '\', false) then
  begin
   Reestor.WriteString('Description',
    'EN: Service for Protect you PC. ' +
    'RUS: Сервис для Защиты Вашего ПК. ');
  end;
 REESTOR.CloseKey;
{}

//  DeleteNTService( ServiceName );

(*  CreateNTService( ExtractFilePath(paramstr(0)) + 'SZTT_Service.exe',
   ServiceName{ ExtractFileName(paramstr(0)){});
  ServiceStart('', ServiceName);

  exit; (**)
 (**)
 (*
  if (paramcount = 2) then
  begin
    if (lowercase(paramstr(1)) = '/i') then
    begin
      CreateNTService(paramstr(0), paramstr(2));
      exit;
    end;

    if (lowercase(paramstr(1)) = '/u') then
    begin
      DeleteNTService(paramstr(2));
      exit;
    end;

    if (lowercase(paramstr(1)) = '/ir') then
    begin
      CreateNTService(paramstr(0), paramstr(2));
      ServiceStart('', paramstr(2));
      exit;
    end;

    if (lowercase(paramstr(1)) = '/su') then
    begin
      DeleteNTService(paramstr(2));
      ServiceStop('', paramstr(2));
      exit;
    end;
  end; (**)
end.
