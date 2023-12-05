#import "Fenetres";

#if OS == .WINDOWS
    #load "windows.jai";
else
    #assert false "Unsupported OS";

LoadGL :: ()
{
    #import "GL";

    dummy_window := CreateWindow ("Dummy Window", -1, -1, -1, -1, .Hidden);
    defer DestroyWindow (dummy_window);

    dummy_ctx := CreateContext (dummy_window, 0);
    defer DestroyContext (dummy_ctx);

    MakeCurrent (dummy_window, dummy_ctx);

    gl_load (*gl, GetProcAddress);
}
