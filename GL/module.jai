#import "Fenetres";

#if OS ==
{
case .WINDOWS;
    #load "windows.jai";
case .MACOS;
    #load "macos.jai";
case;
    #assert false "Unsupported OS";
}

LoadGL :: () -> bool
{
    #import "GL";

    #if OS == .MACOS
    {

    // No need for a window on MacOS
    dummy_ctx := CreateContextWithoutWindow ();
    if !dummy_ctx
        return false;

    defer DestroyContext (dummy_ctx);

    }
    else
    {

    dummy_window := CreateWindow ("Dummy Window", -1, -1, -1, -1, .Hidden);
    if !dummy_window
        return false;

    defer DestroyWindow (dummy_window);

    dummy_ctx := CreateContext (dummy_window, .Compatibility_Profile);
    if !dummy_ctx
        return false;

    defer DestroyContext (dummy_ctx);

    }

    gl_load (*gl, GetProcAddress);

    return true;
}
