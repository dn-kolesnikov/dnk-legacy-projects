;
; "Таймер сна" ver. 0.1
; (с) 2004, Дмитрий Н. Колесников
;
    .386
    .MODEL FLAT,STDCALL
    OPTION CASEMAP:NONE
;
; ###################################################################

    include windows.inc
    include sleep-timer.inc

    include kernel32.inc
    include user32.inc
    include shell32.inc
    include advapi32.inc

    includelib kernel32.lib
    includelib user32.lib
    includelib shell32.lib
    includelib advapi32.lib

; ###################################################################
    m2m macro m1,m2
        push m2
        pop m1
    endm
; ###################################################################
;
        .DATA
;
        MinStr \
                    db '15',0
                    db '30',0
                    db '45',0
                    db '60',0
                    db '75',0
                    db '90',0
                    db '105',0
                    db '120',0
                    db '135',0
                    db '150',0
                    db '165',0
                    db '180',0
                    db 0

        TasksStr \
                    db 'выключить компьютер',0
                    db 'перезагрузить компьютер',0
                    db 0
;
        wnd_name    db '"Таймер сна" ver. 0.3c',0
        szShut      db "SeShutdownPrivilege",0
        formatStr   db '%d:%d',0
        timer_flag  db 0                                        ; = 1, если таймер установлен.
        task_numb   db 0                                        ; Номер задачи, которую нужно выполнить.
;
        NIData NOTIFYICONDATA <size NOTIFYICONDATA,?,0,NIF_ICON+NIF_TIP+\
                NIF_MESSAGE,WM_NOTIFYICON,?,'Таймер сна'>
;
        .DATA?
;
        time_line   db 10 dup(?)
        CurPos      POINT <>
        tkp         TOKEN_PRIVILEGES <>
;
        align 4
        hInst       dd ?                                        ; Хендл основного процесса.
        hMDlg       dd ?                                        ; Хендл основного диалога.
        hMenu       dd ?                                        ; Хендл меню.
        hTimer      dd ?                                        ; Хендл таймера.
        hToken      dd ?
        hButtonOK   dd ?
        Min         dd ?
        SecCount    dd ?
        TempCount   dd ?
;
        .CODE
;
_start:
        xor ebx,ebx
        invoke GetModuleHandle,ebx
        mov [hInst],eax
        invoke DialogBoxParam,eax,ID_TSDLG,ebx,offset TsDlgProc,ebx
        invoke ExitProcess,ebx
;
TsDlgProc proc uses edi hDlg:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
        mov eax,[uMsg]
        mov edi,[hDlg]
        xor ebx,ebx

        cmp eax,WM_COMMAND
        je @command
        cmp eax,WM_NOTIFYICON
        je @notifyicon
        cmp eax,WM_SIZE
        je @size
        cmp eax,WM_CLOSE
        je @close
        cmp eax,WM_INITDIALOG
        je @initdialog
        xor eax,eax
        jmp @finish

    @initdialog:
        mov [hMDlg],edi
        mov [NIData.hwnd],edi
        invoke LoadIcon,[hInst],ID_ICON                         ; Получим хендл нашей иконки.
        mov [NIData.hIcon],eax
        invoke SendMessage,edi,WM_SETICON,ICON_BIG,eax
        invoke SetWindowText,edi,offset wnd_name

        invoke GetDlgItem,edi,IDB_OK                            ; Получим хендл кнопки "Принять".
        mov [hButtonOK],eax

        invoke GetDlgItem,edi,IDC_MINCOUNT
        push offset MinStr
        push eax
        invoke SendMessage,eax,CB_LIMITTEXT,3,ebx
        call AddStrCB                                           ; Добавим массив строк в ComboBox.
        invoke GetDlgItem,edi,IDC_TASKS
        invoke AddStrCB,eax,offset TasksStr                     ; Добавим массив строк в ComboBox.

        invoke LoadMenu,[hInst],ID_MENU
        invoke GetSubMenu,eax,ebx
        mov [hMenu],eax
        jmp @processed

    @command:
        mov eax,[wParam]
        and eax,0FFFFh
        sub eax,100h
        jb @processed
        cmp eax,03h
        ja @processed
        jmp dword ptr buttons[eax*4]
;
    buttons \
        dd offset @idb_ok
        dd offset @idb_cancel
        dd offset @idb_about
        dd offset @close

    @idb_ok:
        invoke SendDlgItemMessage,edi,IDC_TASKS,CB_GETCURSEL,ebx,ebx
        cmp eax,CB_ERR
        je @processed
        mov [task_numb],al
        invoke GetDlgItemInt,edi,IDC_MINCOUNT,ebx,ebx
        or eax,eax
        jz @processed
        mov [Min],eax
        dec [Min]
        mov ecx,60000
        mul ecx
        push eax
        call GetTickCount
        pop ecx
        add eax,ecx
        mov [SecCount],eax
        invoke SetTimer,ebx,ebx,1000,offset TsTimerProc
        mov [hTimer],eax
        mov [timer_flag],1
        mov [TempCount],60
        invoke EnableWindow,[hButtonOK],ebx
        jmp @processed

    @id_cancel:
        cmp [timer_flag],bl
        je @processed
        invoke KillTimer,ebx,[hTimer]
        mov [timer_flag],bl
        invoke SetDlgItemInt,edi,IDC_MINCOUNT,ebx,ebx
        invoke SetDlgItemInt,edi,IDC_COUNTER,ebx,ebx
        invoke SendDlgItemMessage,edi,IDC_TASKS,CB_SETCURSEL,-1,ebx
        invoke EnableWindow,[hButtonOK],1
        jmp @processed

    @idb_about:
        invoke DialogBoxParam,[hInst],ID_ABOUT,edi,offset AboutProc,ebx
        jmp @processed

    @size:
        mov eax,[wParam]
        cmp eax,SIZE_MINIMIZED                                  ; Если нажали на кнопку "свернуть",
        jne @processed                                          ; то скроем наше окно и добавим
        invoke ShowWindow,edi,SW_HIDE                           ; иконку в системный трэй.
        invoke Shell_NotifyIcon,NIM_ADD,offset NIData
        jmp @processed

    @notifyicon:
        mov eax,[lParam]
        cmp eax,WM_LBUTTONUP                                    ; Если кликнули левой кнопкой по иконке
        jne @not_lbuttonup                                      ; в системном трэе, то показать наше окно,
        invoke ShowWindow,edi,SW_SHOWNORMAL                     ; и удалить иконку из трэя.
        invoke Shell_NotifyIcon,NIM_DELETE,offset NIData
        jmp @processed

    @not_lbuttonup:
        cmp eax,WM_RBUTTONUP                                    ; Если правой кнопкой,
        jne @processed                                          ; то показать контекстное меню.
        invoke GetCursorPos,offset CurPos
        invoke SetForegroundWindow,edi
        invoke TrackPopupMenu,[hMenu],TPM_LEFTALIGN+TPM_LEFTBUTTON,\
                                [CurPos.x],[CurPos.y],ebx,edi,ebx
        jmp @processed

    @close:
        cmp [timer_flag],bl
        je @F
        invoke KillTimer,ebx,[hTimer]
    @@:
        invoke Shell_NotifyIcon,NIM_DELETE,offset NIData
        invoke EndDialog,edi,ebx
    @processed:
        xor eax,eax
        inc eax
    @finish:
        ret
TsDlgProc endp
;
; Процедура TsTimerProc.
; Вызывается таймером, через указанный интервал времени
; (В нашем случае, каждую секунду).
;
TsTimerProc proc hWnd:DWORD,uMsg:DWORD,idEvent:DWORD,dwTime:DWORD
        mov eax,[dwTime]                                        ; В EAX число милисекунд, прошедших
                                                                ; с момента запуска Windows.
        cmp eax,[SecCount]
        jb @F
        xor ebx,ebx
        invoke KillTimer,ebx,[hTimer]                           ; Дизактивируем таймер
        mov [timer_flag],bl                                     ; и обнулим флаг.
        push esi
        xor eax,eax                                             ; В EAX номер задачи, которую необходимо выполнить.
        mov al,[task_numb]                                      ; 0 - выключить; 1 - перезагрузить.
        inc eax
        mov esi,eax
        invoke GetCurrentProcess                                ; get need privileges
        invoke OpenProcessToken,eax,TOKEN_ADJUST_PRIVILEGES+TOKEN_QUERY,offset hToken
        invoke LookupPrivilegeValue,NULL,offset szShut,offset tkp.Privileges[0].Luid
        mov [tkp.PrivilegeCount],1
        mov tkp.Privileges[0].Attributes,SE_PRIVILEGE_ENABLED
        invoke AdjustTokenPrivileges,[hToken],ebx,offset tkp,ebx,ebx,ebx
        invoke ExitWindowsEx,esi,ebx
        invoke PostMessage,[hMDlg],WM_CLOSE,ebx,ebx
        pop esi
        ret
    @@:
        dec [TempCount]
        jnz @F
        dec [Min]
        mov [TempCount],60
    @@:
        invoke wsprintf,offset time_line,offset formatStr,Min,TempCount
        invoke SetDlgItemText,[hMDlg],IDC_COUNTER,offset time_line
        ret
TsTimerProc endp
;
AboutProc proc hDlg:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
        mov eax,[uMsg]
        xor ebx,ebx
        cmp eax,WM_COMMAND
        je @close
        cmp eax,WM_CLOSE
        je @close
        xor eax,eax
        jmp @finish
    @close:
        invoke EndDialog,[hDlg],ebx
        xor eax,eax
        inc eax
    @finish:
        ret
AboutProc endp
;
AddStrCB proc uses esi hCBWnd:DWORD,lpzStr:DWORD
        mov esi,[lpzStr]
    @add_string:
        cmp byte ptr [esi],0
        je @finish
        invoke SendMessage,[hCBWnd],CB_ADDSTRING,0,esi
    @next_string:
        lodsb
        or al,al
        jnz @next_string
        jmp @add_string
    @finish:
        ret
AddStrCB endp
;
        end _start
