#import "Basic";
Fenetres :: #import "Fenetres";
X11 :: #import "X11";

main :: ()
{
    window := Fenetres.CreateWindow("Hello Fenetres", 900, 900, 10, 10);
    assert(window != null);

    defer Fenetres.DestroyWindow(window);

    d := X11.XOpenDisplay(null);
    while true
    {
        e : X11.XEvent;
        X11.XNextEvent(d, *e);
        print("%\n", e.type);
    }
}
