#module_parameters(ENABLE_ALL_EXTENSIONS := false);

#import "Fenetres";
#import "GL" (ENABLE_ALL_EXTENSIONS=ENABLE_ALL_EXTENSIONS);

#if OS ==
{
case .WINDOWS;
    #load "windows.jai";
case .MACOS;
    #load "macos.jai";
case .LINUX;
    #load "linux.jai";
case;
    #assert false "Unsupported OS";
}

LoadGL :: () -> bool
{
    #if OS == .MACOS
    {

    // No need for a window on MacOS
    dummy_ctx := CreateContextWithoutWindow();
    if !dummy_ctx
        return false;

    defer DestroyContext(dummy_ctx);

    }
    else #if OS == .WINDOWS
    {

    dummy_window := CreateWindow("Dummy Window", -1, -1, -1, -1, .Hidden);
    if !dummy_window
        return false;

    defer DestroyWindow(dummy_window);

    dummy_ctx := CreateContext(dummy_window, .Compatibility_Profile);
    if !dummy_ctx
        return false;

    defer DestroyContext(dummy_ctx);

    }

    LoadGLFunctionPointers(*gl);

    // Make sure we also load the function pointers for the instantiation of gl
    // when someone #imports "GL" without any module parameter, which is the most
    // common case of importing the GL module.
    // This is a hack, of course
    #if ENABLE_ALL_EXTENSIONS
    {
        Normal_GL :: #import "GL";
        LoadGLFunctionPointers(*Normal_GL.gl);
    }

    return true;
}

#scope_file

LoadGLFunctionPointers :: (procs : *$T)
{
    // Copy-Pasta from the GL module, which does not load function
    // pointers if gl_get_version returns 0, even though this does
    // not prevent us from loading function pointers on Linux
    Compiler :: #import "Compiler";
    #import "String";

    info_struct := type_info(T);

    dest_bytes := cast(*u8) procs;
    table := Compiler.get_type_table();

    gl_version_major, gl_version_minor = gl_get_version();

    for * info_struct.members {

        if it.flags & .CONSTANT continue;

        is_intentional_void_pointer := (it.flags & .PROCEDURE_WITH_VOID_POINTER_TYPE_INFO) != 0;  // Let us use #type_info_procedures_are_void_pointers.
        if (it.type.type == .PROCEDURE) || is_intentional_void_pointer {
            ptype := cast(*Type_Info_Procedure) it.type;


            if !is_intentional_void_pointer {
                assert ((ptype.procedure_flags & .IS_C_CALL) != 0,
                        "Proc \"%\" is not a #c_call! (member_address %, type_address %, procedure_flags = %, % arguments, % returns, index = %)",
                        it.name, it, ptype, formatInt(ptype.procedure_flags, base=16), ptype.argument_types.count, ptype.return_types.count,
                        array_find(table, it.type));
            }

            // Okay, do the work.
            c_string := it.name.data;  // Strings in Type_Info are guaranteed to be zero-terminated now.  -jblow, 23 December 2018

            address := GetProcAddress(c_string);

            if address {
                dest := cast(**void) (dest_bytes + it.offset_in_bytes);
                    << dest = address;
            }
        } else if it.type.type == .BOOL {
            poke := false;

            if begins_with(it.name, "GL_VERSION_") {
                major, minor := gl_parse_version(it.name);
                poke = gl_version_major > major || (gl_version_major == major && gl_version_minor >= minor);
            } else if begins_with(it.name, "GL_") || begins_with(it.name, "WGL_") || begins_with(it.name, "GLX_") {
                poke = gl_supports_extension(it.name);
            } else {
                assert(false, "Unexpected variable '%' in GL struct.", it.name);
            }

            if poke {
                //log("% found", it.name);
                dest := cast(*bool) (dest_bytes + it.offset_in_bytes);
                    <<dest = true;
            }
        } else {
            if !begins_with(it.name, "gl_version_") {
                builder: String_Builder;
                print_type_to_builder(*builder, it.type);
                type_string := builder_to_string(*builder);
                defer free(type_string);

                assert(false, "Unexpected variable '%' in GL struct. (The type was: %).", it.name, type_string);
            }
        }
    }
}
