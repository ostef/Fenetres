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
    window : Selector;
    clickCount : Selector;
    scrollingDeltaX : Selector;
    scrollingDeltaY : Selector;
    locationInWindow : Selector;
    mouseLocation : Selector;
    screens : Selector;
};

g_all_windows : [..]*Window;
g_initialized : bool;
g_message_queue : [..]Message;
g_non_polled_messages : [..]Message;

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

    windowWillClose :: (using self : *WindowDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
        ctx : Context;
        push_context, defer_pop ctx;

        ns_window := cast (*NSWindow) notification.object (notification);
        window := GetWindowFromPlatformHandle (ns_window);
        if window
        {
            msg : Message;
            msg.kind = .Window_Closed;
            msg.window = window;
            array_add (*g_non_polled_messages, msg);
        }
    }
    @ObjectiveCMethod

    windowDidResize :: (using self : *WindowDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
        ctx : Context;
        push_context, defer_pop ctx;

        ns_window := cast (*NSWindow) notification.object (notification);
        window := GetWindowFromPlatformHandle (ns_window);
        if window
        {
            msg : Message;
            msg.kind = .Window_Resized;
            msg.window = window;
            msg.window_w, msg.window_h = GetWindowSize (window);
            msg.viewport_w, msg.viewport_h = GetViewportSize (window);
            array_add (*g_non_polled_messages, msg);
        }
    }
    @ObjectiveCMethod

    windowDidMove :: (using self : *WindowDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
        ctx : Context;
        push_context, defer_pop ctx;

        ns_window := cast (*NSWindow) notification.object (notification);
        window := GetWindowFromPlatformHandle (ns_window);
        if window
        {
            msg : Message;
            msg.kind = .Window_Moved;
            msg.window = window;
            msg.window_x, msg.window_y = GetWindowPosition (window);
            array_add (*g_non_polled_messages, msg);
        }
    }
    @ObjectiveCMethod

    windowDidMiniaturize :: (using self : *WindowDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
        ctx : Context;
        push_context, defer_pop ctx;

        ns_window := cast (*NSWindow) notification.object (notification);
        window := GetWindowFromPlatformHandle (ns_window);
        if window
        {
            msg : Message;
            msg.kind = .Window_Minimized;
            msg.window = window;
            array_add (*g_non_polled_messages, msg);
        }
    }
    @ObjectiveCMethod

    windowDidDeminiaturize :: windowDidResize; @ObjectiveCMethod

    windowDidEnterFullscreen :: (using self : *WindowDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
        ctx : Context;
        push_context, defer_pop ctx;

        ns_window := cast (*NSWindow) notification.object (notification);
        window := GetWindowFromPlatformHandle (ns_window);
        if window
        {
            msg : Message;
            msg.kind = .Window_Maximized;
            msg.window = window;
            array_add (*g_non_polled_messages, msg);

            msg.kind = .Window_Resized;
            msg.window_w, msg.window_h = GetWindowSize (window);
            msg.viewport_w, msg.viewport_h = GetViewportSize (window);
            array_add (*g_non_polled_messages, msg);
        }
    }
    @ObjectiveCMethod

    windowDidExitFullscreen :: windowDidResize; @ObjectiveCMethod

    windowDidBecomeKey :: (using self : *WindowDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
        ctx : Context;
        push_context, defer_pop ctx;

        ns_window := cast (*NSWindow) notification.object (notification);
        window := GetWindowFromPlatformHandle (ns_window);
        if window
        {
            msg : Message;
            msg.kind = .Window_Received_Focus;
            msg.window = window;
            array_add (*g_non_polled_messages, msg);
        }
    }
    @ObjectiveCMethod

    windowDidResignKey :: (using self : *WindowDelegate, sel : Selector, notification : *NSNotification) #c_call
    {
        ctx : Context;
        push_context, defer_pop ctx;

        ns_window := cast (*NSWindow) notification.object (notification);
        window := GetWindowFromPlatformHandle (ns_window);
        if window
        {
            msg : Message;
            msg.kind = .Window_Lost_Focus;
            msg.window = window;
            array_add (*g_non_polled_messages, msg);
        }
    }
    @ObjectiveCMethod
}

#scope_export

GetDisplays :: inline () -> []DisplayInfo #must
{
    InitObjectiveCStuff ();

    func : (*void, Selector) -> *NSArray (*NSScreen) #c_call;
    func = xx objc_msgSend;

    screens := func (class (NSScreen), g_selector.screens);
    defer release (screens);

    count := screens.count (screens);
    if count == 0
        return .[];

    result := NewArray (xx count, DisplayInfo);
    for i : 0..count - 1
    {
        screen := screens.objectAtIndex (screens, i);
        frame := screen.frame (screen);

        display := *result[i];
        display.is_primary = i == 0;
        display.x = xx frame.origin.x;
        display.y = xx frame.origin.y;
        display.w = xx frame.size.width;
        display.h = xx frame.size.height;
        display.dpi = xx screen.backingScaleFactor (screen);
    }

    return result;
}

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
    window = window.initWithContentRect (window, target_frame, flags, NSBackingStoreBuffered, NO, target_screen);
    if !window
    {
        log_error ("Could not create window");
        return null;
    }

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
    x, y := GetMousePosition ();
    x, y = ScreenToWindowPosition (window, x, y);

    return x, y;
}

SetMousePosition :: inline (window : *Window, x : s32, y : s32) #no_context
{
    x, y = WindowToScreenPosition (window);
    SetMousePosition (x, y);
}

SetMouseCapture :: inline (window : *Window, capture : bool) #no_context
{
}

GetMouseCapture :: inline () -> *Window #must, non_fenetres_window : bool #no_context
{
}

PollMessages :: () -> []Message
{
    GetEventMousePositionInWindow :: (window : *Window, event : *NSEvent) -> s32, s32
    {
        locationInWindow: (self: *void, op: Selector) -> NSPoint #c_call;
        locationInWindow = xx objc_msgSend;

        position := locationInWindow (event, g_selector.locationInWindow);
        _, window_height := GetWindowSize (window);
        position.y = window_height - position.y;

        return xx position.x, xx position.y;
    }

    g_message_queue.count = 0;
    array_add (*g_message_queue, ..g_non_polled_messages);
    g_non_polled_messages.count = 0;

    past := NSDate.distantPast ();
    while true
    {
        event := NSApp.nextEventMatchingMask (NSApp, NSEventMaskAny, past, NSDefaultRunLoopMode, YES);
        if !event
            break;

        ns_window := cast (*NSWindow) objc_msgSend_typed (event, g_selector.window);
        window := GetWindowFromPlatformHandle (ns_window);
        if !window
        {
            NSApp.sendEvent (NSApp, event);

            continue;
        }

        type := event.type (event);
        if type ==
        {
        case NSEventTypeFlagsChanged;
        case NSEventTypeKeyDown; #through;
        case NSEventTypeKeyUp;
            msg : Message;
            msg.window = window;
            msg.kind = ifx type == NSEventTypeKeyUp
                then .Key_Released
                else ifx event.isARepeat (event)
                then .Key_Repeated
                else .Key_Pressed;

            mods := event.modifierFlags (event);
            if mods & NSEventModifierFlagShift
                msg.mods |= .Shift;
            if mods & NSEventModifierFlagControl
                msg.mods |= .Ctrl;
            if mods & NSEventModifierFlagOption
                msg.mods |= .Option;
            if mods & NSEventModifierFlagCommand
                msg.mods |= .Cmd;

            msg.key_code = CocoaKeyCodeToKeyCode (event.keyCode (event));
            array_add (*g_message_queue, msg);

        case NSEventTypeLeftMouseDown;
            click_count := cast (NSInteger) objc_msgSend_typed (event, g_selector.clickCount);

            msg : Message;
            msg.window = window;
            msg.kind = ifx click_count > 1
                then .Mouse_Button_Repeated
                else .Mouse_Button_Pressed;
            msg.mouse_button = .Left;
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeRightMouseDown;
            click_count := cast (NSInteger) objc_msgSend_typed (event, g_selector.clickCount);

            msg : Message;
            msg.window = window;
            msg.kind = ifx click_count > 1
                then .Mouse_Button_Repeated
                else .Mouse_Button_Pressed;
            msg.mouse_button = .Right;
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeOtherMouseDown;
            click_count := cast (NSInteger) objc_msgSend_typed (event, g_selector.clickCount);

            msg : Message;
            msg.window = window;
            msg.kind = ifx click_count > 1
                then .Mouse_Button_Repeated
                else .Mouse_Button_Pressed;
            msg.mouse_button = .Middle;
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeLeftMouseUp;
            msg : Message;
            msg.window = window;
            msg.kind = .Mouse_Button_Released;
            msg.mouse_button = .Left;
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeRightMouseUp;
            msg : Message;
            msg.window = window;
            msg.kind = .Mouse_Button_Released;
            msg.mouse_button = .Right;
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeOtherMouseUp;
            msg : Message;
            msg.window = window;
            msg.kind = .Mouse_Button_Released;
            msg.mouse_button = .Middle;
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeMouseMoved;
            msg : Message;
            msg.window = window;
            msg.kind = .Mouse_Moved;
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            array_add (*g_message_queue, msg);

            msg.kind = .Mouse_Raw_Moved;
            msg.mouse_delta_x = xx event.deltaX (event);
            msg.mouse_delta_y = xx event.deltaY (event);
            if msg.mouse_delta_x != 0 || msg.mouse_delta_y != 0
                array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeScrollWheel;
            func: (self: *void, op: Selector) -> CGFloat #c_call;
            func = xx objc_msgSend;

            msg : Message;
            msg.window = window;
            msg.kind = .Mouse_Wheel;
            msg.mouse_wheel_x = xx func (event, g_selector.scrollingDeltaX);
            msg.mouse_wheel_y = xx func (event, g_selector.scrollingDeltaY);
            msg.mouse_x, msg.mouse_y = GetEventMousePositionInWindow (window, event);
            if msg.mouse_wheel_x != 0 || msg.mouse_wheel_y != 0
                array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeMouseEntered;
            msg : Message;
            msg.window = window;
            msg.kind = .Mouse_Entered_Window;
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case NSEventTypeMouseExited;
            msg : Message;
            msg.window = window;
            msg.kind = .Mouse_Left_Window;
            array_add (*g_message_queue, msg);

            NSApp.sendEvent (NSApp, event);

        case;
            NSApp.sendEvent (NSApp, event);
        }
    }

    NSApp.updateWindows (NSApp);

    return g_message_queue;
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

CocoaKeyCodeToKeyCode :: (cocoa : u16) -> KeyCode #must
{
    #insert -> string
    {
        builder : String_Builder;

        append (*builder, "if cocoa ==\n{\n");
        for VK_To_Key_Code_Map
        {
            print_to_builder (*builder, "case %; return .%;\n", it.vk, it.key_code);
        }
        append (*builder, "}\n");

        return builder_to_string (*builder);
    };

    return .Invalid;
}

KeyCodeToCocoaKeyCode :: (key_code : KeyCode) -> u16 #must
{
    #insert -> string
    {
        builder : String_Builder;

        append (*builder, "if key_code ==\n{\n");
        for VK_To_Key_Code_Map
        {
            print_to_builder (*builder, "case .%; return %;\n", it.key_code, it.vk);
        }
        append (*builder, "}\n");

        return builder_to_string (*builder);
    };

    return 0;
}

VKKeyCodePair :: struct
{
    vk : u16;
    key_code : KeyCode;
}

VK_To_Key_Code_Map :: VKKeyCodePair.[
    .{OSX_VK_ESCAPE, .Escape},
    .{OSX_VK_F1, .F1},
    .{OSX_VK_F2, .F2},
    .{OSX_VK_F3, .F3},
    .{OSX_VK_F4, .F4},
    .{OSX_VK_F5, .F5},
    .{OSX_VK_F6, .F6},
    .{OSX_VK_F7, .F7},
    .{OSX_VK_F8, .F8},
    .{OSX_VK_F9, .F9},
    .{OSX_VK_F10, .F10},
    .{OSX_VK_F11, .F11},
    .{OSX_VK_F12, .F12},
    .{OSX_VK_BACK_TICK, .Backtick},
    .{OSX_VK_1, .One},
    .{OSX_VK_2, .Two},
    .{OSX_VK_3, .Three},
    .{OSX_VK_4, .Four},
    .{OSX_VK_5, .Five},
    .{OSX_VK_6, .Six},
    .{OSX_VK_7, .Seven},
    .{OSX_VK_8, .Eight},
    .{OSX_VK_9, .Nine},
    .{OSX_VK_0, .Zero},
    .{OSX_VK_DASH, .OEM_Minus},
    .{OSX_VK_EQUAL, .OEM_Plus},
    .{OSX_VK_BACKSPACE, .Backspace},
    .{OSX_VK_TAB, .Tab},
    .{OSX_VK_Q, .Q},
    .{OSX_VK_W, .W},
    .{OSX_VK_E, .E},
    .{OSX_VK_R, .R},
    .{OSX_VK_T, .T},
    .{OSX_VK_Y, .Y},
    .{OSX_VK_U, .U},
    .{OSX_VK_I, .I},
    .{OSX_VK_O, .O},
    .{OSX_VK_P, .P},
    .{OSX_VK_LBRACKET, .Open_Bracket},
    .{OSX_VK_RBRACKET, .Close_Bracket},
    .{OSX_VK_BACKSLASH, .Pipe},
    .{OSX_VK_CAPS_LOCK, .Caps_Lock},
    .{OSX_VK_A, .A},
    .{OSX_VK_S, .S},
    .{OSX_VK_D, .D},
    .{OSX_VK_F, .F},
    .{OSX_VK_G, .G},
    .{OSX_VK_H, .H},
    .{OSX_VK_J, .J},
    .{OSX_VK_K, .K},
    .{OSX_VK_L, .L},
    .{OSX_VK_COLON, .Colon},
    .{OSX_VK_QUOTE, .Quote},
    .{OSX_VK_RETURN, .Return},
    .{OSX_VK_SHIFT, .Shift},
    .{OSX_VK_Z, .Z},
    .{OSX_VK_X, .X},
    .{OSX_VK_C, .C},
    .{OSX_VK_V, .V},
    .{OSX_VK_B, .B},
    .{OSX_VK_N, .N},
    .{OSX_VK_M, .M},
    .{OSX_VK_COMMA, .OEM_Comma},
    .{OSX_VK_PERIOD, .OEM_Period},
    .{OSX_VK_FWD_SLASH, .Slash},
    .{OSX_VK_CONTROL, .Ctrl},
    .{OSX_VK_OPTION, .Alt},
    .{OSX_VK_COMMAND, .Cmd},
    .{OSX_VK_RIGHT_SHIFT, .Right_Shift},
    .{OSX_VK_RIGHT_COMMAND, .Right_Cmd},
    .{OSX_VK_RIGHT_OPTION, .Right_Alt},
    .{OSX_VK_RIGHT_CONTROL, .Right_Ctrl},
    .{OSX_VK_SPACEBAR, .Space},
    .{OSX_VK_INSERT, .Insert},
    .{OSX_VK_HOME, .Home},
    .{OSX_VK_PAGE_UP, .Page_Up},
    .{OSX_VK_DELETE, .Delete},
    .{OSX_VK_END, .End},
    .{OSX_VK_PAGE_DOWN, .Page_Down},
    .{OSX_VK_UP, .Up},
    .{OSX_VK_DOWN, .Down},
    .{OSX_VK_RIGHT, .Right},
    .{OSX_VK_LEFT, .Left},
    .{OSX_VK_NUMLOCK, .Num_Lock},
    .{OSX_VK_NUMPAD_EQUALS, .Numpad_Equals},
    .{OSX_VK_NUMPAD_DIVIDE, .Divide},
    .{OSX_VK_NUMPAD_MULT, .Multiply},
    .{OSX_VK_NUMPAD_7, .Numpad7},
    .{OSX_VK_NUMPAD_8, .Numpad8},
    .{OSX_VK_NUMPAD_9, .Numpad9},
    .{OSX_VK_NUMPAD_MINUS, .Subtract},
    .{OSX_VK_NUMPAD_4, .Numpad4},
    .{OSX_VK_NUMPAD_5, .Numpad5},
    .{OSX_VK_NUMPAD_6, .Numpad6},
    .{OSX_VK_NUMPAD_PLUS, .Add},
    .{OSX_VK_NUMPAD_1, .Numpad1},
    .{OSX_VK_NUMPAD_2, .Numpad2},
    .{OSX_VK_NUMPAD_3, .Numpad3},
    .{OSX_VK_NUMPAD_ENTER, .Separator},
    .{OSX_VK_NUMPAD_0, .Numpad0},
    .{OSX_VK_NUMPAD_PERIOD, .Decimal},
];

OSX_VK_ESCAPE        :: 53;
OSX_VK_F1            :: 122;
OSX_VK_F2            :: 120;
OSX_VK_F3            :: 99;
OSX_VK_F4            :: 118;
OSX_VK_F5            :: 96;
OSX_VK_F6            :: 97;
OSX_VK_F7            :: 98;
OSX_VK_F8            :: 100;
OSX_VK_F9            :: 101;
OSX_VK_F10           :: 109;
OSX_VK_F11           :: 103;
OSX_VK_F12           :: 111;
OSX_VK_F13           :: 105;
OSX_VK_F14           :: 107;
OSX_VK_F15           :: 113;
OSX_VK_BACK_TICK     :: 50;
OSX_VK_1             :: 18;
OSX_VK_2             :: 19;
OSX_VK_3             :: 20;
OSX_VK_4             :: 21;
OSX_VK_5             :: 23;
OSX_VK_6             :: 22;
OSX_VK_7             :: 26;
OSX_VK_8             :: 28;
OSX_VK_9             :: 25;
OSX_VK_0             :: 29;
OSX_VK_DASH          :: 27;
OSX_VK_EQUAL         :: 24;
OSX_VK_BACKSPACE     :: 51;
OSX_VK_TAB           :: 48;
OSX_VK_Q             :: 12;
OSX_VK_W             :: 13;
OSX_VK_E             :: 14;
OSX_VK_R             :: 15;
OSX_VK_T             :: 17;
OSX_VK_Y             :: 16;
OSX_VK_U             :: 32;
OSX_VK_I             :: 34;
OSX_VK_O             :: 31;
OSX_VK_P             :: 35;
OSX_VK_LBRACKET      :: 33;
OSX_VK_RBRACKET      :: 30;
OSX_VK_BACKSLASH     :: 42;
OSX_VK_CAPS_LOCK     :: 57;
OSX_VK_A             :: 0;
OSX_VK_S             :: 1;
OSX_VK_D             :: 2;
OSX_VK_F             :: 3;
OSX_VK_G             :: 5;
OSX_VK_H             :: 4;
OSX_VK_J             :: 38;
OSX_VK_K             :: 40;
OSX_VK_L             :: 37;
OSX_VK_COLON         :: 41;
OSX_VK_QUOTE         :: 39;
OSX_VK_RETURN        :: 36;
OSX_VK_SHIFT         :: 56;
OSX_VK_Z             :: 6;
OSX_VK_X             :: 7;
OSX_VK_C             :: 8;
OSX_VK_V             :: 9;
OSX_VK_B             :: 11;
OSX_VK_N             :: 45;
OSX_VK_M             :: 46;
OSX_VK_COMMA         :: 43;
OSX_VK_PERIOD        :: 47;
OSX_VK_FWD_SLASH     :: 44;
OSX_VK_CONTROL       :: 59;
OSX_VK_OPTION        :: 58;
OSX_VK_COMMAND       :: 55;
OSX_VK_RIGHT_SHIFT   :: 60;
OSX_VK_RIGHT_COMMAND :: 54;
OSX_VK_RIGHT_OPTION  :: 61;
OSX_VK_RIGHT_CONTROL :: 62;
OSX_VK_SPACEBAR      :: 49;
OSX_VK_INSERT        :: 114;
OSX_VK_HOME          :: 115;
OSX_VK_PAGE_UP       :: 116;
OSX_VK_DELETE        :: 117;
OSX_VK_END           :: 119;
OSX_VK_PAGE_DOWN     :: 121;
OSX_VK_UP            :: 126;
OSX_VK_DOWN          :: 125;
OSX_VK_RIGHT         :: 124;
OSX_VK_LEFT          :: 123;
OSX_VK_NUMLOCK       :: 71;
OSX_VK_NUMPAD_EQUALS :: 81;
OSX_VK_NUMPAD_DIVIDE :: 75;
OSX_VK_NUMPAD_MULT   :: 67;
OSX_VK_NUMPAD_7      :: 89;
OSX_VK_NUMPAD_8      :: 91;
OSX_VK_NUMPAD_9      :: 92;
OSX_VK_NUMPAD_MINUS  :: 78;
OSX_VK_NUMPAD_4      :: 86;
OSX_VK_NUMPAD_5      :: 87;
OSX_VK_NUMPAD_6      :: 88;
OSX_VK_NUMPAD_PLUS   :: 69;
OSX_VK_NUMPAD_1      :: 83;
OSX_VK_NUMPAD_2      :: 84;
OSX_VK_NUMPAD_3      :: 85;
OSX_VK_NUMPAD_ENTER  :: 76;
OSX_VK_NUMPAD_0      :: 82;
OSX_VK_NUMPAD_PERIOD :: 65;
