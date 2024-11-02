// @Todo: rename numpad keys
// @Todo: rename GetWindowPosition/Size to GetWindowPosition/SizeWithFrame
// and rename GetViewportPosition/Size to GetWindowPosition/Size

Check_API :: false;

#if OS ==
{
case .WINDOWS;
    #load "windows.jai";
case .MACOS;
    #load "macos.jai";
case .LINUX;
    #load "linux_x11.jai";
case;
    #assert false "Unsupported OS";
}

g_all_windows : [..]*Window;

GetWindowFromPlatformHandle :: inline (handle : PlatformHandle) -> *Window #must #no_context
{
    for g_all_windows
    {
        if GetPlatformHandle(it) == handle
            return it;
    }

    return null;
}

DisplayInfo :: struct
{
    is_primary : bool;
    x, y, w, h : s32;
    dpi : s32;
}

Window_Default_Pos  :: -1;
Window_Default_Size :: -1;

WindowFlags :: enum_flags
{
    Hidden;
    Custom_Caption;
    Borderless;
    No_Taskbar_Icon;
    Topmost;
    No_Resize;
}

SystemCursor :: enum
{
    None;
    Arrow;
    Arrow_Busy;
    Busy;
    Cross;
    Hand;
    IBeam;
    Size;
    Size_NWSE;
    Size_NESW;
    Size_Horizontal;
    Size_Vertical;
    Not_Allowed;

    Count;
}

Message :: struct
{
    Kind :: enum
    {
        Invalid;

        Window_Moved;
        Window_Resized;
        Window_Maximized;
        Window_Minimized;
        Window_Closed;
        Window_Shown;
        Window_Hidden;
        Window_Received_Focus;
        Window_Lost_Focus;

        Display_Changed;

        Text_Input;
        Key_Pressed;
        Key_Repeated;
        Key_Released;

        Mouse_Raw_Moved;
        Mouse_Moved;
        Mouse_Wheel;
        Mouse_Button_Pressed;
        Mouse_Button_Repeated;
        Mouse_Button_Released;
        Mouse_Entered_Window;
        Mouse_Left_Window;
    }

    kind : Kind;
    window : *Window;
    window_x, window_y : s32;
    window_w, window_h : s32;
    viewport_w, viewport_h : s32;
    codepoint : u32;
    mods : KeyMods;
    key_code : KeyCode;
    mouse_delta_x, mouse_delta_y : s32;
    mouse_x, mouse_y : s32;
    mouse_wheel_x, mouse_wheel_y : float;
    mouse_button : MouseButton;
}

PrintMessage :: (msg : Message)
{
    #import "Unicode";

    window_title := GetWindowTitle(msg.window ,, temp);
    print("Message %\n", msg.kind);
    print("  Window: '%'\n", window_title);

    if #complete msg.kind ==
    {
    case .Invalid;
    case .Key_Pressed; #through;
    case .Key_Repeated; #through;
    case .Key_Released;
        print("  Key: %\n", msg.key_code);
        print("  Mods: %\n", msg.mods);

    case .Text_Input;
        str_data : [4]u8;
        str := string.{4, str_data.data};
        character_utf32_to_utf8(msg.codepoint, *str);
        print("  Text: '%'\n", str);

    case .Window_Moved;
        print("  Position: % %\n", msg.window_x, msg.window_y);

    case .Window_Resized;
        print("           Size: % %\n", msg.window_w, msg.window_h);
        print("  Viewport Size: % %\n", msg.viewport_w, msg.viewport_h);

    case .Window_Maximized;
    case .Window_Minimized;
    case .Window_Closed;
    case .Window_Shown;
    case .Window_Hidden;
    case .Window_Received_Focus;
    case .Window_Lost_Focus;
    case .Display_Changed;

    case .Mouse_Raw_Moved;
        print("  Delta: % %\n", msg.mouse_delta_x, msg.mouse_delta_y);
    case .Mouse_Moved;
        print("  Position: % %\n", msg.mouse_x, msg.mouse_y);
    case .Mouse_Wheel;
        print("  Wheel: % %\n", msg.mouse_wheel_x, msg.mouse_wheel_y);

    case .Mouse_Button_Pressed;
        print("  Mods: %\n", msg.mods);
        print("  Button: %\n", msg.mouse_button);

    case .Mouse_Button_Repeated;
        print("  Mods: %\n", msg.mods);
        print("  Button: %\n", msg.mouse_button);

    case .Mouse_Button_Released;
        print("  Mods: %\n", msg.mods);
        print("  Button: %\n", msg.mouse_button);

    case .Mouse_Entered_Window;
    case .Mouse_Left_Window;
    }
}

MouseButton :: enum u8
{
    Invalid;
    Left;
    Right;
    Middle;

    Count;
}

KeyMods :: enum_flags u8
{
    Ctrl;
    Shift;
    Alt;
    Cmd;
    Caps_Lock;

    Option :: Alt;
}

KeyCode :: enum u8
{
    Invalid;
    Backspace;
    Tab;
    Clear;
    Return;
    Shift;
    Ctrl;
    Alt;
    Option :: Alt;
    Cmd;
    Left_Shift;
    Right_Shift;
    Left_Ctrl;
    Right_Ctrl;
    Left_Alt;
    Right_Alt;
    Left_Super;
    Right_Super;
    Left_Cmd;
    Right_Cmd;
    Pause;
    Caps_Lock;
    Escape;
    Space;
    Page_Up;
    Page_Down;
    End;
    Home;
    Left;
    Up;
    Right;
    Down;
    Select;
    Print;
    Execute;
    Print_Screen;
    Insert;
    Delete;
    Help;
    Zero;
    One;
    Two;
    Three;
    Four;
    Five;
    Six;
    Seven;
    Eight;
    Nine;
    A; B; C; D; E; F; G; H; I; J; K; L; M;
    N; O; P; Q; R; S; T; U; V; W; X; Y; Z;
    Numpad0;
    Numpad1;
    Numpad2;
    Numpad3;
    Numpad4;
    Numpad5;
    Numpad6;
    Numpad7;
    Numpad8;
    Numpad9;
    Numpad_Equals;
    Scroll_Lock;
    Num_Lock;
    Multiply;
    Add;
    Separator;
    Subtract;
    Decimal;
    Divide;
    F1; F2; F3; F4; F5; F6; F7; F8; F9; F10; F11; F12;

    OEM1;
    Colon     :: OEM1;
    Semicolon :: OEM1;

    OEM_Plus;
    OEM_Comma;
    OEM_Minus;
    OEM_Period;

    OEM2;
    Slash              :: OEM2;
    Interrogation_Mark :: OEM2;

    OEM3;
    Backtick :: OEM3;
    Tilde    :: OEM3;

    OEM4;
    Open_Bracket :: OEM4;
    Open_Square_Bracket :: OEM4;
    Open_Curly_Bracket  :: OEM4;

    OEM5;
    Backslash :: OEM5;
    Pipe      :: OEM5;

    OEM6;
    Close_Bracket :: OEM6;
    Close_Square_Bracket :: OEM6;
    Close_Curly_Bracket  :: OEM6;

    OEM7;
    Quote :: OEM7;

    OEM8;
    OEM102;

    Count;
}

#if Check_API
{
    #run
    {
        #import "Compiler";
        #import "String";

        has_error := false;
        api := type_info(API);
        impl := type_info(APIImpl);
        for api_member : api.members
        {
            overload_name := api_member.name;
            index := find_index_from_right(overload_name, #char "_");
            if index != -1
                overload_name.count = index;

            member_info := (cast(**Type_Info) (api.constant_storage.data + api_member.offset_into_constant_storage)).*;

            for impl_member : impl.members
            {
                for note : impl_member.notes
                {
                    if note == "PlatformSpecific"
                        continue impl_member;
                }

                if impl_member.name == overload_name
                && impl_member.type == member_info
                {
                    //print("Found implementation for %\n", overload_name);
                    continue api_member;
                }
            }

            compiler_report(tprint("API coverage: % :: % is not implemented for this platform", overload_name, get_type(member_info)), mode=.ERROR_CONTINUABLE);
            has_error = true;
        }

        if has_error
            exit(1);
    }
}

// @Todo: make a function that checks if we define all of these below
// to ensure the API is correctly implemented on all platforms
// We probably want to add a note on each procedure that is platform
// specific, and the set of all procedures that don't have the note
// must match *exactly* the set of procedures below
// Same for structs (or API structs should be defined here, and we should
// make them opaque if they have platform specific fields)

// This structure lists all the API functions that should be implemented on each platform
// We then use this structure and compare it to actual implementation structure to ensure
// the API is correctly implemented for all platforms
API :: struct
{

GetDisplays :: #type () -> []DisplayInfo #must;

ShowErrorBox_1 :: #type (parent : *Window, fmt_str : string, args : ..Any);
ShowErrorBox_2 :: #type (fmt_str : string, args : ..Any);

CreateWindow :: #type (title : string, width : s32, height : s32, x : s32, y : s32, flags : WindowFlags = 0, parent : *Window = null, extra : CreateWindowExtraParams = .{}) -> *Window;
DestroyWindow :: #type (window : *Window) #no_context;
PollMessages :: #type () -> []Message;

GetPlatformHandle :: #type (window : *Window) -> PlatformHandle #must #no_context;
SetWindowTitle :: #type (window : *Window, title : string);
GetWindowTitle :: #type (window : *Window) -> string #must;
GetWindowScaleFactor :: #type (window : *Window) -> float #must #no_context;
GetWindowPosition :: #type (window : *Window) -> x : s32, y : s32 #no_context;
SetWindowPosition :: #type (window : *Window, x : s32, y : s32) #no_context;
GetWindowSize :: #type (window : *Window) -> w : s32, h : s32 #no_context;
SetWindowSize :: #type (window : *Window, w : s32, h : s32) #no_context;
GetViewportPosition :: #type (window : *Window) -> x : s32, y : s32 #no_context;
SetViewportPosition :: #type (window : *Window, x : s32, y : s32) #no_context;
GetViewportSizeInPixels :: #type (window : *Window) -> w : s32, h : s32 #no_context;
GetViewportSize :: #type (window : *Window) -> w : s32, h : s32 #no_context;
SetViewportSize :: #type (window : *Window, w : s32, h : s32) #no_context;
GetFocusedWindow :: #type () -> *Window, non_fenetres_window : bool #no_context;
SetFocusedWindow :: #type (window : *Window) #no_context;
IsFocused :: #type (window : *Window) -> bool #must #no_context;
IsMaximized :: #type (window : *Window) -> bool #must #no_context;
Maximize :: #type (window : *Window) #no_context;
IsMinimized :: #type (window : *Window) -> bool #must #no_context;
Minimize :: #type (window : *Window) #no_context;
Restore :: #type (window : *Window) #no_context;
SetWindowVisibility :: #type (window : *Window, visible : bool) #no_context;
ShowAndFocusWindow :: #type (window : *Window) #no_context;
ScreenToWindowPosition :: #type (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context;
WindowToScreenPosition :: #type (window : *Window, x : s32, y : s32) -> x : s32, y : s32 #no_context;

GetKeyModState :: #type () -> KeyMods #no_context;
//GetKeyState :: #type (key : KeyCode) -> KeyState;
//GetMouseButtonState :: #type (button : MouseButton) -> KeyState;
GetMousePosition_1 :: #type () -> x : s32, y : s32 #no_context;
SetMousePosition_1 :: #type (x : s32, y : s32) #no_context;
GetMousePosition_2 :: #type (window : *Window) -> x : s32, y : s32 #no_context;
SetMousePosition_2 :: #type (window : *Window, x : s32, y : s32) #no_context;

SetCursor :: #type (window : *Window, cursor : SystemCursor) #no_context;
SetCursorConstraint :: #type (x : s32, y : s32, w : s32, h : s32) -> bool #no_context;
RemoveCursorConstraint :: #type () -> bool #no_context;

GetClipboardTextData :: #type () -> string;
SetClipboardTextData :: #type (text : string);
ClearClipboard :: #type ();

}
