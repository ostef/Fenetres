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

Initialize :: ()
{
    if g_initialized
        return;

    defer g_initialized = true;

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

    s := X11.DefaultScreen(d);
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
