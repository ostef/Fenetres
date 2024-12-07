// @Todo: handle window width and height (= viewport size with caption and borders)
// @Todo: raw mouse movement
// @Todo: handle maximize/minimize events, show and hide events,
// display changed events

// To implement for ImGui Fenetres backend:
// GetDisplays
// GetClipboardTextData
// SetClipboardTextData
// ClearClipboard
// All Fenetres GL stuff

#import "Basic";
X11 :: #import "X11";

GetOpenedXDisplay :: inline () -> *X11.Display #must #no_context
{
    return g_display;
}

#scope_file

g_double_click_time_ms : u64 = 500;
g_display : *X11.Display;
g_wm_delete_window : X11.Atom;
g_wm_protocols : X11.Atom;
g_active_window : X11.Atom;
g_wm_state : X11.Atom;
g_wm_state_hidden : X11.Atom;
g_wm_state_maximized_vert : X11.Atom;
g_wm_state_maximized_horz : X11.Atom;
g_cursors : struct
{
    all : [SystemCursor.Count]X11.Cursor;

    #place all;
    none : X11.Cursor;
    arrow : X11.Cursor;
    arrow_busy : X11.Cursor;
    busy : X11.Cursor;
    cross : X11.Cursor;
    hand : X11.Cursor;
    ibeam : X11.Cursor;
    size : X11.Cursor;
    size_nwse : X11.Cursor;
    size_nesw : X11.Cursor;
    size_horizontal : X11.Cursor;
    size_vertical : X11.Cursor;
    not_allowed : X11.Cursor;
    size_left : X11.Cursor;
    size_right : X11.Cursor;
    size_top : X11.Cursor;
    size_bottom : X11.Cursor;
    size_top_left : X11.Cursor;
    size_top_right : X11.Cursor;
    size_bottom_left : X11.Cursor;
    size_bottom_right : X11.Cursor;
};

g_initialized : bool;
g_error_buffer : [10000]u8 = ---;
g_message_queue : [..]Message;

SendClientMessage :: (window : X11.Window, type : X11.Atom, args : ..s64) #no_context
{
    ctx : Context;
    push_context, defer_pop ctx;

    event : X11.XEvent;
    event.xclient.type = X11.ClientMessage;
    event.xclient.send_event = X11.True;
    event.xclient.message_type = type;
    event.xclient.window = window;
    event.xclient.format = 32;
    for i : 0..min(args.count, 5) - 1
    {
        event.xclient.data.l[i] = args[i];
    }

    root := X11.DefaultRootWindow(g_display);
    X11.XSendEvent(g_display, root, X11.False, X11.SubstructureRedirectMask | X11.SubstructureNotifyMask, *event);
}

HandleXError :: (d : *X11.Display, event : *X11.XErrorEvent) -> s32 #c_call
{
    ctx : Context;
    push_context, defer_pop ctx;

    X11.XGetErrorText(d, event.error_code, g_error_buffer.data, g_error_buffer.count);
    log_error("Error: %", to_string(g_error_buffer.data));

    return 0;
}

Initialize :: ()
{
    if g_initialized
        return;

    defer g_initialized = true;

    X11.XSetErrorHandler(HandleXError);

    g_display = X11.XOpenDisplay(null);
    assert(g_display != null);

    g_wm_protocols = X11.XInternAtom(g_display, "WM_PROTOCOLS", X11.False);
    g_wm_delete_window = X11.XInternAtom(g_display, "WM_DELETE_WINDOW", X11.False);
    g_active_window = X11.XInternAtom(g_display, "_NET_ACTIVE_WINDOW", X11.False);
    g_wm_state = X11.XInternAtom(g_display, "_NET_WM_STATE", X11.False);
    g_wm_state_hidden = X11.XInternAtom(g_display, "_NET_WM_STATE_HIDDEN", X11.False);
    g_wm_state_maximized_vert = X11.XInternAtom(g_display, "_NET_WM_STATE_MAXIMIZED_VERT", X11.False);
    g_wm_state_maximized_horz = X11.XInternAtom(g_display, "_NET_WM_STATE_MAXIMIZED_HORZ", X11.False);

    {
        using g_cursors;

        XC_left_ptr :: 68;
        XC_bottom_left_corner :: 12;
        XC_bottom_right_corner :: 14;
        XC_bottom_side :: 16;
        XC_left_side :: 70;
        XC_top_left_corner :: 134;
        XC_top_right_corner :: 136;
        XC_top_side :: 138;
        XC_right_side :: 96;
        XC_sb_h_double_arrow :: 108;
        XC_sb_v_double_arrow :: 116;
        XC_watch :: 150;
        XC_xterm :: 152;
        XC_fleur :: 52;
        XC_cross :: 30;
        XC_hand2 :: 60;

        black : X11.XColor;
        no_data := u8.[0,0,0,0,0,0,0,0];
        bitmap := X11.XCreateBitmapFromData(g_display, X11.DefaultRootWindow(g_display), no_data.data, 8, 8);
        none = X11.XCreatePixmapCursor(g_display, bitmap, bitmap, *black, *black, 0, 0);

        arrow = X11.XCreateFontCursor(g_display, XC_left_ptr);
        arrow_busy = X11.XCreateFontCursor(g_display, XC_watch);
        busy = X11.XCreateFontCursor(g_display, XC_watch);
        cross = X11.XCreateFontCursor(g_display, XC_cross);
        hand = X11.XCreateFontCursor(g_display, XC_hand2);
        ibeam = X11.XCreateFontCursor(g_display, XC_xterm);
        size = X11.XCreateFontCursor(g_display, XC_fleur);
        size_nwse = X11.XCreateFontCursor(g_display, XC_top_left_corner);
        size_nesw = X11.XCreateFontCursor(g_display, XC_top_right_corner);
        size_horizontal = X11.XCreateFontCursor(g_display, XC_sb_h_double_arrow);
        size_vertical = X11.XCreateFontCursor(g_display, XC_sb_v_double_arrow);
        not_allowed = X11.XCreateFontCursor(g_display, XC_left_ptr);
        size_left = X11.XCreateFontCursor(g_display, XC_left_side);
        size_right = X11.XCreateFontCursor(g_display, XC_right_side);
        size_top = X11.XCreateFontCursor(g_display, XC_top_side);
        size_bottom = X11.XCreateFontCursor(g_display, XC_bottom_side);
        size_top_left = X11.XCreateFontCursor(g_display, XC_top_left_corner);
        size_top_right = X11.XCreateFontCursor(g_display, XC_top_right_corner);
        size_bottom_left = X11.XCreateFontCursor(g_display, XC_bottom_left_corner);
        size_bottom_right = X11.XCreateFontCursor(g_display, XC_bottom_right_corner);
    }
}

#scope_export

using APIImpl :: struct
{

PlatformHandle :: X11.Window;

Window :: struct
{
    visual : *X11.XVisualInfo;
    x, y : s32;
    viewport_width, viewport_height : s32;
    handle : X11.Window;
    last_mouse_button_release_time : [3]X11.Time; // In ms
    prev_mouse_x, prev_mouse_y : s32;
}

GetPlatformHandle :: inline (window : *Window) -> PlatformHandle #must
#no_context
{
    return window.handle;
}

ShowErrorBox :: inline (parent : *Window, fmt_str : string, args : ..Any)
{
    assert(false);
}

ShowErrorBox :: inline (fmt_str : string, args : ..Any)
{
    assert(false);
}

GetDisplays :: inline () -> []DisplayInfo #must
{
    return .[];
}

CreateWindowExtraParams :: struct
{
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
    Initialize();

    d := g_display;
    X11.XLockDisplay(d);
    defer X11.XUnlockDisplay(d);

    x = ifx x == Window_Default_Pos then 0 else x;
    y = ifx y == Window_Default_Pos then 0 else y;
    parent_handle := ifx parent then parent.handle else X11.DefaultRootWindow(d);
    assert(parent_handle != 0);

    glx_attribs := s32.[
        X11.GLX_RGBA,
        X11.GLX_DOUBLEBUFFER,
        X11.GLX_DEPTH_SIZE, 24,
        X11.GLX_STENCIL_SIZE, 8,
        X11.GLX_RED_SIZE, 8,
        X11.GLX_GREEN_SIZE, 8,
        X11.GLX_BLUE_SIZE, 8,
        X11.GLX_SAMPLE_BUFFERS, 0,
        X11.GLX_SAMPLES, 0,
        0
    ];
    screen_id := X11.DefaultScreen(g_display);
    visual := X11.glXChooseVisual(g_display, screen_id, glx_attribs.data);
    if !visual
        return null;

    event_mask : s32;
    event_mask |= X11.ExposureMask;
    event_mask |= X11.StructureNotifyMask;
    event_mask |= X11.FocusChangeMask;
    event_mask |= X11.KeyPressMask | X11.KeyReleaseMask;
    event_mask |= X11.PointerMotionMask;
    event_mask |= X11.ButtonPressMask | X11.ButtonReleaseMask;
    event_mask |= X11.EnterWindowMask | X11.LeaveWindowMask;

    attr : X11.XSetWindowAttributes;
    attr.border_pixel = X11.XBlackPixel(g_display, screen_id);
    attr.background_pixel = X11.XWhitePixel(g_display, screen_id);
    attr.override_redirect = X11.True;
    attr.colormap = X11.XCreateColormap(g_display, parent_handle, visual.visual, X11.AllocNone);
    attr.event_mask = event_mask;

    CWBlackPixel :: 1 << 1;
    CWBorderPixel :: 1 << 3;
    CWColormap :: 1 << 13;
    CWEventMask :: 1 << 11;

    if x < 0
        x = 0;
    if y < 0
        y = 0;
    if width < 0
        width = 0;
    if height < 0
        height = 0;

    handle := X11.XCreateWindow(
        d, parent_handle,
        xx x, xx y, xx width, xx height,
        0, visual.depth, X11.InputOutput, visual.visual,
        CWBlackPixel | CWColormap | CWBorderPixel | CWEventMask, *attr
    );
    if !handle
        return null;

    if title
    {
        c_title := temp_c_string(title);
        X11.XStoreName(d, handle, c_title);

        class_hint := X11.XAllocClassHint();
        if class_hint
        {
            class_hint.res_name = c_title;
            class_hint.res_class = c_title;
            X11.XSetClassHint(d, handle, class_hint);
        }
    }

    X11.XSelectInput(d, handle, event_mask);

    X11.XSetWMProtocols(d, handle, *g_wm_delete_window, 1);

    if !(flags & .Hidden)
        X11.XMapWindow(d, handle);

    window := New(Window);
    window.handle = handle;
    window.visual = visual;
    window.x = x;
    window.y = y;
    window.viewport_width = width;
    window.viewport_height = height;
    array_add(*g_all_windows, window);

    return window;
}

DestroyWindow :: inline (window : *Window) #no_context
{
    // @Todo: find a way to handle DestroyNotify events when this is
    // called at the end of the program when we stopped polling events
    // On windows this is not a problem because this function will call our event
    // callback directly.
    X11.XDestroyWindow(g_display, window.handle);
}

CloseWindow :: inline (window : *Window) #no_context
{
    X11.XUnmapWindow(g_display, window.handle);
}

PollMessages :: () -> []Message
{
    g_message_queue.count = 0;

    X11.XLockDisplay(g_display);
    defer X11.XUnlockDisplay(g_display);

    event : X11.XEvent;
    while X11.XPending(g_display)
    {
        X11.XNextEvent(g_display, *event);

        HandleXEvent(event);
    }

    return g_message_queue;
}

SetCursor :: (window : *Window, cursor : SystemCursor) #no_context
{
    X11.XDefineCursor(g_display, window.handle, g_cursors.all[cursor]);
}

// @Todo
SetCursorConstraint :: (x : s32, y : s32, w : s32, h : s32) -> bool #no_context
{
    return false;
}

// @Todo
RemoveCursorConstraint :: () -> bool #no_context
{
    return false;
}

GetWindowTitle :: (window : *Window) -> string #must
{
    result : *u8;
    X11.XFetchName(g_display, window.handle, *result);
    defer X11.XFree(result);

    return copy_string(to_string(result));
}

SetWindowTitle :: (window : *Window, title : string)
{
    c_title := temp_c_string(title);
    X11.XStoreName(g_display, window.handle, c_title);
}

// @Todo
GetWindowScaleFactor :: inline (window : *Window) -> float #must #no_context
{
    return 1;
}

GetViewportPosition :: inline (window : *Window) -> x : s32, y : s32 #no_context
{
    ctx : Context;
    push_context, defer_pop ctx;

    root_window := X11.DefaultRootWindow(g_display);
    child : X11.Window;
    x, y : s32;
    X11.XTranslateCoordinates(g_display, window.handle, root_window, 0, 0, *x, *y, *child);

    return x, y;
}

SetViewportPosition :: (window : *Window, x : s32, y : s32) #no_context
{
    change : X11.XWindowChanges;
    change.x = x;
    change.y = y;
    X11.XConfigureWindow(g_display, window.handle, (1<<0) | (1<<1), *change);
}

GetViewportSize :: (window : *Window) -> w : s32, h : s32 #no_context
{
    attr : X11.XWindowAttributes;
    X11.XGetWindowAttributes(g_display, window.handle, *attr);

    return attr.width, attr.height;
}

SetViewportSize :: (window : *Window, w : s32, h : s32) #no_context
{
    change : X11.XWindowChanges;
    change.width = w;
    change.height = h;
    X11.XConfigureWindow(g_display, window.handle, (1<<2) | (1<<3), *change);
}

GetFocusedWindow :: () -> *Window #must, non_fenetres_window : bool #no_context
{
    result : X11.Window;
    revert_to : s32;
    X11.XGetInputFocus(g_display, *result, *revert_to);

    window := GetWindowFromPlatformHandle(result);

    return window, window == null && result != 0;
}

SetFocusedWindow :: (window : *Window) #no_context
{
    X11.XSetInputFocus(g_display, window.handle, 0, 0);
}

IsMaximized :: (window : *Window) -> bool #must #no_context
{
    actual_type : X11.Atom;
    actual_format : s32;
    num_states, remaining : u64;
    states : *X11.Atom;
    ok := X11.XGetWindowProperty(
        g_display, window.handle,
        g_wm_state,
        0,
        1024,
        X11.False,
        X11.XA_ATOM,
        *actual_type,
        *actual_format,
        *num_states,
        *remaining,
        xx *states
    );
    defer X11.XFree(states);

    if ok != X11.Success || num_states == 0 || actual_type != X11.XA_ATOM
        return false;

    for i : 0..num_states - 1
    {
        if states[i] == g_wm_state_maximized_horz
            return true;
    }

    return false;
}

IsMinimized :: (window : *Window) -> bool #must #no_context
{
    actual_type : X11.Atom;
    actual_format : s32;
    num_states, remaining : u64;
    states : *X11.Atom;

    ok := X11.XGetWindowProperty(
        g_display, window.handle,
        g_wm_state,
        0,
        1024,
        X11.False,
        X11.XA_ATOM,
        *actual_type,
        *actual_format,
        *num_states,
        *remaining,
        xx *states
    );
    defer X11.XFree(states);

    if ok != X11.Success || num_states == 0 || actual_type != X11.XA_ATOM
        return false;

    for i : 0..num_states - 1
    {
        if states[i] == g_wm_state_hidden
            return true;
    }

    return false;
}

Maximize :: (window : *Window) #no_context
{
    SendClientMessage(window.handle, g_wm_state, X11._NET_WM_STATE_REMOVE, xx g_wm_state_hidden);
    SendClientMessage(window.handle, g_wm_state, X11._NET_WM_STATE_ADD, xx g_wm_state_maximized_vert, xx g_wm_state_maximized_horz);
}

Restore :: (window : *Window) #no_context
{
    SendClientMessage(window.handle, g_wm_state, X11._NET_WM_STATE_REMOVE, xx g_wm_state_maximized_vert, xx g_wm_state_maximized_horz);
    SendClientMessage(window.handle, g_wm_state, X11._NET_WM_STATE_REMOVE, xx g_wm_state_hidden);
    SendClientMessage(window.handle, g_active_window, 1, 0);
}

Minimize :: (window : *Window) #no_context
{
    SendClientMessage(window.handle, g_wm_state, X11._NET_WM_STATE_REMOVE, xx g_wm_state_maximized_vert, xx g_wm_state_maximized_horz);
    X11.XIconifyWindow(g_display, window.handle, X11.XDefaultScreen(g_display));
}

SetWindowVisibility :: (window : *Window, visible : bool) #no_context
{
    if visible
    {
        X11.XMapWindow(g_display, window.handle);

        // Restore window to original position and size
        SetViewportPosition(window, window.x, window.y);
        SetViewportSize(window, window.viewport_width, window.viewport_height);
    }
    else
    {
        X11.XUnmapWindow(g_display, window.handle);
    }
}

ShowAndFocusWindow :: (window : *Window) #no_context
{
    SetWindowVisibility(window, true);
    SetFocusedWindow(window);
}

ScreenToWindowPosition :: (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context
{
    ctx : Context;
    push_context, defer_pop ctx;

    root_window := X11.DefaultRootWindow(g_display);
    child : X11.Window;
    result_x, result_y : s32;
    X11.XTranslateCoordinates(g_display, root_window, window.handle, x, y, *result_x, *result_y, *child);

    return result_x, result_y;
}

WindowToScreenPosition :: (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context
{
    ctx : Context;
    push_context, defer_pop ctx;

    root_window := X11.DefaultRootWindow(g_display);
    child : X11.Window;
    result_x, result_y : s32;
    X11.XTranslateCoordinates(g_display, window.handle, root_window, x, y, *result_x, *result_y, *child);

    return result_x, result_y;
}

GetMousePosition :: () -> x : s32, y : s32 #no_context
{
    x, y := GetMousePosition(null);

    return x, y;
}

SetMousePosition :: (x : s32, y : s32) #no_context
{
    SetMousePosition(null, x, y);
}

GetMousePosition :: (window : *Window) -> x : s32, y : s32 #no_context
{
    ctx : Context;
    push_context, defer_pop ctx;

    handle := ifx window then window.handle else X11.DefaultRootWindow(g_display);

    root, child : X11.Window;
    x_root, y_root, x_win, y_win : s32;
    mods : u32;
    X11.XQueryPointer(g_display, handle, *root, *child, *x_root, *y_root, *x_win, *y_win, *mods);

    return x_win, y_win;
}

SetMousePosition :: (window : *Window, x : s32, y : s32) #no_context
{
    ctx : Context;
    push_context, defer_pop ctx;

    handle := ifx window then window.handle else X11.DefaultRootWindow(g_display);
    X11.XWarpPointer(g_display, 0, handle, 0, 0, 0, 0, x, y);
}

SetMouseCapture :: (window : *Window, capture : bool) #no_context
{
    // Causes the window system to freeze...
    // if capture
    // {
    //     X11.XGrabPointer(
    //         g_display, window.handle,
    //         X11.False,
    //         X11.PointerMotionMask | X11.ButtonPressMask | X11.ButtonReleaseMask,
    //         X11.GrabModeSync, X11.GrabModeSync,
    //         X11.None, X11.None, 0
    //     );
    // }
    // else
    // {
    //     X11.XUngrabPointer(g_display, 0);
    // }
}

GetClipboardTextData :: () -> string #must
{
    return "";
}

SetClipboardTextData :: (text : string)
{
}

ClearClipboard :: ()
{
}

}

#scope_file

HandleXEvent :: (event : X11.XEvent)
{
    GetKeyModsFromStateFlags :: inline (state : u32) -> KeyMods #must
    {
        result : KeyMods;
        if state & X11.ShiftMask
            result |= .Shift;
        if state & X11.ControlMask
            result |= .Ctrl;
        if state & X11.Mod1Mask
            result |= .Alt;

        return result;
    }

    window := GetWindowFromPlatformHandle(event.xany.window);
    if !window
        return;

    if event.type ==
    {
    case X11.ClientMessage;
        msg_type := event.xclient.message_type;
        if msg_type == g_wm_protocols
        {
            wm := cast(X11.Atom) event.xclient.data.l[0];
            if wm == g_wm_delete_window
            {
                X11.XUnmapWindow(event.xany.display, window.handle);

                msg : Message;
                msg.kind = .Window_Closed;
                msg.window = window;
                array_add(*g_message_queue, msg);
            }
        }

    case X11.KeyPress; #through;
    case X11.KeyRelease;
        // Filter out release+press events for repeat
        if event.type == X11.KeyRelease && X11.XEventsQueued(g_display, X11.QueuedAfterReading)
        {
            next : X11.XEvent;
            X11.XPeekEvent(g_display, *next);

            if next.type == X11.KeyPress
            && next.xkey.time == event.xkey.time
            && next.xkey.keycode == event.xkey.keycode
            {
                X11.XNextEvent(g_display, *next);

                sym := X11.XKeycodeToKeysym(next.xany.display, xx next.xkey.keycode, 0);

                msg : Message;
                msg.kind = .Key_Repeated;
                msg.window = window;
                msg.mods = GetKeyModsFromStateFlags(next.xkey.state);
                msg.key_code = XKeySymToKeyCode(sym);
                array_add(*g_message_queue, msg);

                return;
            }
        }

        sym := X11.XkbKeycodeToKeysym(event.xany.display, xx event.xkey.keycode, 0, 0);

        msg : Message;
        msg.kind = ifx event.type == X11.KeyPress then .Key_Pressed else .Key_Released;
        msg.window = window;
        msg.mods = GetKeyModsFromStateFlags(event.xkey.state);
        msg.key_code = XKeySymToKeyCode(sym);
        array_add(*g_message_queue, msg);

        shift := cast(u32) ifx event.xkey.state & X11.ShiftMask then 1 else 0;
        sym = X11.XkbKeycodeToKeysym(event.xany.display, xx event.xkey.keycode, 0, shift);

        if event.type == X11.KeyPress && (sym < X11.XK_BackSpace || sym > X11.XK_Hyper_R)
        {
            msg : Message;
            msg.kind = .Text_Input;
            msg.window = window;
            msg.codepoint = xx, no_check sym;
            array_add(*g_message_queue, msg);
        }

    case X11.ButtonPress; #through;
    case X11.ButtonRelease;
        button := event.xbutton.button;
        if button >= 4 && button <= 7
        {
            if event.type == X11.ButtonRelease
                return;

            msg : Message;
            msg.kind = .Mouse_Wheel;
            msg.window = window;
            msg.mouse_wheel_x = ifx button == 7 then -1.0 else ifx button == 6 then 1.0;
            msg.mouse_wheel_y = ifx button == 5 then -1.0 else ifx button == 4 then 1.0;
            msg.mods = GetKeyModsFromStateFlags(event.xbutton.state);
            //msg.mouse_wheel_x /= 120.0;
            //msg.mouse_wheel_y /= 120.0;
            array_add(*g_message_queue, msg);

            return;
        }

        msg : Message;
        msg.kind = ifx event.type == X11.ButtonPress then .Mouse_Button_Pressed else .Mouse_Button_Released;
        msg.window = window;
        msg.mods = GetKeyModsFromStateFlags(event.xbutton.state);

        if button ==
        {
        case X11.Button1;
            msg.mouse_button = .Left;

            time_since_last_release := event.xbutton.time - window.last_mouse_button_release_time[0];
            if msg.kind == .Mouse_Button_Released
                window.last_mouse_button_release_time[0] = event.xbutton.time;
            else if time_since_last_release <= g_double_click_time_ms
                msg.kind = .Mouse_Button_Repeated;

        case X11.Button2;
            msg.mouse_button = .Middle;

            time_since_last_release := event.xbutton.time - window.last_mouse_button_release_time[1];
            if msg.kind == .Mouse_Button_Released
                window.last_mouse_button_release_time[1] = event.xbutton.time;
            else if time_since_last_release <= g_double_click_time_ms
                msg.kind = .Mouse_Button_Repeated;

        case X11.Button3;
            msg.mouse_button = .Right;

            time_since_last_release := event.xbutton.time - window.last_mouse_button_release_time[2];
            if msg.kind == .Mouse_Button_Released
                window.last_mouse_button_release_time[2] = event.xbutton.time;
            else if time_since_last_release <= g_double_click_time_ms
                msg.kind = .Mouse_Button_Repeated;
        }

        array_add(*g_message_queue, msg);

    case X11.MotionNotify;
        msg : Message;
        msg.kind = .Mouse_Moved;
        msg.window = window;
        msg.mouse_x = event.xmotion.x;
        msg.mouse_y = event.xmotion.y;
        array_add(*g_message_queue, msg);

        msg.kind = .Mouse_Raw_Moved;
        msg.mouse_delta_x = msg.mouse_x - window.prev_mouse_x;
        msg.mouse_delta_y = msg.mouse_y - window.prev_mouse_y;
        array_add(*g_message_queue, msg);

        window.prev_mouse_x = msg.mouse_x;
        window.prev_mouse_y = msg.mouse_y;

    case X11.EnterNotify;
        msg : Message;
        msg.kind = .Mouse_Entered_Window;
        msg.window = window;
        array_add(*g_message_queue, msg);

        window.prev_mouse_x = event.xcrossing.x;
        window.prev_mouse_y = event.xcrossing.y;

    case X11.LeaveNotify;
        msg : Message;
        msg.kind = .Mouse_Left_Window;
        msg.window = window;
        array_add(*g_message_queue, msg);

    case X11.ConfigureNotify;
        msg : Message;
        msg.window = window;
        msg.window_x = event.xconfigure.x;
        msg.window_y = event.xconfigure.y;
        msg.viewport_w = event.xconfigure.width;
        msg.viewport_h = event.xconfigure.height;
        msg.window_w = msg.viewport_w;
        msg.window_h = msg.viewport_h;

        if window.x != msg.window_x
        || window.y != msg.window_y
        {
            msg.kind = .Window_Moved;
            array_add(*g_message_queue, msg);
        }

        if window.viewport_width != msg.viewport_w
        || window.viewport_height != msg.viewport_h
        {
            msg.kind = .Window_Resized;
            array_add(*g_message_queue, msg);
        }

        window.x = msg.window_x;
        window.y = msg.window_y;
        window.viewport_width = msg.viewport_w;
        window.viewport_height = msg.viewport_h;

    case X11.FocusIn;
        msg : Message;
        msg.kind = .Window_Received_Focus;
        msg.window = window;
        array_add(*g_message_queue, msg);

    case X11.FocusOut;
        msg : Message;
        msg.kind = .Window_Lost_Focus;
        msg.window = window;
        array_add(*g_message_queue, msg);

    case X11.DestroyNotify;
        for g_all_windows
        {
            if it == window
            {
                remove it;
                break;
            }
        }

        free(window);
    }
}

XKeySymToKeyCode :: (sym : X11.KeySym) -> KeyCode #must #no_context
{
    #insert -> string
    {
        builder : String_Builder;

        append(*builder, "if sym ==\n{\n");
        for Key_Sym_To_Key_Code_Map
        {
            print_to_builder(*builder, "case %; return .%;\n", it.key_sym, it.key_code);
        }
        append(*builder, "}\n");

        return builder_to_string(*builder);
    };

    return .Invalid;
}

KeyCodeToXKeySym :: (key_code : KeyCode) -> X11.KeySym #must #no_context
{
    #insert -> string
    {
        builder : String_Builder;

        append(*builder, "if key_code ==\n{\n");
        for Key_Sym_To_Key_Code_Map
        {
            print_to_builder(*builder, "case .%; return %;\n", it.key_code, it.key_sym);
        }
        append(*builder, "}\n");

        return builder_to_string(*builder);
    };

    return 0;
}

KeySymKeyCodePair :: struct
{
    key_sym : X11.KeySym;
    key_code : KeyCode;
}

// https://www.cl.cam.ac.uk/~mgk25/ucs/keysymdef.h

Key_Sym_To_Key_Code_Map :: KeySymKeyCodePair.[
    .{X11.XK_BackSpace, .Backspace},
    .{X11.XK_Tab, .Tab},
    .{X11.XK_Clear, .Clear},
    .{X11.XK_Return, .Return},
    .{X11.XK_Pause, .Pause},
    .{X11.XK_Escape, .Escape},
    .{X11.XK_Delete, .Delete},

    .{X11.XK_Scroll_Lock, .Scroll_Lock},
    .{X11.XK_Caps_Lock, .Caps_Lock},
    .{0xff7f, .Num_Lock},

    .{X11.XK_Home, .Home},
    .{X11.XK_Left, .Left},
    .{X11.XK_Up, .Up},
    .{X11.XK_Right, .Right},
    .{X11.XK_Down, .Down},
    .{X11.XK_Page_Up, .Page_Up},
    .{X11.XK_Page_Down, .Page_Down},
    .{0xff63, .Insert},
    .{X11.XK_End, .End},

    .{X11.XK_F1, .F1},
    .{X11.XK_F2, .F2},
    .{X11.XK_F3, .F3},
    .{X11.XK_F4, .F4},
    .{X11.XK_F5, .F5},
    .{X11.XK_F6, .F6},
    .{X11.XK_F7, .F7},
    .{X11.XK_F8, .F8},
    .{X11.XK_F9, .F9},
    .{X11.XK_F10, .F10},
    .{X11.XK_F11, .F11},
    .{X11.XK_F12, .F12},

    .{X11.XK_Shift_L, .Left_Shift},
    .{X11.XK_Shift_R, .Right_Shift},
    .{X11.XK_Control_L, .Left_Ctrl},
    .{X11.XK_Control_R, .Right_Ctrl},

    .{X11.XK_Alt_L, .Left_Alt},
    .{X11.XK_Alt_R, .Right_Alt},
    .{X11.XK_Super_L, .Left_Super},
    .{X11.XK_Super_R, .Right_Super},

    .{X11.XK_space, .Space},

    .{X11.XK_grave, .Backtick},
    .{X11.XK_minus, .OEM_Minus},
    .{X11.XK_equal, .OEM_Plus},

    .{X11.XK_backslash, .Backslash},

    .{X11.XK_bracketleft, .Open_Bracket},
    .{X11.XK_braceleft, .Open_Bracket},
    .{X11.XK_bracketright, .Close_Bracket},
    .{X11.XK_braceright, .Close_Bracket},

    .{X11.XK_apostrophe, .Quote},
    .{X11.XK_semicolon, .Semicolon},

    .{X11.XK_comma, .OEM_Comma},
    .{X11.XK_period, .OEM_Period},
    .{X11.XK_slash, .Slash},

    .{X11.XK_0, .Zero},
    .{X11.XK_1, .One},
    .{X11.XK_2, .Two},
    .{X11.XK_3, .Three},
    .{X11.XK_4, .Four},
    .{X11.XK_5, .Five},
    .{X11.XK_6, .Six},
    .{X11.XK_7, .Seven},
    .{X11.XK_8, .Eight},
    .{X11.XK_9, .Nine},

    .{X11.XK_A, .A},
    .{X11.XK_B, .B},
    .{X11.XK_C, .C},
    .{X11.XK_D, .D},
    .{X11.XK_E, .E},
    .{X11.XK_F, .F},
    .{X11.XK_G, .G},
    .{X11.XK_H, .H},
    .{X11.XK_I, .I},
    .{X11.XK_J, .J},
    .{X11.XK_K, .K},
    .{X11.XK_L, .L},
    .{X11.XK_M, .M},
    .{X11.XK_N, .N},
    .{X11.XK_O, .O},
    .{X11.XK_P, .P},
    .{X11.XK_Q, .Q},
    .{X11.XK_R, .R},
    .{X11.XK_S, .S},
    .{X11.XK_T, .T},
    .{X11.XK_U, .U},
    .{X11.XK_V, .V},
    .{X11.XK_W, .W},
    .{X11.XK_X, .X},
    .{X11.XK_Y, .Y},
    .{X11.XK_Z, .Z},

    .{X11.XK_a, .A},
    .{X11.XK_b, .B},
    .{X11.XK_c, .C},
    .{X11.XK_d, .D},
    .{X11.XK_e, .E},
    .{X11.XK_f, .F},
    .{X11.XK_g, .G},
    .{X11.XK_h, .H},
    .{X11.XK_i, .I},
    .{X11.XK_j, .J},
    .{X11.XK_k, .K},
    .{X11.XK_l, .L},
    .{X11.XK_m, .M},
    .{X11.XK_n, .N},
    .{X11.XK_o, .O},
    .{X11.XK_p, .P},
    .{X11.XK_q, .Q},
    .{X11.XK_r, .R},
    .{X11.XK_s, .S},
    .{X11.XK_t, .T},
    .{X11.XK_u, .U},
    .{X11.XK_v, .V},
    .{X11.XK_w, .W},
    .{X11.XK_x, .X},
    .{X11.XK_y, .Y},
    .{X11.XK_z, .Z},

    // Numpad
    .{0x0ffaf, .Divide},
    .{0x0ffaa, .Multiply},
    .{0x0ffad, .Subtract},
    .{0x0ffab, .Add},
    .{0x0ff8d, .Numpad_Equals},
    .{0x0ff9f, .Separator},
    .{0x0ff9e, .Numpad0},
    .{0x0ff9c, .Numpad1},
    .{0x0ff99, .Numpad2},
    .{0x0ff9b, .Numpad3},
    .{0x0ff96, .Numpad4},
    .{0x0ff9d, .Numpad5},
    .{0x0ff98, .Numpad6},
    .{0x0ff95, .Numpad7},
    .{0x0ff97, .Numpad8},
    .{0x0ff9a, .Numpad9},
];
