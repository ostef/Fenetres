#import "Basic";
Fenetres :: #import "Fenetres";
Fenetres_GL :: #import "Fenetres/GL";

main :: ()
{
    window := Fenetres.CreateWindow("Hello Fenetres", 900, 480, 10, 10);
    assert(window != null);

    defer Fenetres.DestroyWindow(window);

    quit := false;
    while !quit
    {
        msgs := Fenetres.PollMessages();
        for msgs
        {
            Fenetres.PrintMessage(it);

            if it.kind == .Window_Closed
                quit = true;
        }
    }
}
