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

LoadGL :: ()
{
    #import "GL";

    dummy_window := CreateWindow ("Dummy Window", -1, -1, -1, -1, .Hidden);
    defer DestroyWindow (dummy_window);

    dummy_ctx := CreateContext (dummy_window, .Compatibility_Profile);
    defer DestroyContext (dummy_ctx);

    gl_load (*gl, GetProcAddress);
}
