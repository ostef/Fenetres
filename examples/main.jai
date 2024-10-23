Fenetres :: #import "Fenetres";
Fenetres_GL :: #import "Fenetres/GL";

#import "Basic";
#import "GL";

main :: ()
{
    displays := Fenetres.GetDisplays();
    if displays.count == 0
        print("No displays\n");

    for displays
    {
        print("Display %: is_primary=%, bounds=% % % %, dpi=%\n",
            it_index, it.is_primary, it.x, it.y, it.w, it.h, it.dpi);
    }

    if !Fenetres_GL.LoadGL()
    {
        log_error("Could not load GL");
        exit(1);
    }

    window := Fenetres.CreateWindow("My Cube Goes BOING BOING", 1280, 720);
    defer Fenetres.DestroyWindow(window);
    WindowTests(window);

    gl_context := Fenetres_GL.CreateContext(window);
    defer Fenetres_GL.DestroyContext(gl_context);

    Fenetres_GL.MakeCurrent(window, gl_context);

    assert(Fenetres_GL.GetCurrentWindow() == window);
    assert(Fenetres_GL.GetCurrentContext() == gl_context);

    major, minor := gl_get_version();
    print("GL version: %.%\n", major, minor);

    InitGraphics();

    quit := false;
    delta_time : float64 = 1 / 60.0;
    while !quit
    {
        frame_start := seconds_since_init();

        for Fenetres.PollMessages()
        {
            // if it.kind != .Mouse_Moved && it.kind != .Mouse_Raw_Moved
            //     Fenetres.PrintMessage(it);
            if it.kind == .Key_Pressed
            {
                if it.key_code == .Space
                {
                    if it.mods == .Shift
                    {
                        Fenetres.Minimize(window);
                        Fenetres.Restore(window);
                    }
                    else
                    {
                        Fenetres.Maximize(window);
                    }
                }
            }

            if it.kind == .Window_Closed
                quit = true;
        }

        w, h := Fenetres.GetViewportSize(window);
        time := cast(float) seconds_since_init();

        glClearColor(0.1, 0.3, 0.8, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glFrontFace(GL_CW);

        view_projection := make_projection_matrix(60 * PI / 180.0, w / cast(float) h, 0.1, 100)
            * make_look_at_matrix(.{0,0,-5}, .{0,0,0}, .{0,1,0}, false);

        rotation : Quaternion;
        set_from_axis_and_angle(*rotation, 0, 1, 0, time);
        transform := make_translation_matrix4(.{0, cos(time * 1.5), 0})
            * rotation_matrix(Matrix4, rotation);

        glUseProgram(g_shader);
        glUniformMatrix4fv(
            glGetUniformLocation(g_shader, "u_view_projection"),
            1, GL_TRUE,
            cast(*float) *view_projection
        );
        glUniformMatrix4fv(
            glGetUniformLocation(g_shader, "u_transform"),
            1, GL_TRUE,
            cast(*float) *transform
        );
        glDrawArrays(GL_TRIANGLES, 0, 6 * 6);

        Fenetres_GL.SwapBuffers(window);

        frame_end := seconds_since_init();
        delta_time = frame_end - frame_start;
    }
}

WindowTests :: (window : *Fenetres.Window)
{
    // assert(Fenetres.GetFocusedWindow() == window);

    print("%\n", Fenetres.GetWindowTitle(window));

    x, y := Fenetres.GetWindowPosition(window);
    w, h := Fenetres.GetWindowSize(window);
    print("% % % %\n", x, y, w, h);

    x, y = Fenetres.GetViewportPosition(window);
    w, h = Fenetres.GetViewportSize(window);
    px_w, px_h := Fenetres.GetViewportSizeInPixels(window);
    print("% % % % % %\n", x, y, w, h, px_w, px_h);

    Fenetres.SetWindowPosition(window, 100, 100);
    x, y = Fenetres.GetWindowPosition(window);
    assert(x == 100 && y == 100, "% %", x, y);

    Fenetres.SetWindowSize(window, 200, 200);
    w, h = Fenetres.GetWindowSize(window);
    assert(x == 100 && y == 100, "% %", x, y);
    assert(w == 200 && h == 200, "% %", w, h);

    Fenetres.SetViewportPosition(window, 100, 100);
    x, y = Fenetres.GetViewportPosition(window);
    assert(x == 100 && y == 100, "% %", x, y);

    Fenetres.SetViewportSize(window, 1280, 720);
    w, h = Fenetres.GetViewportSize(window);
    assert(x == 100 && y == 100, "% %", x, y);
    assert(w == 1280 && h == 720, "% %", w, h);
}

g_cube_vao, g_cube_vbo : GLuint;
g_shader : GLuint;

InitGraphics :: ()
{
    #import "Math";

    Vertex :: struct
    {
        position : Vector3;
        normal : Vector3;
    }

    Vertices :: Vertex.[
        .{.{-0.5, -0.5, -0.5}, .{0,0,-1}},
        .{.{ 0.5,  0.5, -0.5}, .{0,0,-1}},
        .{.{-0.5,  0.5, -0.5}, .{0,0,-1}},

        .{.{-0.5, -0.5, -0.5}, .{0,0,-1}},
        .{.{ 0.5, -0.5, -0.5}, .{0,0,-1}},
        .{.{ 0.5,  0.5, -0.5}, .{0,0,-1}},

        .{.{ 0.5, -0.5, -0.5}, .{1,0,0}},
        .{.{ 0.5,  0.5,  0.5}, .{1,0,0}},
        .{.{ 0.5,  0.5, -0.5}, .{1,0,0}},

        .{.{ 0.5, -0.5, -0.5}, .{1,0,0}},
        .{.{ 0.5, -0.5,  0.5}, .{1,0,0}},
        .{.{ 0.5,  0.5,  0.5}, .{1,0,0}},

        .{.{ 0.5, -0.5, 0.5}, .{0,0,1}},
        .{.{-0.5,  0.5, 0.5}, .{0,0,1}},
        .{.{ 0.5,  0.5, 0.5}, .{0,0,1}},

        .{.{ 0.5, -0.5, 0.5}, .{0,0,1}},
        .{.{-0.5, -0.5, 0.5}, .{0,0,1}},
        .{.{-0.5,  0.5, 0.5}, .{0,0,1}},

        .{.{-0.5, -0.5,  0.5}, .{-1,0,0}},
        .{.{-0.5,  0.5, -0.5}, .{-1,0,0}},
        .{.{-0.5,  0.5,  0.5}, .{-1,0,0}},

        .{.{-0.5, -0.5,  0.5}, .{-1,0,0}},
        .{.{-0.5, -0.5, -0.5}, .{-1,0,0}},
        .{.{-0.5,  0.5, -0.5}, .{-1,0,0}},

        .{.{-0.5, 0.5, -0.5}, .{0,1,0}},
        .{.{ 0.5, 0.5,  0.5}, .{0,1,0}},
        .{.{-0.5, 0.5,  0.5}, .{0,1,0}},

        .{.{-0.5, 0.5, -0.5}, .{0,1,0}},
        .{.{ 0.5, 0.5, -0.5}, .{0,1,0}},
        .{.{ 0.5, 0.5,  0.5}, .{0,1,0}},

        .{.{ 0.5, -0.5,  0.5}, .{0,-1,0}},
        .{.{-0.5, -0.5, -0.5}, .{0,-1,0}},
        .{.{-0.5, -0.5,  0.5}, .{0,-1,0}},

        .{.{ 0.5, -0.5,  0.5}, .{0,-1,0}},
        .{.{ 0.5, -0.5, -0.5}, .{0,-1,0}},
        .{.{-0.5, -0.5, -0.5}, .{0,-1,0}},
    ];

    glGenVertexArrays(1, *g_cube_vao);
    glGenBuffers(1, *g_cube_vbo);

    glBindBuffer(GL_ARRAY_BUFFER, g_cube_vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(Vertices)), Vertices.data, GL_STATIC_DRAW);

    glBindVertexArray(g_cube_vao);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void) size_of(Vector3));

    status, log_len : s32;

    vertex_shader := glCreateShader(GL_VERTEX_SHADER);
    defer glDeleteShader(vertex_shader);

    vertex_source := Vertex_Shader.data;
    vertex_len : s32 = Vertex_Shader.count;
    glShaderSource(vertex_shader, 1, *vertex_source, *vertex_len);
    glCompileShader(vertex_shader);

    glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, *status);
    glGetShaderiv(vertex_shader, GL_INFO_LOG_LENGTH, *log_len);

    if !status
    {
        if log_len > 1
        {
            buffer := alloc(log_len + 1);
            glGetShaderInfoLog(vertex_shader, xx log_len, null, buffer);
            log_error("Could not compile vertex shader: %", string.{log_len, buffer});
        }
        else
        {
            log_error("Could not compile vertex shader");
        }

        exit(1);
    }

    fragment_shader := glCreateShader(GL_FRAGMENT_SHADER);
    defer glDeleteShader(fragment_shader);

    fragment_source := Fragment_Shader.data;
    fragment_len : s32 = Fragment_Shader.count;
    glShaderSource(fragment_shader, 1, *fragment_source, *fragment_len);
    glCompileShader(fragment_shader);

    glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, *status);
    glGetShaderiv(fragment_shader, GL_INFO_LOG_LENGTH, *log_len);

    if !status
    {
        if log_len > 1
        {
            buffer := alloc(log_len + 1);
            glGetShaderInfoLog(fragment_shader, xx log_len, null, buffer);
            log_error("Could not compile fragment shader: %", string.{log_len, buffer});
        }
        else
        {
            log_error("Could not compile fragment shader");
        }

        exit(1);
    }

    g_shader = glCreateProgram();
    glAttachShader(g_shader, vertex_shader);
    glAttachShader(g_shader, fragment_shader);
    glLinkProgram(g_shader);

    glGetProgramiv(g_shader, GL_LINK_STATUS, *status);
    glGetProgramiv(g_shader, GL_INFO_LOG_LENGTH, *log_len);

    if !status
    {
        if log_len > 1
        {
            buffer := alloc(log_len + 1);
            glGetProgramInfoLog(g_shader, xx log_len, null, buffer);
            log_error("Could not compile shader: %", string.{log_len, buffer});
        }
        else
        {
            log_error("Could not compile shader");
        }

        exit(1);
    }
}

Vertex_Shader :: #string GLSL
#version 330 core

layout(location = 0) in vec3 v_position;
layout(location = 1) in vec3 v_normal;

uniform mat4 u_view_projection;
uniform mat4 u_transform;

out vec3 position;
out vec3 normal;

void main()
{
    normal = (u_transform * vec4(v_normal, 0)).xyz;
    position = (u_transform * vec4(v_position, 1)).xyz;

    gl_Position = u_view_projection * vec4(position, 1);
}
GLSL

Fragment_Shader :: #string GLSL
#version 330 core

in vec3 position;
in vec3 normal;

out vec4 frag_color;

void main()
{
    const vec3 Color = vec3(1, 1, 1);
    const vec3 Light_Position = vec3(1, 1, -10);

    vec3 L = normalize(Light_Position - position);
    float intensity = max(dot(L, normal), 0.1);

    frag_color = vec4(Color * intensity, 1);
}
GLSL
