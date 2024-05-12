Fenetres :: #import "Fenetres";
Fenetres_GL :: #import "Fenetres/GL";

#import "GL";

main :: ()
{
    window := Fenetres.CreateWindow ("Fenetres Example", 1280, 720);
    defer Fenetres.DestroyWindow (window);

    gl_context := Fenetres_GL.CreateContext (window);
    defer Fenetres_GL.DestroyContext (gl_context);

    Fenetres_GL.MakeCurrent (window, gl_context);

    gl_load (*gl, Fenetres_GL.GetProcAddress);

    quit := false;
    while !quit
    {
        for Fenetres.PollMessages ()
        {
            if it.kind == .Window_Closed
                quit = true;
        }

        glClearColor (0.1, 0.3, 0.8, 1.0);
        glClear (GL_COLOR_BUFFER_BIT);

        Fenetres_GL.SwapBuffers (window);
    }
}
