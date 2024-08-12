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

            // msg.key_code = CocoaKeyCodeToKeyCode (event.keyCode (event));
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

/*
CocoaKeyCodeToKeyCode :: (cocoa : u16) -> KeyCode #must
{
    #insert -> string
    {
        builder : String_Builder;

        append (*builder, "if cocoa ==\n{\n");
        for VK_To_Key_Code_Map
        {
            print_to_builder (*builder, "case .%; return .%;\n", it.vk, it.key_code);
        }
        append (*builder, "}\n");

        return builder_to_string (*builder);
    };

    return .Invalid;
}

KeyCodeToCocoaKeyCode :: (key_code : KeyCode) -> u16 #must
{
}

VKKeyCodePair :: struct
{
    vk : Win32.VIRTUAL_KEY;
    key_code : KeyCode;
}

VK_To_Key_Code_Map :: VKKeyCodePair.[
    .{ .VK_BACK, .Backspace },
    .{ .VK_TAB, .Tab },
    .{ .VK_CLEAR, .Clear },
    .{ .VK_RETURN, .Return },
    .{ .VK_SHIFT, .Shift },
    .{ .VK_CONTROL, .Ctrl },
    .{ .VK_MENU, .Alt },
    .{ .VK_PAUSE, .Pause },
    .{ .VK_CAPITAL, .Caps_Lock },
    .{ .VK_ESCAPE, .Escape },
    .{ .VK_SPACE, .Space },
    .{ .VK_PRIOR, .Page_Up },
    .{ .VK_NEXT, .Page_Down },
    .{ .VK_END, .End },
    .{ .VK_HOME, .Home },
    .{ .VK_LEFT, .Left },
    .{ .VK_UP, .Up },
    .{ .VK_RIGHT, .Right },
    .{ .VK_DOWN, .Down },
    .{ .VK_SELECT, .Select },
    .{ .VK_PRINT, .Print },
    .{ .VK_EXECUTE, .Execute },
    .{ .VK_SNAPSHOT, .Print_Screen },
    .{ .VK_INSERT, .Insert },
    .{ .VK_DELETE, .Delete },
    .{ .VK_HELP, .Help },
    .{ .VK_0, .Zero },
    .{ .VK_1, .One },
    .{ .VK_2, .Two },
    .{ .VK_3, .Three },
    .{ .VK_4, .Four },
    .{ .VK_5, .Five },
    .{ .VK_6, .Six },
    .{ .VK_7, .Seven },
    .{ .VK_8, .Eight },
    .{ .VK_9, .Nine },
    .{ .VK_A, .A },
    .{ .VK_B, .B },
    .{ .VK_C, .C },
    .{ .VK_D, .D },
    .{ .VK_E, .E },
    .{ .VK_F, .F },
    .{ .VK_G, .G },
    .{ .VK_H, .H },
    .{ .VK_I, .I },
    .{ .VK_J, .J },
    .{ .VK_K, .K },
    .{ .VK_L, .L },
    .{ .VK_M, .M },
    .{ .VK_N, .N },
    .{ .VK_O, .O },
    .{ .VK_P, .P },
    .{ .VK_Q, .Q },
    .{ .VK_R, .R },
    .{ .VK_S, .S },
    .{ .VK_T, .T },
    .{ .VK_U, .U },
    .{ .VK_V, .V },
    .{ .VK_W, .W },
    .{ .VK_X, .X },
    .{ .VK_Y, .Y },
    .{ .VK_Z, .Z },
    .{ .VK_LWIN, .Left_Super },
    .{ .VK_RWIN, .Right_Super },
    .{ .VK_NUMPAD0, .Numpad0 },
    .{ .VK_NUMPAD1, .Numpad1 },
    .{ .VK_NUMPAD2, .Numpad2 },
    .{ .VK_NUMPAD3, .Numpad3 },
    .{ .VK_NUMPAD4, .Numpad4 },
    .{ .VK_NUMPAD5, .Numpad5 },
    .{ .VK_NUMPAD6, .Numpad6 },
    .{ .VK_NUMPAD7, .Numpad7 },
    .{ .VK_NUMPAD8, .Numpad8 },
    .{ .VK_NUMPAD9, .Numpad9 },
    .{ .VK_MULTIPLY, .Multiply },
    .{ .VK_ADD, .Add },
    .{ .VK_SEPARATOR, .Separator },
    .{ .VK_SUBTRACT, .Subtract },
    .{ .VK_DECIMAL, .Decimal },
    .{ .VK_DIVIDE, .Divide },
    .{ .VK_F1, .F1 },
    .{ .VK_F2, .F2 },
    .{ .VK_F3, .F3 },
    .{ .VK_F4, .F4 },
    .{ .VK_F5, .F5 },
    .{ .VK_F6, .F6 },
    .{ .VK_F7, .F7 },
    .{ .VK_F8, .F8 },
    .{ .VK_F9, .F9 },
    .{ .VK_F10, .F10 },
    .{ .VK_F11, .F11 },
    .{ .VK_F12, .F12 },
    .{ .VK_NUMLOCK, .Num_Lock },
    .{ .VK_SCROLL, .Scroll_Lock },
    .{ .VK_LSHIFT, .Left_Shift },
    .{ .VK_RSHIFT, .Right_Shift },
    .{ .VK_LCONTROL, .Left_Ctrl },
    .{ .VK_RCONTROL, .Right_Ctrl },
    .{ .VK_LMENU, .Left_Alt },
    .{ .VK_RMENU, .Right_Alt },
    .{ .VK_OEM_1, .OEM1 },
    .{ .VK_OEM_PLUS, .OEM_Plus },
    .{ .VK_OEM_COMMA, .OEM_Comma },
    .{ .VK_OEM_MINUS, .OEM_Minus },
    .{ .VK_OEM_PERIOD, .OEM_Period },
    .{ .VK_OEM_2, .OEM2 },
    .{ .VK_OEM_3, .OEM3 },
    .{ .VK_OEM_4, .OEM4 },
    .{ .VK_OEM_5, .OEM5 },
    .{ .VK_OEM_6, .OEM6 },
    .{ .VK_OEM_7, .OEM7 },
    .{ .VK_OEM_8, .OEM8 },
    .{ .VK_OEM_102, .OEM102 }
];
*/
