#include <stdio.h>
#include <raylib.h>
#include <rlgl.h>

int main(int argc, char** argv) {
    printf("Hello mug-sdf!\n");

    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(800, 600, "Mug SDF");

    Shader sdf_shader = LoadShader(NULL, "./shader/mug.glsl");

    int aspectRatioLoc = GetShaderLocation(sdf_shader, "aspectRatio");
    int timeLoc = GetShaderLocation(sdf_shader, "time");
    // int fovLoc = GetShaderLocation(sdf_shader, "fov");

    printf("Aspect ratio shader-loc: %d\n", aspectRatioLoc);

    // Currently wanna see how fast it actually runs
    // SetTargetFPS(60);

    // Set default internal texture (1px white) and rectangle to be used for shapes drawing
    Texture2D defaultTexture = {
        .format = RL_PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        .width = 1,
        .height = 1,
        .mipmaps = 0,
        .id = rlGetTextureIdDefault()
    };
    SetShapesTexture(defaultTexture, (Rectangle){ 0.0f, 0.0f, 1.0f, 1.0f });

    while(!WindowShouldClose()) {
        BeginDrawing();
            float aspectRatio = (float)GetRenderWidth() / GetRenderHeight();
            float time = (float)GetTime();
            BeginShaderMode(sdf_shader);
                SetShaderValue(sdf_shader, aspectRatioLoc, &aspectRatio, SHADER_UNIFORM_FLOAT);
                SetShaderValue(sdf_shader, timeLoc, &time, SHADER_UNIFORM_FLOAT);
                DrawRectangle(0, 0, GetRenderWidth(), GetRenderHeight(), WHITE);
            EndShaderMode();
            DrawFPS(20, 20);
        EndDrawing();
    }

    CloseWindow();

    return 0;
}
