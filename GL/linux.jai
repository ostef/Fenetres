#import "Basic";

GLContext :: X11.GLXContext;

GLContextFlags :: enum_flags
{
    Multi_Sampled;
    Compatibility_Profile;
    Debug;
}

#scope_file

glXGetCurrentDisplay :: () -> *X11.Display #foreign glx;
glXGetCurrentDrawable :: () -> X11.GLXDrawable #foreign glx;

glx :: #system_library "libGL";

#scope_module

GetProcAddress :: X11.glXGetProcAddress;

CreateContext :: inline (window : *Window, flags := GLContextFlags.Multi_Sampled, major_version : s32 = 0, minor_version : s32 = 0, share_context : GLContext = null) -> GLContext #must
{
    ctx := X11.glXCreateContext(GetOpenedXDisplay(), window.visual, share_context, X11.True);
    if !ctx
        return null;

    X11.glXMakeCurrent(GetOpenedXDisplay(), window.handle, ctx);

    return ctx;
}

DestroyContext :: inline (ctx : GLContext) #no_context
{
    X11.glXDestroyContext(GetOpenedXDisplay(), ctx);
}

MakeCurrent :: inline (window : *Window, ctx : GLContext) #no_context
{
    X11.glXMakeCurrent(GetOpenedXDisplay(), window.handle, ctx);
}

GetCurrentContext :: inline () -> GLContext #must #no_context
{
    return X11.glXGetCurrentContext();
}

GetCurrentWindow :: inline () -> *Window #must, non_fenetres_window : bool #no_context
{
    handle := cast(X11.Window) glXGetCurrentDrawable();
    if !handle
        return null, false;

    window := GetWindowFromPlatformHandle(handle);

    return window, window == null;
}

SwapBuffers :: inline (window : *Window) #no_context
{
    X11.glXSwapBuffers(glXGetCurrentDisplay(), window.handle);
}

SetSwapInterval :: inline (interval : s32) -> bool #no_context
{
    return xx glXSwapIntervalEXT(glXGetCurrentDisplay(), glXGetCurrentDrawable(), interval);
}

GetSwapInterval :: inline () -> s32 #must #no_context
{
    value : s32;
    glXQueryDrawable(glXGetCurrentDisplay(), glXGetCurrentDrawable(), GLX_SWAP_INTERVAL_EXT, *swap);

    return value;
}
