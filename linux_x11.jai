#import "Basic";
X11 :: #import "X11";

PlatformHandle :: X11.Window;

Window :: struct
{
    handle : X11.Window;
}

#scope_file

g_display : *X11.Display;
g_initialized : bool;
g_error_buffer : [10000]u8;
g_message_queue : [..]Message;

HandleXError :: (d : *X11.Display, event : *X11.XErrorEvent) -> s32 #c_call
{
    ctx : Context;
    push_context, defer_pop ctx;

    X11.XGetErrorText(d, event.error_code, g_error_buffer.data, g_error_buffer.count);
    log_error("%", to_string(g_error_buffer.data));

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
}

#scope_export

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
    assert(false);
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

    handle := X11.XCreateSimpleWindow(
        d, parent_handle,
        xx x, xx y, xx width, xx height,
        0, 0, 0xffffffff
    );
    assert(handle != 0);

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

    X11.XSelectInput(d, handle, X11.ExposureMask | X11.KeyPressMask);
    X11.XMapWindow(d, handle);

    window := New(Window);
    window.handle = handle;
    array_add(*g_all_windows, window);

    return window;
}

DestroyWindow :: inline (window : *Window) #no_context
{
    X11.XDestroyWindow(g_display, window.handle);
}

SetWindowTitle :: (window : *Window, title : string)
{
    c_title := temp_c_string(title);
    X11.XStoreName(g_display, window.handle, c_title);
}

GetWindowTitle :: (window : *Window) -> string #must
{
    result : *u8;
    X11.XFetchName(g_display, window.handle, *result);
    defer X11.XFree(result);

    return copy_string(to_string(result));
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

#scope_file

HandleXEvent :: (event : X11.XEvent)
{
    window := GetWindowFromPlatformHandle(event.xany.window);
    if !window
        return;

    if event.type ==
    {
    case X11.KeyPress; #through;
    case X11.KeyRelease;
        msg : Message;
        msg.kind = ifx event.type == X11.KeyPress then .Key_Pressed else .Key_Released;
        msg.window = window;
        sym := X11.XKeycodeToKeysym(event.xany.display, xx event.xkey.keycode, 0);
        msg.key_code = XKeySymToKeyCode(sym);
        array_add(*g_message_queue, msg);
        print("% %\n", FormatInt.{value=sym, base=16}, FormatInt.{value=event.xkey.keycode, base=16});

    case X11.ButtonPress; #through;
    case X11.ButtonRelease;
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
