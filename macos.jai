#import "Basic";
#import "Objective_C";
#import "Objective_C/AppKit";
#import "Objective_C/LightweightRenderingView";

Window :: struct
{
    #as using handle : *NSWindow;
}

GetPlatformHandle :: inline (window : *Window) -> *void #must #no_context
{
    return window.handle;
}

CreateWindowExtraParams :: struct
{
}

#scope_file

g_all_windows : [..]*Window;
g_initialized : bool;

InitObjectiveCStuff :: ()
{
    if g_initialized
        return;

    init_objective_c ();
    init_app_kit ();
    init_lightweight_rendering_view ();

    RegisterObjectiveCClass (AppDelegate, NSObject);
    RegisterObjectiveCClass (WindowDelegate, NSObject);

    NSApplication.sharedApplication ();

    delegate := objc_init (objc_alloc (AppDelegate));
    NSApp.setDelegate (NSApp, delegate);

    // NSApp is a global variable representing the app instance
    NSApp.finishLaunching (NSApp);

    g_initialized = true;
}

RegisterObjectiveCClass :: ($T : Type, $parent : Type)
{
    class := objc_create_class (T, parent);
    #insert -> string
    {
        builder : String_Builder;

        info := type_info (T);
        for info.members
        {
            is_method := false;
            for note : it.notes
            {
                if note == "ObjectiveCMethod"
                {
                    is_method = true;
                    break;
                }
            }

            if is_method
            {
                print (*builder,
                    "objc_add_instance_method (class, %.%, \"%:\");\n",
                    T, it.name, it.name
                );
            }
        }

        return builder_to_string (*builder);
    }

    objc_finalize_class (class);
}

AppDelegate :: struct
{
    #as using _ : NSApplicationDelegate;

    applicationShouldTerminate :: (using self : *AppDelegate, sel : Selector, sender : id) -> NSApplicationTerminateReply #c_call
    {
        return NSTerminateCancel;
    }
    @ObjectiveCMethod

    applicationWillTerminate :: (using self : *AppDelegate, sel : Selector, notifictation : *NSNotification) #c_call
    {
    }
    @ObjectiveCMethod

    applicationDidResignActive :: (using self : *AppDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
    }
    @ObjectiveCMethod

    applicationDidBecomeActive :: (using self : *AppDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
    }
    @ObjectiveCMethod

    applicationDidFinishLaunching :: (using self : *AppDelegate, sel : Selector, app : *NSApplication) #c_call
    {
        NSApp.setActivationPolicy (NSApp, NSApplicationActivationPolicyRegular);
        NSApp.activateIgnoringOtherApps (NSApp, YES);
        NSApp.stop (NSApp, null);
    }
    @ObjectiveCMethod
}

WindowDelegate :: struct
{
    #as using _ : NSObject;
}

#scope_export

CreateWindow :: (
    title : string,
    width : s32, height : s32,
    x : s32 = Window_Default_Pos, y : s32 = Window_Default_Pos,
    flags : WindowFlags = 0,
    parent : *Window = null,
    extra : CreateWindowExtraParams = .{}
) -> *Window #must
{
    InitObjectiveCStuff ();

    target_screen := NSScreen.mainScreen ();

    target_frame : NSRect;
    target_frame.origin = .{xx x, xx y};
    target_frame.size = .{xx width, xx height};

    flags := NSWindowStyleMaskTitled | NSWindowStyleMaskResizable
        | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;

    window := objc_alloc (NSWindow);
    window = window.initWithContentRect (window, target_frame, flags, NSBackingStoreBuffered, NO, target_screen);

    autorelease (window);

    delegate := objc_init (objc_alloc (WindowDelegate));
    window.setDelegate (window, delegate);

    content_view := objc_alloc (LightweightOpenGLView);
    objc_init (content_view);

    content_view.setWantsLayer (content_view, YES);
    content_view.setWantsBestResolutionOpenGLSurface (content_view, YES);
    autorelease (content_view);

    window.setContentView (window, content_view);
    window.makeFirstResponder (window, content_view);

    window.setReleasedWhenClosed (window, NO);
    window.setTitle (window, title);

    if x == Window_Default_Pos || y == Window_Default_Pos
        window.center (window);

    // window.setCollectionBehavior (window, NSWindowCollectionBehaviorFullScreenPrimary | NSWindowCollectionBehaviorManaged);
    window.makeKeyAndOrderFront (window, null);

    result := New (Window);
    result.handle = window;
    array_add (*g_all_windows, result);

    return result;
}

DestroyWindow :: inline (window : *Window)
{
    release (window.handle);
    free (window);
}

CloseWindow :: inline (window : *Window) #no_context
{
}

GetWindowTitle :: inline (window : *Window) -> string #must
{
}

SetWindowTitle :: inline (window : *Window, title : string)
{
    window.setTitle (window, title);
}

GetWindowPosition :: inline (window : *Window) -> x : s32, y : s32 #no_context
{
}

SetWindowPosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
}

GetWindowSize :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
}

SetWindowSize :: inline (window : *Window, width : s32, height : s32) #no_context
{
}

GetViewportPosition :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
}

SetViewportPosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
}

GetViewportSize :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
}

SetViewportSize :: inline (window : *Window, width : s32, height : s32) #no_context
{
}

GetFocusedWindow :: () -> *Window #must, non_fenetres_window_focused : bool #no_context
{
}

SetFocusedWindow :: inline (window : *Window) #no_context
{
}

IsFocused :: inline (window : *Window) -> bool #must #no_context
{
}

IsMaximized :: inline (window : *Window) -> bool #must #no_context
{
}

IsMinimized :: inline (window : *Window) -> bool #must #no_context
{
}

Maximize :: inline (window : *Window) #no_context
{
}

Restore :: inline (window : *Window) #no_context
{
}

Minimize :: inline (window : *Window) #no_context
{
}

SetWindowVisibility :: inline (window : *Window, visible : bool) #no_context
{
}

ShowAndFocusWindow :: inline (window : *Window) #no_context
{
}

GetMousePosition :: inline () -> x : s32, y : s32 #no_context
{
}

SetMousePosition :: inline (x : s32, y : s32) #no_context
{
}

ScreenToWindowPosition :: inline (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context
{
}

WindowToScreenPosition :: inline (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context
{
}

GetMousePosition :: inline (window : *Window) -> x : s32, y : s32 #no_context
{
}

SetMousePosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
}

SetMouseCapture :: inline (window : *Window, capture : bool) #no_context
{
}

GetMouseCapture :: inline () -> *Window #must, non_fenetres_window : bool #no_context
{
}

PollMessages :: () -> []Message
{
    past := NSDate.distantPast ();
    while true
    {
        event := NSApp.nextEventMatchingMask (NSApp, NSEventMaskAny, past, NSDefaultRunLoopMode, YES);
        if !event
            break;

        NSApp.sendEvent (NSApp, event);
    }

    NSApp.updateWindows (NSApp);

    return .[];
}

SetCursor :: inline (window : *Window, cursor : SystemCursor) #no_context
{
}

SetCursorConstraint :: inline (x : s32, y : s32, w : s32, h : s32) -> bool #no_context
{
}

RemoveCursorConstraint :: inline () -> bool #no_context
{
}

GetKeyModState :: inline () -> KeyMods #must #no_context
{
}

GetClipboardTextData :: () -> string #must
{
}

SetClipboardTextData :: (text : string)
{
}

ClearClipboard :: inline ()
{
}
