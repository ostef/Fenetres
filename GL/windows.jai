#import "Basic";

#scope_module

Win32 :: #import "Win32" (WGL = true, GDI_Basics = true);

#scope_export

// @Todo: choose OpenGL version
// @Todo: share lists

GLContext :: Win32.HGLRC;

GLContextFlags :: enum_flags
{
    Multi_Sampled;
    Compatibility_Profile;
    Debug;
}

GetProcAddress :: Win32.wglGetProcAddress;

CreateContext :: inline (window : *Window, flags := GLContextFlags.Multi_Sampled, major_version : s32 = 0, minor_version : s32 = 0) -> GLContext #must
{
    #import "GL";

    hdc := Win32.GetDC (window.hwnd);
    pfd : Win32.PIXELFORMATDESCRIPTOR;
    pfd.nSize = size_of (Win32.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = Win32.PFD_DRAW_TO_WINDOW | Win32.PFD_SUPPORT_OPENGL | Win32.PFD_DOUBLEBUFFER;
    pfd.iPixelType = Win32.PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.cStencilBits = 8;

    pixel_format : s32;

    if wglChoosePixelFormatARB
    {
        attributes : [..]s32;
        attributes.allocator = temp;

        array_add (*attributes,
            WGL_DRAW_TO_WINDOW_ARB, 1,
            WGL_SUPPORT_OPENGL_ARB, 1,
            WGL_DOUBLE_BUFFER_ARB, 1,
            WGL_PIXEL_TYPE_ARB, WGL_TYPE_RGBA_ARB,
            WGL_COLOR_BITS_ARB, 32,
            WGL_DEPTH_BITS_ARB, 24,
            WGL_STENCIL_BITS_ARB, 8
        );

        if flags & .Multi_Sampled
        {
            array_add (*attributes,
                WGL_SAMPLE_BUFFERS_ARB, 1,
                WGL_SAMPLES_ARB, 4
            );
        }

        array_add (*attributes, 0, 0);

        num_formats : u32;

        valid := wglChoosePixelFormatARB (hdc, attributes.data, null, 1, *pixel_format, *num_formats);

        if !valid || num_formats < 1
        {
            log_error ("wglChoosePixelFormatARB failed. GL context creation flags were %", flags);
            pixel_format = Win32.ChoosePixelFormat (hdc, *pfd);
        }
        else
        {
            Win32.DescribePixelFormat (hdc, pixel_format, size_of (Win32.PIXELFORMATDESCRIPTOR), *pfd);
        }
    }
    else
    {
        if flags & .Multi_Sampled
            log_error ("Cannot create multi sampled GL context because wglChoosePixelFormatARB proc is not loaded. Did you forget to call LoadGL? Falling back to Win32.ChoosePixelFormat");

        pixel_format = Win32.ChoosePixelFormat (hdc, *pfd);
    }

    if !Win32.SetPixelFormat (hdc, pixel_format, *pfd)
    {
        return null;
    }

    ctx : Win32.HGLRC;
    if wglCreateContextAttribsARB
    {
        attribs : [..]s32;
        attribs.allocator = temp;

        if major_version > 0
        {
            array_add (*attribs, WGL_CONTEXT_MAJOR_VERSION_ARB, major_version);
            array_add (*attribs, WGL_CONTEXT_MINOR_VERSION_ARB, minor_version);
        }

        if flags & .Compatibility_Profile
        {
            array_add (*attribs,
                WGL_CONTEXT_PROFILE_MASK_ARB,
                WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB
            );
        }
        else
        {
            array_add (*attribs,
                WGL_CONTEXT_PROFILE_MASK_ARB,
                WGL_CONTEXT_CORE_PROFILE_BIT_ARB
            );
        }

        if flags & .Debug
        {
            array_add (*attribs,
                WGL_CONTEXT_FLAGS_ARB,
                WGL_CONTEXT_DEBUG_BIT_ARB
            );
        }

        array_add (*attribs, 0, 0);

        // @Todo: make sure the ShareContexts function still works when calling
        // wglCreateContextAttribsARB.
        ctx = wglCreateContextAttribsARB (hdc, null, attribs.data);
        if !ctx
        {
            log_error ("GL context creation failed with flags % and version %.%", flags, major_version, minor_version);
        }
    }
    else
    {
        if major_version > 0 || flags & .Debug || !(flags & .Compatibility_Profile)
        {
            log_error ("Cannot create GL context with flags % because wglCreateContextAttribsARB is not loaded. Did you forget to call LoadGL? Falling back to legacy wglCreateContext", flags);
        }

        ctx = Win32.wglCreateContext (hdc);
    }

    Win32.wglMakeCurrent (hdc, ctx);

    return ctx;
}

DestroyContext :: inline (ctx : GLContext) #no_context
{
    Win32.wglDeleteContext (ctx);
}

MakeCurrent :: inline (window : *Window, ctx : GLContext) #no_context
{
    hdc := Win32.GetDC (window.hwnd);
    Win32.wglMakeCurrent (hdc, ctx);
}

SetSwapInterval :: inline (interval : int)
{
    // @Todo
}

ShareContexts :: inline (first : GLContext, second : GLContext) -> bool #no_context
{
    return xx Win32.wglShareLists (first, second);
}

GetCurrentContext :: inline () -> GLContext #must #no_context
{
    return Win32.wglGetCurrentContext ();
}

GetCurrentWindow :: inline () -> *Window #must, non_fenetres_window : bool #no_context
{
    hdc := Win32.wglGetCurrentDC ();
    if !hdc
        return null, false;

    hwnd := Win32.WindowFromDC (hdc);
    if !hwnd
        return null, false;

    window := GetWindowFromPlatformHandle (hwnd);
    if !window
        return null, true;

    return window, false;
}
