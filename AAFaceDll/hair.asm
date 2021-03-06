.386
.model flat, c

EXTERN g_AA2Base:DWORD

EXTERN g_HairDialogProcReturnValue:DWORD
EXTERN GetHairSelectorIndex:PROC
EXTERN InitHairTab:PROC
EXTERN InitHairSelector:PROC
EXTERN HairDialogNotification:PROC
EXTERN HairDialogAfterInit:PROC
EXTERN InvalidHairNotifier:PROC

EXTERNDEF hairdialog_refresh_hair_inject:PROC
EXTERNDEF hairdialog_init_hair_inject:PROC
EXTERNDEF hairdialog_constructor_inject:PROC
EXTERNDEF hairdialog_hooked_dialog_proc:PROC
EXTERNDEF hairdialog_hooked_dialog_proc_afterinit:PROC
EXTERNDEF hairdialog_invalid_hair_loaded:PROC

.data
	hInstTmp DWORD 0
	returnAddress DWORD 0
.code


;constructor of hair dialog
;AA2Edit.exe+27EEC - FF 15 54435B00        - call dword ptr[AA2Edit.exe+2C4354]
hairdialog_constructor_inject:
	pop [returnAddress]
	mov dword ptr [hInstTmp], ecx
	mov eax, [g_AA2Base]
	add eax, 2C4354h
	mov eax, [eax]
	call eax ; original createDialogParam call
	push eax
	push [hInstTmp]
	push eax
	call InitHairSelector
	add esp, 8
	pop eax
	push [returnAddress]
	ret


;thiscall over edi at hair dialog initialisation (e.g after opening a new file or creating a new char).
;also, this is void (), so no need for extra parameter care n stuff
;AA2Edit.exe+1C45A - E8 01C00000           - call AA2Edit.exe+28460 (this=edi)
hairdialog_init_hair_inject:
	push 1 ; before = true
	push edi
	call InitHairTab
	add esp, 8
	mov eax, [g_AA2Base]
	add eax, 28460h
	call eax
	push 0
	push edi
	call InitHairTab
	add esp, 8
	ret

;setting hair after button press or when tabs are switched. ebx e [0:3] depending on tab
;AA2Edit.exe+280DA - E8 C1F3FEFF           - call AA2Edit.exe+174A0
;AA2Edit.exe+280DF - 0FB6 96 A0020000      - movzx edx,byte ptr[esi+000002A0]
;AA2Edit.exe+280E6 - 88 84 1A 9C060000     - mov[edx+ebx+0000069C],al
hairdialog_refresh_hair_inject:
	pop [returnAddress] ; since this is actually supposed to call something else, our return address
					  ; is kinda lying around after the parameters; and it shouldnt be there

	mov eax, [g_AA2Base]
	add eax, 174A0h
	call eax
	push eax ; save return value for now
	push eax ; lets make this value a parameter as well. the more info the better.
	mov eax, [esi+000002A0h]
	push eax ; and the tab
	call GetHairSelectorIndex
	add esp, 8 ; also, cdecl
	cmp eax, -1
	jne skipHairSelection ; if not -1, use this value
					  ; else, use original value from stack
	mov eax, [esp] 
  skipHairSelection:
	add esp, 4 ; clean eax from stack

	push [returnAddress] ; dont forget this one
	ret

;start of virtual handler of hair-dialog (REMEMBER TO REPLICATE THE FIRST 2 INSTRUCTIONS)
;AA2Edit.exe+28650 - 8B 44 24 08           - mov eax,[esp+08]
;AA2Edit.exe+28654 - 56                    - push esi
;AA2Edit.exe+28655 - 57                    - push edi
;AA2Edit.exe+28656 - 8B F9                 - mov edi,ecx
;AA2Edit.exe+28658 - 3D 11010000           - cmp eax,00000111
hairdialog_hooked_dialog_proc:
	; save ecx (since its this)
	push ecx
	; copy parameters [esp+C] [esp+10] [esp+14] [esp+18]
	push [esp+18h]
	push [esp+18h]
	push [esp+18h]
	push [esp+18h]
	push ecx
	call HairDialogNotification
	add esp, 14h ; cdecl
	pop ecx ; restore this
	cmp eax, 0
	je hairdialog_hooked_dialog_proc_exec_native
	;abort proc, return g_HairDialogProcReturnValue
	add esp, 4 ; get rid of our return point, so that ret will exit our hooked function
	mov eax, [g_HairDialogProcReturnValue]
	ret 10h ; we are now returning from (HWND, UMSG, WPARAM, LPARAM) and have to clear the parameters accordingly (stdcall)
  hairdialog_hooked_dialog_proc_exec_native:
	;remember that we had instructions to do (i think ret doesnt alter flags)
	mov eax, [esp+0Ch] ; thats C now
	;now we need to push esi, but the return value is in the way. shit.
	push [esp] ; duplicate return point
	mov [esp+4], esi ; "push" esi below our return point
	ret


;function that handles WM_INITDIALOG
;AA2Edit.exe+28674 - E8 97F8FFFF           - call AA2Edit.exe+27F10 <-- no parameters, but esi-thiscall (esi=edi=this)
;AA2Edit.exe+28679 - 5F                    - pop edi
;AA2Edit.exe+2867A - 33 C0                 - xor eax,eax
;AA2Edit.exe+2867C - 5E                    - pop esi
;AA2Edit.exe+2867D - C2 1000               - ret 0010
hairdialog_hooked_dialog_proc_afterinit:
	mov eax, [g_AA2Base]
	add eax, 27F10h
	call eax
	push esi
	call HairDialogAfterInit
	add esp, 4
	ret

;i hope this only gets lead to if a hair is invalid. we get injecetd in F8
;AA2Edit.exe+119CF2 - 74 0C                 - je AA2Edit.exe+119D00
;AA2Edit.exe+119CF4 - 8B 4C 24 1C           - mov ecx,[esp+1C]
;AA2Edit.exe+119CF8 - C6 84 0E 5C020000 00  - mov byte ptr[esi+ecx+0000025C],00
;AA2Edit.exe+119D00 - 33 D2                 - xor edx,edx
hairdialog_invalid_hair_loaded:
	pushad
	call InvalidHairNotifier
	popad
	mov byte ptr [esi+ecx+25Ch], 00
	ret
END