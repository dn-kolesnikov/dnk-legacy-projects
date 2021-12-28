;
TsDlgProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
TsTimerProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
AboutProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
AddStrCB PROTO :DWORD,:DWORD
;
ID_ABOUT                    equ 500h

ID_ICON                     equ 400h

ID_TSDLG                    equ 300h
    IDC_MINCOUNT            equ 301h
    IDC_TASKS               equ 302h
    IDC_COUNTER             equ 303h

IDB_OK                      equ 100h
IDB_CANCEL	                equ 101h
IDB_ABOUT                   equ 102h
IDB_EXIT                    equ 103h

ID_MENU                     equ 200h

WM_NOTIFYICON               equ WM_USER+100h
