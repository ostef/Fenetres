Fenetres :: #import "Fenetres";
Fenetres_GL :: #import "Fenetres/GL";

#import "Basic";
#import "GL";

main :: ()
{
    window := Fenetres.CreateWindow ("Fenetres Example", 1280, 720);
    defer Fenetres.DestroyWindow (window);
    WindowTests (window);

    gl_context := Fenetres_GL.CreateContext (window);
    defer Fenetres_GL.DestroyContext (gl_context);

    Fenetres_GL.MakeCurrent (window, gl_context);

    assert (Fenetres_GL.GetCurrentWindow () == window);
    assert (Fenetres_GL.GetCurrentContext () == gl_context);

    gl_load (*gl, Fenetres_GL.GetProcAddress);

    quit := false;
    while !quit
    {
        for Fenetres.PollMessages ()
        {
            // if it.kind != .Mouse_Moved && it.kind != .Mouse_Raw_Moved
            //     Fenetres.PrintMessage (it);

            if it.kind == .Window_Closed
                quit = true;
        }

        glClearColor (0.1, 0.3, 0.8, 1.0);
        glClear (GL_COLOR_BUFFER_BIT);

        Fenetres_GL.SwapBuffers (window);
    }
}

WindowTests :: (window : *Fenetres.Window)
{
    print("%\n", Fenetres.GetWindowTitle (window));

    x, y := Fenetres.GetWindowPosition (window);
    w, h := Fenetres.GetWindowSize (window);
    print("% % % %\n", x, y, w, h);

    x, y = Fenetres.GetViewportPosition (window);
    w, h = Fenetres.GetViewportSize (window);
    print("% % % %\n", x, y, w, h);

    Fenetres.SetWindowPosition (window, 100, 100);
    x, y = Fenetres.GetWindowPosition (window);
    assert (x == 100 && y == 100, "% %", x, y);

    Fenetres.SetWindowSize (window, 200, 200);
    w, h = Fenetres.GetWindowSize (window);
    assert (x == 100 && y == 100, "% %", x, y);
    assert (w == 200 && h == 200, "% %", w, h);

    Fenetres.SetViewportPosition (window, 100, 100);
    x, y = Fenetres.GetViewportPosition (window);
    assert (x == 100 && y == 100, "% %", x, y);

    Fenetres.SetViewportSize (window, 200, 200);
    w, h = Fenetres.GetViewportSize (window);
    assert (x == 100 && y == 100, "% %", x, y);
    assert (w == 200 && h == 200, "% %", w, h);
}
