#import "Basic";

#scope_file

Win32 :: #import "Win32" (
    Memory = true,
    GDI_Basics = true,
    Windows_And_Messaging = true,
    Input = true,
    HiDpi = true,
);

g_all_windows : [..]*Window;
g_wndclass : Win32.WNDCLASSEXW;
g_custom_caption_wndclass : Win32.WNDCLASSEXW;
g_cursors : struct
{
    all : [SystemCursor.Count]Win32.HCURSOR;

    #place all;
    none : Win32.HCURSOR;
    arrow : Win32.HCURSOR;
    arrow_busy : Win32.HCURSOR;
    busy : Win32.HCURSOR;
    cross : Win32.HCURSOR;
    hand : Win32.HCURSOR;
    ibeam : Win32.HCURSOR;
    size : Win32.HCURSOR;
    size_nwse : Win32.HCURSOR;
    size_nesw : Win32.HCURSOR;
    size_horizontal : Win32.HCURSOR;
    size_vertical : Win32.HCURSOR;
    not_allowed : Win32.HCURSOR;
};

g_message_queue : [..]Message;

g_initialized : bool;

g_error_wide_buffer : [128]u16;
g_error_utf8_buffer : [512]u8;

GetLastErrorString :: inline () -> string #must
{
    return GetErrorString (Win32.GetLastError ());
}

GetErrorString :: inline (error_code : u32) -> string #must
{
    wide_count := Win32.FormatMessageW (
        .FORMAT_MESSAGE_FROM_SYSTEM | .FORMAT_MESSAGE_IGNORE_INSERTS,
        null,
        error_code,
        Win32.MAKELANGID (0, 0),
        g_error_wide_buffer.data,
        g_error_wide_buffer.count,
        null
    );

    utf8_count := Win32.WideCharToMultiByte (
        Win32.CP_UTF8,
        0,
        g_error_wide_buffer.data,
        cast (s32) wide_count,
        cast (*u8) g_error_utf8_buffer.data,
        g_error_utf8_buffer.count,
        null,
        null
    );

    result : string = ---;
    result.data  = g_error_utf8_buffer.data;
    result.count = utf8_count;

    return result;
}

// The result is null terminated even though a Jai string is returned
WideToUtf8 :: (data : *u16) -> string #must, success : bool
{
    result_length := Win32.WideCharToMultiByte (Win32.CP_UTF8, 0, data, -1, null, 0, null, null);
    if result_length <= 0
        return "", false;

    utf8_data := cast (*u8) alloc (result_length);

    written := Win32.WideCharToMultiByte (Win32.CP_UTF8, 0, data, -1, utf8_data, result_length, null, null);
    if written > 0
    {
        str : string = ---;
        str.data  = utf8_data;
        str.count = written - 1;

        return str, true;
    }

    return "", false;
}

// The result is null terminated
Utf8ToWide :: (utf8_str : string) -> wide_str : *u16 #must, length : s32
{
    if !utf8_str
    {
        wide_str := cast (*u16) alloc (size_of (u16));
        wide_str[0] = 0;

        return wide_str, 0;
    }

    result_length := Win32.MultiByteToWideChar (Win32.CP_UTF8, 0, utf8_str.data, cast (s32) utf8_str.count, null, 0);
    if result_length <= 0
        return null, 0;

    wide_str := cast (*u16) alloc ((result_length + 1) * size_of (u16));
    written := Win32.MultiByteToWideChar (Win32.CP_UTF8, 0, utf8_str.data, cast (s32) utf8_str.count, wide_str, result_length);
    if written > 0
    {
        wide_str[written] = 0;

        return wide_str, written;
    }

    return null, 0;
}

InitializeWindowClassesAndCursors :: ()
{
    if g_initialized
        return;

    defer g_initialized = true;

    {
        using g_wndclass;

        cbSize        = size_of (Win32.WNDCLASSEXW);
        style         = .CS_DBLCLKS | .CS_OWNDC;
        lpfnWndProc   = xx WindowProc;
        hInstance     = Win32.GetModuleHandleW (null);
        lpszClassName = Utf8ToWide ("WindowClass");

        ok := cast (bool) Win32.RegisterClassExW (*g_wndclass);
        assert (ok, "RegisterClassExW for WindowClass failed: %", GetLastErrorString ());
    }
    {
        using g_custom_caption_wndclass;

        cbSize        = size_of (Win32.WNDCLASSEXW);
        style         = .CS_DBLCLKS | .CS_OWNDC;
        lpfnWndProc   = xx CustomCaptionWindowProc;
        hInstance     = Win32.GetModuleHandleW (null);
        lpszClassName = Utf8ToWide ("CustomCaptionWindowClass");

        ok := cast (bool) Win32.RegisterClassExW (*g_custom_caption_wndclass);
        assert(ok, "RegisterClassExW for CustomCaptionWindowClass failed: %", GetLastErrorString ());
    }
    {
        g_cursors.none = null;
        g_cursors.arrow = Win32.LoadCursorW (null, Win32.IDC_ARROW);
        g_cursors.arrow_busy = Win32.LoadCursorW (null, Win32.IDC_APPSTARTING);
        g_cursors.busy = Win32.LoadCursorW (null, Win32.IDC_WAIT);
        g_cursors.cross = Win32.LoadCursorW (null, Win32.IDC_CROSS);
        g_cursors.hand = Win32.LoadCursorW (null, Win32.IDC_HAND);
        g_cursors.ibeam = Win32.LoadCursorW (null, Win32.IDC_IBEAM);
        g_cursors.size = Win32.LoadCursorW (null, Win32.IDC_SIZEALL);
        g_cursors.size_nwse = Win32.LoadCursorW (null, Win32.IDC_SIZENWSE);
        g_cursors.size_nesw = Win32.LoadCursorW (null, Win32.IDC_SIZENESW);
        g_cursors.size_horizontal = Win32.LoadCursorW (null, Win32.IDC_SIZEWE);
        g_cursors.size_vertical = Win32.LoadCursorW (null, Win32.IDC_SIZENS);
        g_cursors.not_allowed = Win32.LoadCursorW (null, Win32.IDC_NO);
    }

    mouse : Win32.RAWINPUTDEVICE;
    mouse.usUsagePage = 0x1;
    mouse.usUsage     = 0x2;
    Win32.RegisterRawInputDevices (*mouse, 1, size_of (Win32.RAWINPUTDEVICE));
}

#scope_export

CaptionHitTestProc :: #type (*Window, mouse_x : s32, mouse_y : s32) -> on_caption : bool;

Window :: struct
{
    hwnd : Win32.HWND;
    flags : WindowFlags;
    WM_CHAR_utf16_high_surrogate : u16;
    caption_hit_test : CaptionHitTestProc;
    mouse_is_outside : bool;
    cursor := SystemCursor.Arrow;
}

GetPlatformHandle :: inline (window : *Window) -> *void #must #no_context
{
    return window.hwnd;
}

GetWindowFromPlatformHandle :: inline (hwnd : *void) -> *Window #must #no_context
{
    for g_all_windows
    {
        if it.hwnd == hwnd
            return it;
    }

    return null;
}

ShowErrorBox :: inline (parent : *Window, fmt_str : string, args : ..Any)
{
    auto_release_temp ();

    str := tprint (fmt_str, ..args);
    Win32.MessageBoxW (
        ifx parent then parent.hwnd else null,
        Utf8ToWide (str,, temp),
        null,
        .MB_ICONERROR | .MB_OK
    );
}

ShowErrorBox :: inline (fmt_str : string, args : ..Any)
{
    ShowErrorBox (null, fmt_str, ..args);
}

DisplayInfo :: struct
{
    is_primary : bool;
    x, y, w, h : s32;
    dpi : s32;
}

GetDisplays :: inline () -> []DisplayInfo #must
{
    CountDisplayMonitors :: (
        monitor : Win32.HMONITOR,
        device_context : Win32.HDC,
        rect : *Win32.RECT,
        user_data : s64
    ) -> Win32.BOOL #c_call
    {
        (cast (*s64) user_data).* += 1;
        return 1;
    }

    UserData :: struct
    {
        displays : []DisplayInfo;
        index : s64;
    }

    AddDisplay :: (
        monitor : Win32.HMONITOR,
        device_context : Win32.HDC,
        rect : *Win32.RECT,
        user_data : s64
    ) -> Win32.BOOL #c_call
    {
        monitor_info : Win32.MONITORINFO;
        monitor_info.cbSize = size_of (Win32.MONITORINFO);
        Win32.GetMonitorInfoW (monitor, *monitor_info);

        using data := (cast (*UserData) user_data);
        if index >= displays.count
            return 0;

        displays[index].is_primary = (monitor_info.dwFlags & Win32.MONITORINFOF_PRIMARY) == Win32.MONITORINFOF_PRIMARY;
        displays[index].x = monitor_info.rcMonitor.left;
        displays[index].y = monitor_info.rcMonitor.top;
        displays[index].w = monitor_info.rcMonitor.right - monitor_info.rcMonitor.left;
        displays[index].h = monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top;

        // https://learn.microsoft.com/en-us/windows/win32/api/shellscalingapi/nf-shellscalingapi-getdpiformonitor
        // "The values of *dpiX and *dpiY are identical. You only need to record
        // one of the values to determine the DPI and respond appropriately."
        dpi_x : u32;
        if Win32.GetDpiForMonitor (monitor, .MDT_EFFECTIVE_DPI, *dpi_x, null) == 0
            displays[index].dpi = xx dpi_x;
        else
            displays[index].dpi = 96;

        index += 1;

        return 1;
    }

    count := 0;
    Win32.EnumDisplayMonitors (null, null, CountDisplayMonitors, cast (s64) *count);

    user_data : UserData;
    user_data.displays = NewArray (count, DisplayInfo);
    Win32.EnumDisplayMonitors (null, null, AddDisplay, cast (s64) *user_data);

    return user_data.displays;
}

CreateWindowExtraParams :: struct
{
    caption_hit_test : CaptionHitTestProc;
}

CreateWindow :: (
    title : string,
    width : s32, height : s32,
    x : s32 = Window_Default_Pos, y : s32 = Window_Default_Pos,
    flags : WindowFlags = 0,
    parent : *Window = null,
    extra : CreateWindowExtraParams = .{}
) -> *Window #must
{
    if !g_initialized
        InitializeWindowClassesAndCursors ();

    if x == Window_Default_Pos
        x = Win32.CW_USEDEFAULT;
    if y == Window_Default_Pos
        y = Win32.CW_USEDEFAULT;
    if width == Window_Default_Size
        width = Win32.CW_USEDEFAULT;
    if height == Window_Default_Size
        height = Win32.CW_USEDEFAULT;

    wndclass := ifx flags & .Custom_Caption then *g_custom_caption_wndclass else *g_wndclass;
    style : Win32.WINDOW_STYLE = .WS_OVERLAPPEDWINDOW;
    ex_style : Win32.WINDOW_EX_STYLE = .WS_EX_APPWINDOW;

    if flags & .Borderless
        style = .WS_POPUP;
    else if flags & .Custom_Caption
        style = .WS_THICKFRAME | .WS_SYSMENU | .WS_MAXIMIZEBOX | .WS_MINIMIZEBOX;

    if !(flags & .Hidden)
        style |= .WS_VISIBLE;

    if flags & .No_Taskbar_Icon
        ex_style = .WS_EX_TOOLWINDOW;

    if flags & .Topmost
        ex_style |= .WS_EX_TOPMOST;

    if flags & .No_Resize
        style ^= .WS_THICKFRAME | .WS_MAXIMIZEBOX;

    rect : Win32.RECT;
    if x != Win32.CW_USEDEFAULT
        rect.left = x;
    if y != Win32.CW_USEDEFAULT
        rect.top = y;
    rect.right = rect.left + width;
    rect.bottom = rect.top + height;

    Win32.AdjustWindowRect (*rect, style, 0);

    if x != Win32.CW_USEDEFAULT
        x = rect.left;
    if y != Win32.CW_USEDEFAULT
        y = rect.top;

    width = rect.right - rect.left;
    height = rect.bottom - rect.top;

    hwnd := Win32.CreateWindowExW (
        ex_style,
        wndclass.lpszClassName,
        Utf8ToWide (title,, temp),
        style,
        x,
        y,
        width,
        height,
        ifx parent then parent.hwnd else null,
        null,
        Win32.GetModuleHandleW (null),
        null
    );

    // Watch for the next event event
    track : Win32.TRACKMOUSEEVENT;
    track.cbSize = size_of (Win32.TRACKMOUSEEVENT);
    track.hwndTrack = hwnd;
    track.dwFlags = 0x02;
    Win32.TrackMouseEvent (*track);

    window := New (Window);
    window.hwnd = hwnd;
    window.caption_hit_test = extra.caption_hit_test;
    window.flags = flags;

    Win32.SetWindowLongPtrW (hwnd, .GWLP_USERDATA, cast (s64) window);
    array_add (*g_all_windows, window);

    return window;
}

DestroyWindow :: inline (window : *Window) #no_context
{
    // This just posts a WM_DESTROY message, freeing the window happens
    // when handling that message
    Win32.DestroyWindow (window.hwnd);
}

CloseWindow :: inline (window : *Window) #no_context
{
    Win32.PostMessageW (window.hwnd, Win32.WM_CLOSE, 0, 0);
}

GetWindowTitle :: inline (window : *Window) -> string #must
{
    len := Win32.GetWindowTextLengthW (window.hwnd) + 2;
    wide_buffer := cast (*u16) alloc (size_of (u16) * len,, temp);
    Win32.GetWindowTextW (window.hwnd, wide_buffer, len);

    return WideToUtf8 (wide_buffer);
}

SetWindowTitle :: inline (window : *Window, title : string)
{
    wide_title := Utf8ToWide (title,, temp);
    Win32.SetWindowTextW (window.hwnd, wide_title);
}

GetWindowPosition :: inline (window : *Window) -> x : s32, y : s32 #no_context
{
    rect : Win32.RECT;
    Win32.GetWindowRect (window.hwnd, *rect);

    return rect.left, rect.top;
}

SetWindowPosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
    Win32.SetWindowPos (window.hwnd, null, x, y, 0, 0, .SWP_NOSIZE | .SWP_NOZORDER | .SWP_NOACTIVATE);
}

GetWindowSize :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
    rect : Win32.RECT;
    Win32.GetWindowRect (window.hwnd, *rect);

    return rect.right - rect.left, rect.bottom - rect.top;
}

SetWindowSize :: inline (window : *Window, width : s32, height : s32) #no_context
{
    Win32.SetWindowPos (window.hwnd, null, 0, 0, width, height, .SWP_NOMOVE | .SWP_NOZORDER | .SWP_NOACTIVATE);
}

GetViewportPosition :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
    x, y := WindowToScreenPosition (window, 0, 0);

    return x, y;
}

SetViewportPosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
    style := cast, no_check (Win32.WINDOW_STYLE) Win32.GetWindowLongW (window.hwnd, .GWL_STYLE);
    ex_style := cast, no_check (Win32.WINDOW_EX_STYLE) Win32.GetWindowLongW (window.hwnd, .GWL_EXSTYLE);
    rect := Win32.RECT.{x, y, x, y};
    Win32.AdjustWindowRectEx (*rect, style, 0, ex_style);

    Win32.SetWindowPos (window.hwnd, null, rect.left, rect.top, 0, 0, .SWP_NOZORDER | .SWP_NOSIZE | .SWP_NOACTIVATE);
}

GetViewportSize :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
    rect : Win32.RECT;
    Win32.GetClientRect (window.hwnd, *rect);

    return rect.right - rect.left, rect.bottom - rect.top;
}

SetViewportSize :: inline (window : *Window, width : s32, height : s32) #no_context
{
    style := cast, no_check (Win32.WINDOW_STYLE) Win32.GetWindowLongW (window.hwnd, .GWL_STYLE);
    ex_style := cast, no_check (Win32.WINDOW_EX_STYLE) Win32.GetWindowLongW (window.hwnd, .GWL_EXSTYLE);
    rect := Win32.RECT.{0, 0, width, height};
    Win32.AdjustWindowRectEx (*rect, style, 0, ex_style);

    Win32.SetWindowPos (window.hwnd, null, 0, 0, rect.right - rect.left, rect.bottom - rect.top, .SWP_NOZORDER | .SWP_NOMOVE | .SWP_NOACTIVATE);
}

GetFocusedWindow :: () -> *Window #must, non_fenetres_window_focused : bool #no_context
{
    focused := Win32.GetFocus ();
    if !focused
        return null, false;

    for g_all_windows
    {
        if focused == it.hwnd
            return it, false;
    }

    return null, true;
}

SetFocusedWindow :: inline (window : *Window) #no_context
{
    Win32.SetFocus (window.hwnd);
}

IsFocused :: inline (window : *Window) -> bool #must #no_context
{
    return GetFocusedWindow () == window;
}

IsMaximized :: inline (window : *Window) -> bool #must #no_context
{
    placement : Win32.WINDOWPLACEMENT;
    placement.length = size_of (Win32.WINDOWPLACEMENT);
    if Win32.GetWindowPlacement (window.hwnd, *placement)
        return placement.showCmd == .SW_SHOWMAXIMIZED;

    return false;
}

IsMinimized :: inline (window : *Window) -> bool #must #no_context
{
    placement : Win32.WINDOWPLACEMENT;
    placement.length = size_of (Win32.WINDOWPLACEMENT);
    if Win32.GetWindowPlacement (window.hwnd, *placement)
        return placement.showCmd == .SW_SHOWMINIMIZED;

    return false;
}

Maximize :: inline (window : *Window) #no_context
{
    Win32.ShowWindow (window.hwnd, .SW_MAXIMIZE);
}

Restore :: inline (window : *Window) #no_context
{
    Win32.ShowWindow (window.hwnd, .SW_RESTORE);
}

Minimize :: inline (window : *Window) #no_context
{
    Win32.ShowWindow (window.hwnd, .SW_MINIMIZE);
}

SetWindowVisibility :: inline (window : *Window, visible : bool) #no_context
{
    if visible
        Win32.ShowWindow (window.hwnd, .SW_SHOWNA);
    else
        Win32.ShowWindow (window.hwnd, .SW_HIDE);
}

ShowAndFocusWindow :: inline (window : *Window) #no_context
{
    Win32.ShowWindow (window.hwnd, .SW_SHOW);
}

GetMousePosition :: inline () -> x : s32, y : s32 #no_context
{
    result : Win32.POINT;
    Win32.GetCursorPos (*result);

    return result.x, result.y;
}

SetMousePosition :: inline (x : s32, y : s32) #no_context
{
    p : Win32.POINT;
    p.x = x;
    p.y = y;
    Win32.SetCursorPos (p.x, p.y);
}

ScreenToWindowPosition :: inline (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context
{
    result := Win32.POINT.{x,y};
    Win32.ScreenToClient (window.hwnd, *result);

    return result.x, result.y;
}

WindowToScreenPosition :: inline (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context
{
    result := Win32.POINT.{x,y};
    Win32.ClientToScreen (window.hwnd, *result);

    return result.x, result.y;
}

GetMousePosition :: inline (window : *Window) -> x : s32, y : s32 #no_context
{
    result : Win32.POINT;
    Win32.GetCursorPos (*result);
    Win32.ScreenToClient (window.hwnd, *result);

    return result.x, result.y;
}

SetMousePosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
    p : Win32.POINT;
    p.x = x;
    p.y = y;
    Win32.ClientToScreen (window, *p);
    Win32.SetCursorPos (p.x, p.y);
}

SetMouseCapture :: inline (window : *Window, capture : bool) #no_context
{
    if capture
        Win32.SetCapture (window.hwnd);
    else
        Win32.ReleaseCapture ();
}

GetMouseCapture :: inline () -> *Window #must, non_fenetres_window : bool #no_context
{
    hwnd := Win32.GetCapture ();
    if !hwnd
        return null, false;

    window := GetWindowFromPlatformHandle (hwnd);
    if !window
        return null, true;

    return window, false;
}

PollMessages :: () -> []Message
{
    g_message_queue.count = 0;

    windows_msg : Win32.MSG;
    while Win32.PeekMessageW (*windows_msg, null, 0, 0, .PM_REMOVE)
    {
        Win32.TranslateMessage (*windows_msg);
        Win32.DispatchMessageW (*windows_msg);
    }

    return g_message_queue;
}

#scope_file

g_show_cursor : bool;

#scope_export

SetCursorVisibility :: inline (visible : bool) #no_context
#deprecated "Use SetCursor (window, .None) instead"
{
    if g_show_cursor == visible
        return;

    // This function does not behave like expected: see https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showcursor
    // "If bShow is TRUE, the display count is incremented by one. If bShow is FALSE, the display count is decremented by one."
    Win32.ShowCursor (xx visible);
    g_show_cursor = visible;
}

SetCursor :: inline (window : *Window, cursor : SystemCursor) #no_context
{
    if window.cursor != cursor
        Win32.SetCursor (g_cursors.all[cursor]);

    window.cursor = cursor;
}

SetCursorConstraint :: inline (x : s32, y : s32, w : s32, h : s32) -> bool #no_context
{
    rect : Win32.RECT = ---;
    rect.left = x;
    rect.top = y;
    rect.right = x + w;
    rect.bottom = y + h;

    return Win32.ClipCursor (*rect) != 0;
}

RemoveCursorConstraint :: inline () -> bool #no_context
{
    return Win32.ClipCursor (null) != 0;
}

VKToMouseButton :: inline (vk : Win32.VIRTUAL_KEY) -> MouseButton #must #no_context
{
    if vk ==
    {
    case .VK_LBUTTON;
        return .Left;
    case .VK_RBUTTON;
        return .Right;
    case .VK_MBUTTON;
        return .Middle;
    }

    return .Invalid;
}

MouseButtonToVK :: inline (button : MouseButton) -> Win32.VIRTUAL_KEY #must #no_context
{
    if button ==
    {
    case .Left;
        return .VK_LBUTTON;
    case .Right;
        return .VK_RBUTTON;
    case .Middle;
        return .VK_MBUTTON;
    }

    return xx 0;
}

VKToKeyCode :: (vk : Win32.VIRTUAL_KEY) -> KeyCode #must #no_context
{
    #insert -> string
    {
        builder : String_Builder;

        append (*builder, "if vk ==\n{\n");
        for VK_To_Key_Code_Map
        {
            print_to_builder (*builder, "case .%; return .%;\n", it.vk, it.key_code);
        }
        append (*builder, "}\n");

        return builder_to_string (*builder);
    };

    return .Invalid;
}

KeyCodeToVK :: (key_code : KeyCode) -> Win32.VIRTUAL_KEY #must #no_context
{
    #insert -> string
    {
        builder : String_Builder;

        append (*builder, "if key_code ==\n{\n");
        for VK_To_Key_Code_Map
        {
            print_to_builder (*builder, "case .%; return .%;\n", it.key_code, it.vk);
        }
        append (*builder, "}\n");

        return builder_to_string (*builder);
    };

    return 0;
}

GetKeyModState :: inline () -> KeyMods #must #no_context
{
    result : KeyMods;
    if (Win32.GetAsyncKeyState (xx Win32.VIRTUAL_KEY.VK_CONTROL) & 0x8000) != 0
        result |= .Ctrl;
    if (Win32.GetAsyncKeyState (xx Win32.VIRTUAL_KEY.VK_SHIFT) & 0x8000) != 0
        result |= .Shift;
    if (Win32.GetAsyncKeyState (xx Win32.VIRTUAL_KEY.VK_MENU) & 0x8000) != 0
        result |= .Alt;

    return result;
}

GetClipboardTextData :: () -> string #must
{
    if !Win32.OpenClipboard (null)
        return "";

    defer Win32.CloseClipboard ();

    data := Win32.GetClipboardData (xx Win32.CLIPBOARD_FORMATS.CF_UNICODETEXT);
    if !data
        return "";

    buffer := Win32.GlobalLock (cast (s64) data);
    defer Win32.GlobalUnlock (cast (s64) data);

    return WideToUtf8 (buffer);
}

SetClipboardTextData :: (text : string)
{
    if !Win32.OpenClipboard (null)
        return;

    defer Win32.CloseClipboard ();

    wide_str, wide_len := Utf8ToWide (text,, temp);

    clipbuffer := cast (*void) Win32.GlobalAlloc (0, xx (wide_len * 2 + 2));

    buffer := Win32.GlobalLock (cast (s64) clipbuffer);
    memcpy (buffer, wide_str, wide_len * 2 + 2);
    Win32.GlobalUnlock (cast (s64) clipbuffer);

    Win32.SetClipboardData (xx Win32.CLIPBOARD_FORMATS.CF_UNICODETEXT, clipbuffer);
}

ClearClipboard :: inline ()
{
    if !Win32.OpenClipboard (null)
        return;

    Win32.EmptyClipboard ();
    Win32.CloseClipboard ();
}

#scope_file

Keystroke :: struct
{
    repeat_count : s16;
    scan_code : u8;
    extended : bool;
    previous_key_state : bool;
    transition_state : bool;
    alt_down : bool;
    dialog_mode : bool;
    menu_mode : bool;
}

DecomposeKeystrokeParam :: inline (lparam : Win32.LPARAM) -> Keystroke #must
{
    using result : Keystroke;
    repeat_count = Win32.LOWORD (lparam);
    scan_code = cast, no_check (u8) Win32.HIWORD (lparam);
    extended           = (Win32.HIWORD (lparam) & Win32.KF_EXTENDED) == Win32.KF_EXTENDED;
    previous_key_state = (Win32.HIWORD (lparam) & Win32.KF_REPEAT) == Win32.KF_REPEAT;
    transition_state   = (Win32.HIWORD (lparam) & Win32.KF_UP) == Win32.KF_UP;
    alt_down           = (Win32.HIWORD (lparam) & Win32.KF_ALTDOWN) == Win32.KF_ALTDOWN;
    dialog_mode        = (Win32.HIWORD (lparam) & Win32.KF_DLGMODE) == Win32.KF_DLGMODE;
    menu_mode          = (Win32.HIWORD (lparam) & Win32.KF_MENUMODE) == Win32.KF_MENUMODE;

    return result;
}

WindowProc :: (hwnd : Win32.HWND, msg : u32, wparam : Win32.WPARAM, lparam : Win32.LPARAM) -> Win32.LRESULT
#c_call
{
    window := cast (*Window) Win32.GetWindowLongPtrW (hwnd, .GWLP_USERDATA);
    if !window
        return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

    window_message : Message;
    window_message.window = window;

    ctx : Context;
    push_context ctx
    {
        if msg ==
        {
        case Win32.WM_DESTROY;
            for g_all_windows
            {
                if it == window
                {
                    remove it;
                    break;
                }
            }

            free (window);
            Win32.SetWindowLongPtrW (hwnd, .GWLP_USERDATA, cast (s64) null);

        case Win32.WM_MOVE;
            window_message.kind = .Window_Moved;
            window_message.window_x = Win32.LOWORD (lparam);
            window_message.window_y = Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_SIZE;
            if wparam ==
            {
            case Win32.SIZE_RESTORED;
                window_message.kind = .Window_Resized;
            case Win32.SIZE_MINIMIZED;
                window_message.kind = .Window_Minimized;
            case Win32.SIZE_MAXIMIZED;
                window_message.kind = .Window_Maximized;
            }
            window_message.viewport_w = Win32.LOWORD (lparam);
            window_message.viewport_h = Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_CLOSE;
            window_message.kind = .Window_Closed;
            array_add (*g_message_queue, window_message);

        case Win32.WM_SHOWWINDOW;
            if wparam
                window_message.kind = .Window_Shown;
            else
                window_message.kind = .Window_Hidden;
            array_add (*g_message_queue, window_message);

        case Win32.WM_SETFOCUS;
            window_message.kind = .Window_Received_Focus;
            array_add (*g_message_queue, window_message);

        case Win32.WM_KILLFOCUS;
            window_message.kind = .Window_Lost_Focus;
            array_add (*g_message_queue, window_message);

        case Win32.WM_CHAR;
            codepoint := cast (u32) wparam;
            Utf16_Hi_Surrogate  :: cast (u16) 0xd800;
            Utf16_Lo_Surrogate  :: cast (u16) 0xdc00;
            Utf16_Surrogate_End :: cast (u16) 0xdfff;

            if codepoint >= Utf16_Hi_Surrogate && codepoint < Utf16_Lo_Surrogate
            {
                window.WM_CHAR_utf16_high_surrogate = cast (u16) codepoint;
            }
            else
            {
                if codepoint >= Utf16_Lo_Surrogate && codepoint <= Utf16_Surrogate_End
                {
                    low_surrogate := cast (u16) codepoint;
                    codepoint  = (window.WM_CHAR_utf16_high_surrogate - Utf16_Hi_Surrogate) << 10;
                    codepoint += (low_surrogate - Utf16_Lo_Surrogate);
                    codepoint += 0x10000;
                }

                if codepoint > 31 && codepoint != 127
                {
                    window_message.kind = .Text_Input;
                    window_message.mods = GetKeyModState ();
                    window_message.codepoint = codepoint;
                    array_add (*g_message_queue, window_message);
                }
            }

        case Win32.WM_SYSKEYDOWN; #through;
        case Win32.WM_SYSKEYUP; #through;
        case Win32.WM_KEYDOWN; #through;
        case Win32.WM_KEYUP;
            using keystroke := DecomposeKeystrokeParam (lparam);

            if msg == Win32.WM_KEYUP || msg == Win32.WM_SYSKEYUP
                window_message.kind = .Key_Released;
            else if previous_key_state
                window_message.kind = .Key_Repeated;
            else
                window_message.kind = .Key_Pressed;

            window_message.mods = GetKeyModState ();

            if wparam == xx Win32.VIRTUAL_KEY.VK_CONTROL
            {
                wparam = xx ifx !extended then Win32.VIRTUAL_KEY.VK_LCONTROL else Win32.VIRTUAL_KEY.VK_RCONTROL;
            }
            else if wparam == xx Win32.VIRTUAL_KEY.VK_MENU
            {
                wparam = xx ifx !extended then Win32.VIRTUAL_KEY.VK_LMENU else Win32.VIRTUAL_KEY.VK_RMENU;
            }
            else if wparam == xx Win32.VIRTUAL_KEY.VK_SHIFT
            {
                wparam = Win32.MapVirtualKeyW (scan_code, Win32.MAPVK_VSC_TO_VK_EX);
            }

            window_message.key_code = VKToKeyCode (xx wparam);

            array_add (*g_message_queue, window_message);

            if msg == Win32.WM_SYSKEYDOWN || msg == Win32.WM_SYSKEYUP
                return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

        case Win32.WM_LBUTTONDOWN;
            window_message.kind = .Mouse_Button_Pressed;
            window_message.mouse_button = .Left;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_RBUTTONDOWN;
            window_message.kind = .Mouse_Button_Pressed;
            window_message.mouse_button = .Right;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_MBUTTONDOWN;
            window_message.kind = .Mouse_Button_Pressed;
            window_message.mouse_button = .Middle;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_LBUTTONUP;
            window_message.kind = .Mouse_Button_Released;
            window_message.mouse_button = .Left;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_RBUTTONUP;
            window_message.kind = .Mouse_Button_Released;
            window_message.mouse_button = .Right;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_MBUTTONUP;
            window_message.kind = .Mouse_Button_Released;
            window_message.mouse_button = .Middle;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_LBUTTONDBLCLK;
            window_message.kind = .Mouse_Button_Repeated;
            window_message.mouse_button = .Left;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_RBUTTONDBLCLK;
            window_message.kind = .Mouse_Button_Repeated;
            window_message.mouse_button = .Right;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_MBUTTONDBLCLK;
            window_message.kind = .Mouse_Button_Repeated;
            window_message.mouse_button = .Middle;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_MOUSEHWHEEL; #through;
        case Win32.WM_MOUSEWHEEL;
            window_message.kind = .Mouse_Wheel;
            window_message.mods = GetKeyModState ();
            if msg == Win32.WM_MOUSEHWHEEL
                window_message.mouse_wheel_x = Win32.HIWORD (wparam) / 120.0;
            else
                window_message.mouse_wheel_y = Win32.HIWORD (wparam) / 120.0;
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_MOUSEMOVE;
            if window.mouse_is_outside
            {
                window.mouse_is_outside = false;

                // Watch for the next WM_MOUSELEAVE event
                track : Win32.TRACKMOUSEEVENT;
                track.cbSize = size_of (Win32.TRACKMOUSEEVENT);
                track.hwndTrack = hwnd;
                track.dwFlags = 0x02;
                Win32.TrackMouseEvent (*track);

                enter_message := window_message;
                enter_message.kind = .Mouse_Entered_Window;
                enter_message.mods = GetKeyModState ();
                enter_message.mouse_x, enter_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
                array_add (*g_message_queue, enter_message);
            }

            window_message.kind = .Mouse_Moved;
            window_message.mods = GetKeyModState ();
            window_message.mouse_x, window_message.mouse_y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            array_add (*g_message_queue, window_message);

        case Win32.WM_MOUSELEAVE;
            window.mouse_is_outside = true;
            window_message.kind = .Mouse_Left_Window;
            array_add (*g_message_queue, window_message);

        case Win32.WM_INPUT;
            rawinput : Win32.RAWINPUT;

            size := cast (u32) size_of (Win32.RAWINPUT);
            Win32.GetRawInputData (cast (Win32.HRAWINPUT) lparam, .RID_INPUT, *rawinput, *size, size_of (Win32.RAWINPUTHEADER));

            if rawinput.header.dwType == xx Win32.RID_DEVICE_INFO_TYPE.RIM_TYPEMOUSE
            {
                mouse := rawinput.data.mouse;
                if mouse.usFlags & Win32.MOUSE_MOVE_RELATIVE == Win32.MOUSE_MOVE_RELATIVE
                && (mouse.lLastX != 0 || mouse.lLastY != 0)
                {
                    window_message.kind = .Mouse_Raw_Moved;
                    window_message.mods = GetKeyModState ();
                    window_message.mouse_delta_x = mouse.lLastX;
                    window_message.mouse_delta_y = mouse.lLastY;

                    array_add (*g_message_queue, window_message);

                    return 0;
                }
            }

            return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

        case Win32.WM_SETCURSOR;
            if Win32.LOWORD (lparam) == Win32.HTCLIENT
            {
                Win32.SetCursor (g_cursors.all[window.cursor]);

                return 0;
            }

            return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

        case Win32.WM_DISPLAYCHANGE;
            window_message.kind = .Display_Changed;
            array_add (*g_message_queue, window_message);

            return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

        case;
            return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);
        }
    }

    return 0;
}

CustomCaptionWindowProc :: (hwnd : Win32.HWND, msg : u32, wparam : Win32.WPARAM, lparam : Win32.LPARAM) -> Win32.LRESULT
#c_call
{
    window := cast (*Window) Win32.GetWindowLongPtrW (hwnd, .GWLP_USERDATA);
    if !window
        return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

    window_message : Message;

    ctx : Context;
    push_context ctx
    {
        if msg ==
        {
        case Win32.WM_CREATE;
            size_rect : Win32.RECT;
            Win32.GetWindowRect (hwnd, *size_rect);
            Win32.SetWindowPos (hwnd, null,
                size_rect.left, size_rect.top,
                size_rect.right - size_rect.left, size_rect.bottom - size_rect.top,
                .SWP_FRAMECHANGED | .SWP_NOMOVE | .SWP_NOSIZE
            );

            return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

        case Win32.WM_NCCALCSIZE;
            if wparam == 0
                return Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

            frame_x := Win32.GetSystemMetrics (.SM_CXFRAME);
            frame_y := Win32.GetSystemMetrics (.SM_CYFRAME);
            padding := Win32.GetSystemMetrics (.SM_CXPADDEDBORDER);
            params := cast (*Win32.NCCALCSIZE_PARAMS) lparam;

            client_rect := *params.rgrc[0];
            client_rect.right  -= frame_x + padding;
            client_rect.left   += frame_x + padding;
            client_rect.bottom -= frame_y + padding;

            if IsMaximized (window)
                client_rect.top += padding * 2;

            return 0;

        case Win32.WM_NCHITTEST;
            hit := Win32.DefWindowProcW (hwnd, msg, wparam, lparam);

            if hit ==
            {
            case Win32.HTNOWHERE; #through;
            case Win32.HTRIGHT; #through;
            case Win32.HTLEFT; #through;
            case Win32.HTTOPLEFT; #through;
            case Win32.HTTOP; #through;
            case Win32.HTTOPRIGHT; #through;
            case Win32.HTBOTTOMRIGHT; #through;
            case Win32.HTBOTTOM; #through;
            case Win32.HTBOTTOMLEFT;
                return hit;
            }

            cursor : Win32.POINT;
            cursor.x, cursor.y = Win32.LOWORD (lparam), Win32.HIWORD (lparam);
            Win32.ScreenToClient (hwnd, *cursor);

            on_caption := window.caption_hit_test && window.caption_hit_test (window, cursor.x, cursor.y);
            on_resize_border := cursor.y > 0 && cursor.y < Win32.GetSystemMetrics (.SM_CYFRAME) + Win32.GetSystemMetrics (.SM_CXPADDEDBORDER);

            // Don't resize when we are not on the caption, because we could be on
            // some UI elements. If we don't have a caption_hit_test, then ignore
            // that. The user should provide a hit test function anyway...
            if on_resize_border && (on_caption || !window.caption_hit_test)
                return Win32.HTTOP;
            else if on_caption
                return Win32.HTCAPTION;

            return Win32.HTCLIENT;
        }
    }

    return WindowProc (hwnd, msg, wparam, lparam);
}

VKKeyCodePair :: struct
{
    vk : Win32.VIRTUAL_KEY;
    key_code : KeyCode;
}

VK_To_Key_Code_Map :: VKKeyCodePair.[
    .{ .VK_BACK, .Backspace },
    .{ .VK_TAB, .Tab },
    .{ .VK_CLEAR, .Clear },
    .{ .VK_RETURN, .Return },
    .{ .VK_SHIFT, .Shift },
    .{ .VK_CONTROL, .Ctrl },
    .{ .VK_MENU, .Alt },
    .{ .VK_PAUSE, .Pause },
    .{ .VK_CAPITAL, .Caps_Lock },
    .{ .VK_ESCAPE, .Escape },
    .{ .VK_SPACE, .Space },
    .{ .VK_PRIOR, .Page_Up },
    .{ .VK_NEXT, .Page_Down },
    .{ .VK_END, .End },
    .{ .VK_HOME, .Home },
    .{ .VK_LEFT, .Left },
    .{ .VK_UP, .Up },
    .{ .VK_RIGHT, .Right },
    .{ .VK_DOWN, .Down },
    .{ .VK_SELECT, .Select },
    .{ .VK_PRINT, .Print },
    .{ .VK_EXECUTE, .Execute },
    .{ .VK_SNAPSHOT, .Print_Screen },
    .{ .VK_INSERT, .Insert },
    .{ .VK_DELETE, .Delete },
    .{ .VK_HELP, .Help },
    .{ .VK_0, .Zero },
    .{ .VK_1, .One },
    .{ .VK_2, .Two },
    .{ .VK_3, .Three },
    .{ .VK_4, .Four },
    .{ .VK_5, .Five },
    .{ .VK_6, .Six },
    .{ .VK_7, .Seven },
    .{ .VK_8, .Eight },
    .{ .VK_9, .Nine },
    .{ .VK_A, .A },
    .{ .VK_B, .B },
    .{ .VK_C, .C },
    .{ .VK_D, .D },
    .{ .VK_E, .E },
    .{ .VK_F, .F },
    .{ .VK_G, .G },
    .{ .VK_H, .H },
    .{ .VK_I, .I },
    .{ .VK_J, .J },
    .{ .VK_K, .K },
    .{ .VK_L, .L },
    .{ .VK_M, .M },
    .{ .VK_N, .N },
    .{ .VK_O, .O },
    .{ .VK_P, .P },
    .{ .VK_Q, .Q },
    .{ .VK_R, .R },
    .{ .VK_S, .S },
    .{ .VK_T, .T },
    .{ .VK_U, .U },
    .{ .VK_V, .V },
    .{ .VK_W, .W },
    .{ .VK_X, .X },
    .{ .VK_Y, .Y },
    .{ .VK_Z, .Z },
    .{ .VK_LWIN, .Left_Super },
    .{ .VK_RWIN, .Right_Super },
    .{ .VK_NUMPAD0, .Numpad0 },
    .{ .VK_NUMPAD1, .Numpad1 },
    .{ .VK_NUMPAD2, .Numpad2 },
    .{ .VK_NUMPAD3, .Numpad3 },
    .{ .VK_NUMPAD4, .Numpad4 },
    .{ .VK_NUMPAD5, .Numpad5 },
    .{ .VK_NUMPAD6, .Numpad6 },
    .{ .VK_NUMPAD7, .Numpad7 },
    .{ .VK_NUMPAD8, .Numpad8 },
    .{ .VK_NUMPAD9, .Numpad9 },
    .{ .VK_MULTIPLY, .Multiply },
    .{ .VK_ADD, .Add },
    .{ .VK_SEPARATOR, .Separator },
    .{ .VK_SUBTRACT, .Subtract },
    .{ .VK_DECIMAL, .Decimal },
    .{ .VK_DIVIDE, .Divide },
    .{ .VK_F1, .F1 },
    .{ .VK_F2, .F2 },
    .{ .VK_F3, .F3 },
    .{ .VK_F4, .F4 },
    .{ .VK_F5, .F5 },
    .{ .VK_F6, .F6 },
    .{ .VK_F7, .F7 },
    .{ .VK_F8, .F8 },
    .{ .VK_F9, .F9 },
    .{ .VK_F10, .F10 },
    .{ .VK_F11, .F11 },
    .{ .VK_F12, .F12 },
    .{ .VK_NUMLOCK, .Num_Lock },
    .{ .VK_SCROLL, .Scroll_Lock },
    .{ .VK_LSHIFT, .Left_Shift },
    .{ .VK_RSHIFT, .Right_Shift },
    .{ .VK_LCONTROL, .Left_Ctrl },
    .{ .VK_RCONTROL, .Right_Ctrl },
    .{ .VK_LMENU, .Left_Alt },
    .{ .VK_RMENU, .Right_Alt },
    .{ .VK_OEM_1, .OEM1 },
    .{ .VK_OEM_PLUS, .OEM_Plus },
    .{ .VK_OEM_COMMA, .OEM_Comma },
    .{ .VK_OEM_MINUS, .OEM_Minus },
    .{ .VK_OEM_PERIOD, .OEM_Period },
    .{ .VK_OEM_2, .OEM2 },
    .{ .VK_OEM_3, .OEM3 },
    .{ .VK_OEM_4, .OEM4 },
    .{ .VK_OEM_5, .OEM5 },
    .{ .VK_OEM_6, .OEM6 },
    .{ .VK_OEM_7, .OEM7 },
    .{ .VK_OEM_8, .OEM8 },
    .{ .VK_OEM_102, .OEM102 }
];
