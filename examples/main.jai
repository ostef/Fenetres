Fenetres :: #import, file "../module.jai";

main :: ()
{
    window := Fenetres.CreateWindow ("Fenetres Example", 1280, 720);

    quit := false;
    while !quit
    {
        for Fenetres.PollMessages ()
        {
            if it.kind == .Window_Closed
                quit = true;
        }
    }
}
