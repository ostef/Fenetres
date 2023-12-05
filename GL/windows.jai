#import "Basic";

#scope_module

Win32 :: #import "Win32" (WGL = true, GDI_Basics = true);

#scope_export

// @Todo: choose OpenGL version
// @Todo: multisampling
// @Todo: share lists

GLContext :: Win32.HGLRC;

GLContextFlags :: enum_flags
{
    Multi_Sampled;
}

GetProcAddress :: Win32.wglGetProcAddress;

CreateContext :: inline (window : *Window, flags := GLContextFlags.Multi_Sampled) -> GLContext #must
{
    hdc := Win32.GetDC (window.hwnd);
    pfd : Win32.PIXELFORMATDESCRIPTOR;
    pfd.nSize = size_of (Win32.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = Win32.PFD_DRAW_TO_WINDOW | Win32.PFD_SUPPORT_OPENGL | Win32.PFD_DOUBLEBUFFER;
    pfd.iPixelType = Win32.PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.cStencilBits = 8;

    if flags  & .Multi_Sampled && !wglChoosePixelFormatARB
    {
        log_error ("Cannot create multisampled GL context because wglChoosePixelFormatARB function is not loaded");
    }

    pixel_format : s32;

    if flags & .Multi_Sampled && wglChoosePixelFormatARB
    {
        attributes := s32.[
            WGL_DRAW_TO_WINDOW_ARB, 1,
            WGL_SUPPORT_OPENGL_ARB, 1,
            WGL_DOUBLE_BUFFER_ARB, 1,
            WGL_PIXEL_TYPE_ARB, WGL_TYPE_RGBA_ARB,
            WGL_COLOR_BITS_ARB, 32,
            WGL_DEPTH_BITS_ARB, 24,
            WGL_STENCIL_BITS_ARB, 8,
            WGL_SAMPLE_BUFFERS_ARB, 1,
            WGL_SAMPLES_ARB, 4,
            0
        ];
        num_formats : u32;
        float_attributes := float.[0,0];

        valid := wglChoosePixelFormatARB (hdc, attributes.data, float_attributes.data, 1, *pixel_format, *num_formats);

        if !valid || num_formats < 1
        {
            log_error ("wglChoosePixelFormatARB failed. GL context creation flags were %", flags);
            pixel_format = Win32.ChoosePixelFormat (hdc, *pfd);
        }
    }
    else
    {
        pixel_format = Win32.ChoosePixelFormat (hdc, *pfd);
    }

    Win32.SetPixelFormat (hdc, pixel_format, *pfd);

    return Win32.wglCreateContext (hdc);
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
