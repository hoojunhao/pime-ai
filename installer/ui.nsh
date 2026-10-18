; PIME installer UI helpers.
; Generated with assistance from OpenAI GPT-5.6.

!include "nsDialogs.nsh"
!include "WinMessages.nsh"

!define UI_COLOR_LIGHT_BACKGROUND "F7F7F7"
!define UI_COLOR_LIGHT_SURFACE "FFFFFF"
!define UI_COLOR_LIGHT_TEXT "202020"
!define UI_COLOR_LIGHT_MUTED "5F6368"
!define UI_COLOR_LIGHT_ACCENT "0067C0"

!define UI_COLOR_DARK_BACKGROUND "202020"
!define UI_COLOR_DARK_SURFACE "2B2B2B"
!define UI_COLOR_DARK_TEXT "F5F5F5"
!define UI_COLOR_DARK_MUTED "C8C8C8"
!define UI_COLOR_DARK_ACCENT "60CDFF"

; Windows language identifiers. MUI language defines are emitted after this
; helper is included, so use the stable LANGID values here.
!define UI_LANG_TRADCHINESE 1028
!define UI_LANG_SIMPCHINESE 2052

Var UI_Dialog
Var UI_Control
Var UI_TitleFont
Var UI_HeaderFont
Var UI_SubtitleFont
Var UI_BodyFont
Var UI_FontFace
Var UI_IsDark
Var UI_ArchLabel

; SetCtlColors resolves color operands while compiling, so select literal
; palettes in generated runtime branches instead of passing color variables.
!macro PIME_SET_COLORS CONTROL LIGHT_TEXT LIGHT_BACKGROUND DARK_TEXT DARK_BACKGROUND
	${If} $UI_IsDark == 1
		SetCtlColors ${CONTROL} "${DARK_TEXT}" "${DARK_BACKGROUND}"
	${Else}
		SetCtlColors ${CONTROL} "${LIGHT_TEXT}" "${LIGHT_BACKGROUND}"
	${EndIf}
!macroend

!macro PIME_SET_TRANSPARENT CONTROL LIGHT_TEXT DARK_TEXT
	${If} $UI_IsDark == 1
		SetCtlColors ${CONTROL} "${DARK_TEXT}" "transparent"
	${Else}
		SetCtlColors ${CONTROL} "${LIGHT_TEXT}" "transparent"
	${EndIf}
!macroend

!macro PIME_THEME_PAGE_LABEL CONTROL_ID
	GetDlgItem $UI_Control $0 ${CONTROL_ID}
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_BACKGROUND}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_BACKGROUND}"
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1
!macroend

!macro PIME_DEFINE_THEME_FUNCTIONS PREFIX
Function ${PREFIX}UI_LoadTheme
	ClearErrors
	StrCpy $0 1
	ReadRegDWORD $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme"
	${If} ${Errors}
		StrCpy $0 1
	${EndIf}

	${If} $0 == 0
		StrCpy $UI_IsDark 1
	${Else}
		StrCpy $UI_IsDark 0
	${EndIf}
FunctionEnd

Function ${PREFIX}UI_ApplyTitleBarTheme
	StrCpy $0 $UI_IsDark
	System::Call 'dwmapi::DwmSetWindowAttribute(p $HWNDPARENT, i 20, *i r0, i 4) i.r1'
	${If} $1 != 0
		System::Call 'dwmapi::DwmSetWindowAttribute(p $HWNDPARENT, i 19, *i r0, i 4) i.r1'
	${EndIf}
FunctionEnd

Function ${PREFIX}UI_ExpandHeaderTitle
	GetDlgItem $UI_Control $HWNDPARENT 1037
	GetDlgItem $0 $HWNDPARENT 1038
	System::Store "S"
	System::Call 'USER32::GetWindowRect(p $UI_Control, @r1)'
	System::Call 'USER32::MapWindowPoints(p0, p $HWNDPARENT, p r1, i2)'
	System::Call '*$1(i.r2, i.r3, i.r4, i.r5)'
	System::Call 'USER32::GetWindowRect(p $0, @r6)'
	System::Call 'USER32::MapWindowPoints(p0, p $HWNDPARENT, p r6, i2)'
	System::Call '*$6(i, i, i, i.r7)'
	IntOp $4 $4 - $2
	IntOp $7 $7 - $3
	; The original label is top-aligned. Expand it through the former
	; subtitle row and vertically center the single-line page title.
	System::Call 'USER32::GetWindowLong(p $UI_Control, i -16) i.r0'
	IntOp $0 $0 | 0x0200
	System::Call 'USER32::SetWindowLong(p $UI_Control, i -16, i r0)'
	System::Call 'USER32::SetWindowPos(p $UI_Control, p0, i r2, i r3, i r4, i r7, i0x0034)'
	System::Store "L"
FunctionEnd

Function ${PREFIX}UI_ApplyShellTheme
	Call ${PREFIX}UI_LoadTheme
	Call ${PREFIX}UI_ApplyTitleBarTheme

	!insertmacro PIME_SET_COLORS $HWNDPARENT \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_BACKGROUND}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_BACKGROUND}"

	; Theme the standard navigation buttons. Unsupported theme classes fail safely.
	GetDlgItem $UI_Control $HWNDPARENT 1
	${If} $UI_IsDark == 1
		System::Call 'uxtheme::SetWindowTheme(p $UI_Control, w "DarkMode_Explorer", w "")'
	${Else}
		System::Call 'uxtheme::SetWindowTheme(p $UI_Control, w "Explorer", w "")'
	${EndIf}
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1

	GetDlgItem $UI_Control $HWNDPARENT 2
	${If} $UI_IsDark == 1
		System::Call 'uxtheme::SetWindowTheme(p $UI_Control, w "DarkMode_Explorer", w "")'
	${Else}
		System::Call 'uxtheme::SetWindowTheme(p $UI_Control, w "Explorer", w "")'
	${EndIf}
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1

	GetDlgItem $UI_Control $HWNDPARENT 3
	${If} $UI_IsDark == 1
		System::Call 'uxtheme::SetWindowTheme(p $UI_Control, w "DarkMode_Explorer", w "")'
	${Else}
		System::Call 'uxtheme::SetWindowTheme(p $UI_Control, w "Explorer", w "")'
	${EndIf}
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1

	; Keep the standard separator, but remove the MUI branding text beside it.
	ShowWindow $mui.Branding.Text ${SW_HIDE}

	; MUI header labels.
	GetDlgItem $UI_Control $HWNDPARENT 1037
	!insertmacro PIME_SET_TRANSPARENT $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_DARK_TEXT}"
	; MUI reserves a short single-line control here. Keep a dedicated font
	; and use the hidden subtitle row to provide enough line height.
	SendMessage $UI_Control ${WM_SETFONT} $UI_HeaderFont 1
	GetDlgItem $UI_Control $HWNDPARENT 1038
	ShowWindow $UI_Control ${SW_HIDE}
	Call ${PREFIX}UI_ExpandHeaderTitle

	; Current page and common controls used by License, Components and InstFiles.
	; MUI hosts standard pages in a nested #32770 dialog. Control 1018 is
	; only the outer placeholder and does not own the page's text controls.
	FindWindow $0 "#32770" "" $HWNDPARENT
	!insertmacro PIME_SET_COLORS $0 \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_BACKGROUND}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_BACKGROUND}"

	; Standard MUI page labels inherit the system button-face color. Make
	; them transparent so the content area uses one continuous background.
	!insertmacro PIME_THEME_PAGE_LABEL 1006
	!insertmacro PIME_THEME_PAGE_LABEL 1021
	!insertmacro PIME_THEME_PAGE_LABEL 1022
	!insertmacro PIME_THEME_PAGE_LABEL 1023
	!insertmacro PIME_THEME_PAGE_LABEL 1034
	!insertmacro PIME_THEME_PAGE_LABEL 1040
	!insertmacro PIME_THEME_PAGE_LABEL 1042
	!insertmacro PIME_THEME_PAGE_LABEL 1043

	GetDlgItem $UI_Control $0 1000
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_SURFACE}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_SURFACE}"
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1
	GetDlgItem $UI_Control $0 1032
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_SURFACE}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_SURFACE}"
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1
	GetDlgItem $UI_Control $0 1016
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_SURFACE}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_SURFACE}"
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1
FunctionEnd

Function ${PREFIX}UI_CreateFonts
	StrCpy $UI_FontFace "Segoe UI"
	${If} $LANGUAGE == ${UI_LANG_TRADCHINESE}
	${OrIf} $LANGUAGE == ${UI_LANG_SIMPCHINESE}
		StrCpy $UI_FontFace "Microsoft JhengHei"
	${EndIf}

	CreateFont $UI_TitleFont "$UI_FontFace" 18 600
	CreateFont $UI_HeaderFont "$UI_FontFace" 13 600
	CreateFont $UI_SubtitleFont "$UI_FontFace" 11 600
	CreateFont $UI_BodyFont "$UI_FontFace" 9 400
FunctionEnd

Function ${PREFIX}UI_DeleteFonts
	System::Call 'gdi32::DeleteObject(p $UI_TitleFont)'
	System::Call 'gdi32::DeleteObject(p $UI_HeaderFont)'
	System::Call 'gdi32::DeleteObject(p $UI_SubtitleFont)'
	System::Call 'gdi32::DeleteObject(p $UI_BodyFont)'
FunctionEnd

Function ${PREFIX}UI_Init
	Call ${PREFIX}UI_CreateFonts
	Call ${PREFIX}UI_ApplyShellTheme
FunctionEnd

Function ${PREFIX}UI_Uninit
	Call ${PREFIX}UI_DeleteFonts
FunctionEnd

Function ${PREFIX}UI_ThemePage
	Call ${PREFIX}UI_ApplyShellTheme
FunctionEnd
!macroend

!insertmacro PIME_DEFINE_THEME_FUNCTIONS ""
!insertmacro PIME_DEFINE_THEME_FUNCTIONS "un."

Function UI_ReloadFonts
	Call UI_DeleteFonts
	Call UI_CreateFonts
FunctionEnd

Function UI_ApplyCustomControlTheme
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_BACKGROUND}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_BACKGROUND}"
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1
FunctionEnd

Function UI_WelcomePageCreate
	; Hide and clear the previous page header before replacing its dialog.
	; Without this reset, navigating back from a MUI page can leave its title
	; painted underneath the custom page title.
	GetDlgItem $UI_Control $HWNDPARENT 1037
	ShowWindow $UI_Control ${SW_HIDE}
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:"
	GetDlgItem $UI_Control $HWNDPARENT 1038
	ShowWindow $UI_Control ${SW_HIDE}
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:"

	nsDialogs::Create 1018
	Pop $UI_Dialog
	${If} $UI_Dialog == error
		Abort
	${EndIf}

	; Apply the shell theme only after the new child dialog exists, then
	; reveal exactly one freshly painted header title.
	Call UI_ApplyShellTheme
	GetDlgItem $UI_Control $HWNDPARENT 1037
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:$(PRODUCT_NAME)"
	ShowWindow $UI_Control ${SW_SHOW}
	System::Call 'user32::RedrawWindow(p $HWNDPARENT, p0, p0, i 0x0585)'

	!insertmacro PIME_SET_COLORS $UI_Dialog \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_BACKGROUND}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_BACKGROUND}"

	${NSD_CreateLabel} 0 2u 4u 100% ""
	Pop $UI_Control
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_ACCENT}" "${UI_COLOR_LIGHT_ACCENT}" \
		"${UI_COLOR_DARK_ACCENT}" "${UI_COLOR_DARK_ACCENT}"

	${NSD_CreateLabel} 14u 8u -14u 28u "$(UI_WELCOME_TITLE)"
	Pop $UI_Control
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_BACKGROUND}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_BACKGROUND}"
	SendMessage $UI_Control ${WM_SETFONT} $UI_TitleFont 1

	${NSD_CreateGroupBox} 14u 39u -14u 48u "$(UI_SYSTEM_INFO)"
	Pop $UI_Control
	!insertmacro PIME_SET_COLORS $UI_Control \
		"${UI_COLOR_LIGHT_TEXT}" "${UI_COLOR_LIGHT_BACKGROUND}" \
		"${UI_COLOR_DARK_TEXT}" "${UI_COLOR_DARK_BACKGROUND}"
	SendMessage $UI_Control ${WM_SETFONT} $UI_BodyFont 1

	${If} ${IsNativeARM64}
		StrCpy $UI_ArchLabel "$(UI_ARCH_ARM64)"
	${ElseIf} ${RunningX64}
		StrCpy $UI_ArchLabel "$(UI_ARCH_X64)"
	${Else}
		StrCpy $UI_ArchLabel "$(UI_ARCH_X86)"
	${EndIf}

	${NSD_CreateLabel} 28u 53u -28u 14u "$(UI_VERSION_LABEL) ${PRODUCT_VERSION}"
	Pop $UI_Control
	Call UI_ApplyCustomControlTheme

	${NSD_CreateLabel} 28u 70u -28u 14u "$(UI_ARCH_LABEL) $UI_ArchLabel"
	Pop $UI_Control
	Call UI_ApplyCustomControlTheme

	nsDialogs::Show
FunctionEnd

Function UI_ThemeLicensePage
	GetDlgItem $UI_Control $HWNDPARENT 1037
	ShowWindow $UI_Control ${SW_HIDE}
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:"
	Call UI_ApplyShellTheme
	GetDlgItem $UI_Control $HWNDPARENT 1037
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:$(UI_LICENSE_TITLE)"
	ShowWindow $UI_Control ${SW_SHOW}
	FindWindow $0 "#32770" "" $HWNDPARENT
	GetDlgItem $UI_Control $0 1040
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:$(UI_LICENSE_HINT)"
	; Remove the bottom instruction and give its space to the license text.
	GetDlgItem $1 $0 1000
	GetDlgItem $2 $0 1006
	System::Store "S"
	System::Call 'USER32::GetWindowRect(p r1, @r3)'
	System::Call 'USER32::MapWindowPoints(p0, p r0, p r3, i2)'
	System::Call '*$3(i.r4, i.r5, i.r6, i.r7)'
	System::Call 'USER32::GetWindowRect(p r2, @r3)'
	System::Call 'USER32::MapWindowPoints(p0, p r0, p r3, i2)'
	System::Call '*$3(i, i, i, i.r8)'
	IntOp $6 $6 - $4
	IntOp $8 $8 - $5
	System::Call 'USER32::SetWindowPos(p r1, p0, i r4, i r5, i r6, i r8, i0x0034)'
	System::Store "L"
	ShowWindow $2 ${SW_HIDE}
	System::Call 'user32::RedrawWindow(p $HWNDPARENT, p0, p0, i 0x0585)'
FunctionEnd

Function UI_LayoutComponentsPage
	FindWindow $0 "#32770" "" $HWNDPARENT
	GetDlgItem $1 $0 1032
	GetDlgItem $2 $0 1022

	; Reserve a small margin above the bottom of the page content.
	System::Store "S"
	System::Call 'USER32::GetClientRect(p r0, @r3)'
	System::Call '*$3(i, i, i, i.r3)'
	IntOp $3 $3 - 8
	StrCpy $R0 $3

	; Move the component tree into the space occupied by the redundant
	; left-side label, leaving a narrow right rail.
	System::Call 'USER32::GetWindowRect(p r1, @r3)'
	System::Call 'USER32::MapWindowPoints(p0, p r0, p r3, i2)'
	System::Call '*$3(i.r4, i.r5, i.r6, i.r7)'
	IntOp $8 $6 - $4
	IntOp $9 $7 - $5
	System::Call 'USER32::GetWindowRect(p r2, @r3)'
	System::Call 'USER32::MapWindowPoints(p0, p r0, p r3, i2)'
	System::Call '*$3(i.r4)'

	; Replace the redundant install-type label with a compact combo box.
	; Half of the tree width is sufficient for every localized option.
	StrCpy $R1 $4
	StrCpy $R2 $6
	GetDlgItem $UI_Control $0 1006
	System::Call 'USER32::GetWindowRect(p $UI_Control, @r3)'
	System::Call 'USER32::MapWindowPoints(p0, p r0, p r3, i2)'
	System::Call '*$3(i, i.r3, i, i)'
	; The standard label is taller than its single rendered line. Position
	; relative to that line instead of preserving the invisible lower padding.
	IntOp $R3 $3 + 24

	GetDlgItem $UI_Control $0 1017
	System::Call 'USER32::GetWindowRect(p $UI_Control, @r3)'
	System::Call 'USER32::MapWindowPoints(p0, p r0, p r3, i2)'
	System::Call '*$3(i, i.r4, i, i.r7)'
	IntOp $3 $8 / 2
	IntOp $7 $7 - $4
	System::Call 'USER32::SetWindowPos(p $UI_Control, p0, i $R1, i $R3, i r3, i r7, i0x0034)'
	IntOp $5 $R3 + $7
	IntOp $5 $5 + 6
	IntOp $9 $R0 - $5
	StrCpy $4 $R1
	StrCpy $6 $R2

	System::Call 'USER32::SetWindowPos(p r1, p0, i r4, i r5, i r8, i r9, i0x0034)'

	; The tree's right edge becomes the right edge of the compact rail.
	; Grow the description with the tree and keep the space label at the bottom.
	IntOp $7 $4 + $8
	IntOp $7 $7 + 8
	IntOp $6 $6 - $7
	IntOp $8 $9 - 35

	GetDlgItem $UI_Control $0 1042
	System::Call 'USER32::SetWindowPos(p $UI_Control, p0, i r7, i r5, i r6, i r8, i0x0034)'

	IntOp $4 $7 + 9
	IntOp $3 $5 + 19
	IntOp $2 $6 - 18
	IntOp $1 $8 - 25
	GetDlgItem $UI_Control $0 1043
	System::Call 'USER32::SetWindowPos(p $UI_Control, p0, i r4, i r3, i r2, i r1, i0x0034)'

	IntOp $3 $5 + $8
	IntOp $3 $3 + 6
	IntOp $1 $9 - $8
	IntOp $1 $1 - 6
	GetDlgItem $UI_Control $0 1023
	System::Call 'USER32::SetWindowPos(p $UI_Control, p0, i r7, i r3, i r6, i r1, i0x0034)'

	; Extend only the scrollable tree through the unused vertical area.
	; Keep its top and width unchanged and stop above the content margin.
	GetDlgItem $UI_Control $0 1032
	System::Call 'USER32::GetWindowRect(p $UI_Control, @r3)'
	System::Call '*$3(i.r4, i, i.r6, i)'
	IntOp $4 $6 - $4
	IntOp $R0 $R0 - $5
	System::Call 'USER32::SetWindowPos(p $UI_Control, p0, i0, i0, i r4, i $R0, i0x0036)'
	System::Store "L"

	ShowWindow $2 ${SW_HIDE}
FunctionEnd

Function UI_ThemeComponentsPage
	GetDlgItem $UI_Control $HWNDPARENT 1037
	ShowWindow $UI_Control ${SW_HIDE}
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:"
	Call UI_ApplyShellTheme
	GetDlgItem $UI_Control $HWNDPARENT 1037
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:$(MUI_TEXT_COMPONENTS_TITLE)"
	ShowWindow $UI_Control ${SW_SHOW}

	FindWindow $0 "#32770" "" $HWNDPARENT
	GetDlgItem $UI_Control $0 1006
	SendMessage $UI_Control ${WM_SETTEXT} 0 "STR:$(UI_COMPONENTS_HINT)"
	Call UI_LayoutComponentsPage
	System::Call 'user32::RedrawWindow(p $HWNDPARENT, p0, p0, i 0x0585)'
FunctionEnd
