Fenetres :: #import "Fenetres";
#import "Objective_C";
#import "Objective_C/AppKit";
#import "Metal";

#scope_file

g_objc_selectors : struct
{
    setLayer_ : Selector;
    initWithFrame_ : Selector;
};

// Needs to have the same name as in the Objective-C source code
FenetresMetalView :: struct
{
    #as using base : NSView;

    initWithFrame :: (view : *FenetresMetalView, frame : NSRect) -> *FenetresMetalView
    {
        func : (*FenetresMetalView, Selector, NSRect) -> *FenetresMetalView #c_call;
        func = xx objc_msgSend;

        return func(view, g_objc_selectors.initWithFrame_, frame);
    }
}

setLayer :: (view : *NSView, layer : *CALayer)
{
    func : (*NSView, Selector, *CALayer) #c_call;
    func = xx objc_msgSend;

    func(view, g_objc_selectors.setLayer_, layer);
}

#scope_export

CreateMetalView :: (window : *Fenetres.Window) -> *CAMetalLayer
{
    if !g_objc_selectors.initWithFrame_
    {
        init_objective_c_selector_struct(*g_objc_selectors);
    }

    nothing := tprint("%", __view_class_object);

    view := window.contentView(window.handle);

    metal_view := FenetresMetalView.initWithFrame(objc_alloc(FenetresMetalView), view.frame(view));
    if !metal_view
        return null;

    autorelease(metal_view);

    window.setContentView(window.handle, metal_view);
    window.makeFirstResponder(window.handle, metal_view);
    window.update(window.handle);

    return xx metal_view.layer(metal_view);
}

#scope_file

#run
{
    #import "Basic";
    #import "Compiler";
    #import "BuildCpp";
    #import "Process";
    #import "File_Utilities";

    // Not sure if this is a good idea since the compiler might try to load files
    // while this executes
    wd := get_working_directory();
    set_working_directory(#filepath);
    defer set_working_directory(wd);

    // if file_exists("libFenetresMetal.a")
    //     return;

    macos_x64_version_arg   := "-mmacos-version-min=11.0"; // Our current x64 min version
    macos_arm64_version_arg := "-mmacos-version-min=11.0";  // Earliest version that supports arm64

    success :=  build_cpp_dynamic_lib("libFenetresMetal_x64", "metal_view.m", extra = .["-arch", "x86_64", "-framework", "AppKit", "-framework", "QuartzCore", macos_x64_version_arg]);
    success &&= build_cpp_static_lib( "libFenetresMetal_x64", "metal_view.m", extra = .["-arch", "x86_64", "-framework", "AppKit", "-framework", "QuartzCore", macos_x64_version_arg]);

    success &&= build_cpp_dynamic_lib("libFenetresMetal_arm64", "metal_view.m", extra = .["-arch", "arm64", "-framework", "AppKit", "-framework", "QuartzCore", macos_arm64_version_arg]);
    success &&= build_cpp_static_lib( "libFenetresMetal_arm64", "metal_view.m", extra = .["-arch", "arm64", "-framework", "AppKit", "-framework", "QuartzCore", macos_arm64_version_arg]);

    // Create universal binaries
    run_result := run_command("lipo", "-create", "libFenetresMetal_x64.dylib", "libFenetresMetal_arm64.dylib", "-output", "libFenetresMetal.dylib");
    success &&= (run_result.exit_code == 0);
    run_result =  run_command("lipo", "-create", "libFenetresMetal_x64.a",     "libFenetresMetal_arm64.a",     "-output", "libFenetresMetal.a");
    success &&= (run_result.exit_code == 0);

    if !success
        compiler_set_workspace_status(.FAILED);
}

QuartzCore :: #system_library,link_always "QuartzCore"; // For CAMetalLayer

libFenetresMetal :: #library,link_always "libFenetresMetal";

__view_class_object: *void #elsewhere libFenetresMetal "OBJC_CLASS_$_FenetresMetalView";
