// @Todo: rename numpad keys

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

Window :: struct {}

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

// @Todo: make a function that checks if we define all of these below
// to ensure the API is correctly implemented on all platforms
// We probably want to add a note on each procedure that is platform
// specific, and the set of all procedures that don't have the note
// must match *exactly* the set of procedures below
// Same for structs (or API structs should be defined here, and we should
// make them opaque if they have platform specific fields)
/*
GetDisplays :: () -> []DisplayInfo #must;

ShowErrorBox :: (parent : *Window, fmt_str : string, args : ..Any);
ShowErrorBox :: (fmt_str : string, args : ..Any);

CreateWindow :: (title : string, width : s32, height : s32, x : s32, y : s32, flags : WindowFlags = 0, parent : *Window = null) -> *Window;
DestroyWindow :: (window : *Window) #no_context;
PollMessages :: () -> []Message;

GetPlatformHandle :: (window : *Window) -> WindowPlatformHandle #must #no_context;
SetWindowTitle :: (window : *Window, title : string);
GetWindowTitle :: (window : *Window) -> string #must;
GetWindowScaleFactor :: (window : *Window) -> float #must;
GetWindowPosition :: (window : *Window) -> x : s32, y : s32;
SetWindowPosition :: (window : *Window, x : s32, y : s32);
GetWindowSize :: (window : *Window) -> w : s32, h : s32;
SetWindowSize :: (window : *Window, w : s32, h : s32);
GetViewportPosition :: (window : *Window) -> x : s32, y : s32;
SetViewportPosition :: (window : *Window, x : s32, y : s32);
GetViewportSizeInPixels :: (window : *Window) -> w : s32, h : s32;
GetViewportSize :: (window : *Window) -> w : s32, h : s32;
SetViewportSize :: (window : *Window, w : s32, h : s32);
GetFocusedWindow :: () -> *Window, non_fenetres_window : bool;
SetFocusedWindow :: (window : *Window);
IsFocused :: (window : *Window) -> bool #must;
IsMaximized :: (window : *Window) -> bool #must;
Maximize :: (window : *Window);
IsMinimized :: (window : *Window) -> bool #must;
Minimize :: (window : *Window);
Restore :: (window : *Window);
CloseWindow :: (window : *Window) #no_context;
ShowWindow :: (window : *Window) #no_context;
HideWindow :: (window : *Window) #no_context;
FocusWindow :: (window : *Window) #no_context;
ScreenToWindow :: (window : *Window, x : s32, y : s32) -> x : s32, y : s32;
WindowToScreen :: (window : *Window, x : s32, y : s32) -> x : s32, y : s32;

GetKeyModState :: () -> KeyMods;
GetKeyState :: (key : KeyCode) -> KeyState;
GetMouseButtonState :: (button : MouseButton) -> KeyState;
GetMousePosition :: () -> x : s32, y : s32;
SetMousePosition :: (x : s32, y : s32);
GetMousePosition :: (window : *Window, ) -> x : s32, y : s32;
SetMousePosition :: (window : *Window, x : s32, y : s32);

SetCursor :: (window : *Window, cursor : SystemCursor);
SetCursorConstraint :: (x : s32, y : s32, w : s32, h : s32) -> bool;
RemoveCursorConstraint :: ();

GetClipboardTextData :: () -> string;
SetClipboardTextData :: (text : string);
ClearClipboard :: ();
*/
