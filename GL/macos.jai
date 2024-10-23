#import "Fenetres";

#import "Basic";
#import "Objective_C";
#import "Objective_C/AppKit";
#import "Objective_C/LightweightRenderingView";

GLContext :: *NSOpenGLContext;

GLContextFlags :: enum_flags
{
    Multi_Sampled;
    Compatibility_Profile;
    Debug;
}

#scope_file

g_gl_lib : *void;
g_selector : struct
{
    getValues_forParameter_ : Selector;
    window : Selector;
};

#scope_export

GetProcAddress :: (name : *u8) -> *void #c_call
{
    POSIX :: #import "POSIX";

    if !g_gl_lib
        g_gl_lib = POSIX.dlopen("/System/Library/Frameworks/OpenGL.framework/Versions/Current/OpenGL", POSIX.RTLD_LAZY);

    return POSIX.dlsym(g_gl_lib, name);
}

CreateContextWithoutWindow :: (flags : GLContextFlags = 0, major_version : s32 = 0, minor_version : s32 = 0) -> GLContext #must
{
    log_warning :: inline (fmt_str : string, args : ..Any, location := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0)
    {
        log(fmt_str, ..args, location, flags | .WARNING, user_flags);
    }

    if !g_selector.window
        init_objective_c_selector_struct(*g_selector);
    init_lightweight_rendering_view();

    if flags & .Compatibility_Profile
        log_error("Compatibility profile is not supported on MacOS, using Core profile");

    attribs : [..]NSOpenGLPixelFormatAttribute;
    attribs.allocator = temp;

    array_add(*attribs,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8
    );

    if flags & .Multi_Sampled
    {
        array_add(*attribs,
            NSOpenGLPFAMultisample,
            NSOpenGLPFASampleBuffers, 1,
            NSOpenGLPFASamples, 4
        );
    }

    array_add(*attribs, NSOpenGLPFAOpenGLProfile);

    if major_version == 0 && minor_version == 0
    {
        major_version = 4;
        minor_version = 1;
        array_add(*attribs, NSOpenGLProfileVersion4_1Core);
    }
    else if major_version >= 4
    {
        if minor_version != 1
            log_error("OpenGL version 4.% is not available on MacOS, using OpenGL 4.1", minor_version);
        minor_version = 1;
        array_add(*attribs, NSOpenGLProfileVersion4_1Core);
    }
    else if major_version >= 3
    {
        if minor_version != 2
            log_error("OpenGL version 3.% is not available on MacOS, using OpenGL 3.2", minor_version);
        minor_version = 2;

        array_add(*attribs, NSOpenGLProfileVersion3_2Core);
    }
    else if major_version != 0 && minor_version != 0
    {
        array_add(*attribs, NSOpenGLProfileVersionLegacy);
    }

    array_add(*attribs, 0);

    pixel_format := objc_alloc(NSOpenGLPixelFormat);
    pixel_format = pixel_format.initWithAttributes(pixel_format, attribs.data);
    if !pixel_format
    {
        log_error("Could not create pixel format (flags: %, version: %.%)", flags, major_version, minor_version);

        return null;
    }

    ctx := objc_alloc(NSOpenGLContext);
    ctx = ctx.initWithFormat(ctx, pixel_format, null);
    if !ctx
    {
        log_error("Could not create GL context (flags: %, version: %.%)", flags, major_version, minor_version);
        return null;
    }

    ctx.makeCurrentContext(ctx);
    ctx.update(ctx);

    return ctx;
}

CreateContext :: inline (window : *Window, flags := GLContextFlags.Multi_Sampled, major_version : s32 = 0, minor_version : s32 = 0) -> GLContext #must
{
    ctx := CreateContextWithoutWindow(flags, major_version, minor_version);
    if !ctx
        return null;

    gl_view := objc_init(objc_alloc(LightweightOpenGLView));
    gl_view.setGlContext(gl_view, ctx);
    gl_view.setWantsLayer(gl_view, YES);
    gl_view.setWantsBestResolutionOpenGLSurface(gl_view, YES);
    autorelease(gl_view);

    ctx.setView(ctx, gl_view);

    window.setContentView(window, gl_view);
    window.makeFirstResponder(window, gl_view);
    window.update(window);

    ctx.update(ctx);

    return ctx;
}

DestroyContext :: inline (ctx : GLContext) #no_context
{
    release(ctx);
}

MakeCurrent :: inline (window : *Window, ctx : GLContext) #no_context
{
    x : Context;
    push_context, defer_pop x;

    ctx.makeCurrentContext(ctx);
}

ShareContexts :: inline (first : GLContext, second : GLContext) -> bool #no_context
{
    //log_error("Unsupported after context creation on MacOS. Todo: add a parameter for this to CreateContext");
    return false;
}

GetCurrentContext :: inline () -> GLContext #must #no_context
{
    c : Context;
    push_context, defer_pop c;

    return NSOpenGLContext.currentContext();
}

GetCurrentWindow :: inline () -> *Window #must, non_fenetres_window : bool #no_context
{
    c : Context;
    push_context, defer_pop c;

    ctx := GetCurrentContext();
    if !ctx
        return null, false;

    view := ctx.view(ctx);
    if !view
        return null, false;

    ns_window := cast(*NSWindow) objc_msgSend_typed(view, g_selector.window);
    if !ns_window
        return null, false;

    window := GetWindowFromPlatformHandle(ns_window);

    return window, window == null;
}

SwapBuffers :: inline (window : *Window) #no_context
{
    c : Context;
    push_context, defer_pop c;

    view := cast(*LightweightOpenGLView) window.contentView(window);
    if !view
        return;

    view.swapBuffers(view);
}

SetSwapInterval :: inline (interval : s32) -> bool #no_context
{
    c : Context;
    push_context, defer_pop c;

    ctx := NSOpenGLContext.currentContext();
    if !ctx
        return false;

    ctx.setValues(ctx, *interval, NSOpenGLContextParameterSwapInterval);

    return true;
}

GetSwapInterval :: inline () -> s32 #must #no_context
{
    c : Context;
    push_context, defer_pop c;

    ctx := NSOpenGLContext.currentContext();
    if !ctx
        return 0;

    func : #type(*void, Selector, *s32, NSOpenGLContextParameter) -> void #c_call;
    func = xx objc_msgSend;

    result : s32;
    func(ctx, g_selector.getValues_forParameter_, *result, NSOpenGLContextParameterSwapInterval);

    return result;
}
