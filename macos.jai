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

GetWindowFromPlatformHandle :: inline (handle : *void) -> *Window #must #no_context
{
    for g_all_windows
    {
        if it.handle == handle
            return it;
    }

    return null;
}

CreateWindowExtraParams :: struct
{
}

#scope_file

g_selector : struct
{
    title : Selector;
    screen : Selector;
};

g_all_windows : [..]*Window;
g_initialized : bool;

InitObjectiveCStuff :: ()
{
    if g_initialized
        return;

    init_objective_c ();
    init_app_kit ();
    init_lightweight_rendering_view ();
    init_objective_c_selector_struct (*g_selector);

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
    // We set the position afterwards, because we need to know some info
    // about the already created window to properly position it
    target_frame.origin = .{0, 0};
    target_frame.size = .{xx width, xx height};

    flags := NSWindowStyleMaskTitled | NSWindowStyleMaskResizable
        | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;

    window := objc_alloc (NSWindow);
    window.initWithContentRect (window, target_frame, flags, NSBackingStoreBuffered, NO, target_screen);

    autorelease (window);

    delegate := objc_init (objc_alloc (WindowDelegate));
    window.setDelegate (window, delegate);

    window.setReleasedWhenClosed (window, NO);
    window.setTitle (window, title);

    if x == Window_Default_Pos || y == Window_Default_Pos
    {
        window.center (window);
    }
    else
    {
        point := NSPoint.{
            xx x,
            xx (y + GetWindowTitleBarHeight (window) + height)
        };
        point = InvertY (target_screen, point);
        window.setFrameOrigin (window, point);
    }

    window.setCollectionBehavior (window, NSWindowCollectionBehaviorFullScreenPrimary | NSWindowCollectionBehaviorManaged);
    window.makeKeyAndOrderFront (window, null);

    result := New (Window);
    result.handle = window;
    array_add (*g_all_windows, result);

    return result;
}

#scope_file

GetWindowScreen :: inline (window : *NSWindow) -> *NSScreen
{
    return cast (*NSScreen) objc_msgSend_typed (window, g_selector.screen);
}

GetWindowTitleBarHeight :: inline (window : *NSWindow) -> s32 #must
{
    rect := window.frame (window);
    view := window.contentView (window);
    view_rect := view.frame (view);

    return xx (rect.size.height - view_rect.size.height);
}

InvertY :: inline (screen : *NSScreen, point : NSPoint) -> NSPoint #must
{
    screen_rect := screen.frame (screen);

    return .{
        point.x,
        screen_rect.size.height - point.y,
    };
}

#scope_export

DestroyWindow :: inline (window : *Window)
{
    release (window.handle);
    free (window);
}

CloseWindow :: inline (window : *Window) #no_context
{
    window.close (window);
}

GetWindowTitle :: inline (window : *Window) -> string #must
{
    ns_string := cast (*NSString) objc_msgSend_typed (window.handle, g_selector.title);
    defer release (ns_string);

    result := string.{
        xx ns_string.length (ns_string),
        ns_string.UTF8String (ns_string)
    };

    return copy_string (result);
}

SetWindowTitle :: inline (window : *Window, title : string)
{
    window.setTitle (window, title);
}

GetWindowPosition :: inline (window : *Window) -> x : s32, y : s32 #no_context
{
    ctx : Context;
    push_context ctx
    {
        rect := window.frame (window);
        position := InvertY (GetWindowScreen (window), rect.origin);

        return xx position.x, xx (position.y - rect.size.height);
    }
}

SetWindowPosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
    ctx : Context;
    push_context ctx
    {
        _, height := GetWindowSize (window);
        point := InvertY (GetWindowScreen (window), .{xx x, xx y});
        point.y -= xx height;
        window.setFrameOrigin (window, point);
    }
}

GetWindowSize :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
    ctx : Context;
    push_context ctx
    {
        rect := window.frame (window);

        return xx rect.size.width, xx rect.size.height;
    }
}

SetWindowSize :: inline (window : *Window, width : s32, height : s32) #no_context
{
    ctx : Context;
    push_context ctx
    {
        rect := window.frame (window);
        rect.size.width = xx width;
        rect.size.height = xx height;
        window.setFrame (window, rect, NO);
    }
}

GetViewportPosition :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
    ctx : Context;
    push_context ctx
    {
        x, y := GetWindowPosition (window);

        return x, y + GetWindowTitleBarHeight (window);
    }
}

SetViewportPosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
    ctx : Context;
    push_context ctx
    {
        _, height := GetViewportSize (window);
        point := InvertY (GetWindowScreen (window), .{xx x, xx y});
        point.y -= xx height;
        window.setFrameOrigin (window, point);
    }
}

GetViewportSize :: inline (window : *Window) -> width : s32, height : s32 #no_context
{
    ctx : Context;
    push_context ctx
    {
        view := window.contentView (window);
        rect := view.frame (view);

        return xx rect.size.width, xx rect.size.height;
    }
}

SetViewportSize :: inline (window : *Window, width : s32, height : s32) #no_context
{
    ctx : Context;
    push_context ctx
    {
        rect := window.frame (window);
        rect.size.width = xx width;
        rect.size.height = xx (height + GetWindowTitleBarHeight (window));
        window.setFrame (window, rect, NO);
    }
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
