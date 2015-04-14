/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, core module
 */
module graphics.core;

//import directx.d2d1;
import derelict.sdl2.sdl;
import graphics.raster;
import std.stdio;

/*public class GraphicsCore{
    ID2D1Factory* factory;
    ID2D1HwndRenderTarget* renderTarget;
    this(){
        factory = NULL;
        renderTarget = NULL;
    }

    ~ this(){
        if(factory){
            factory.Release();
        }
        if(renderTarget){
            renderTarget.Release();
        }
    }

    public bool init(HWND windowHandle){
        HRESULT res = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &factory);
        if(res != S_OK){
            return false;
        }

        RECT rect;
        GetClientRect(windowHandle, &rect);

        res = factory.CreateHwndRenderTarget(D2D1::PenderTargetProperties(), D2D1::HwndRenderTargetProperties(windowHandle, D2D1::SizeU(rect.right, rect.bottom)), &renderTarget);
        if(res != S_OK){
            return false;
        }

        return true;
    }

    public void beginDraw(){
        renderTarget.BeginDraw();
    }

    public void endDraw(){
        renderTarget.EndDraw();
    }


}*/

/*
 *Output window, uses SDL to output the graphics on screen.
 */
public class OutputWindow : RefreshListener{
    private SDL_Window* window;
    private IRaster mainRaster;
    private SDL_Texture* sdlTexture;
    private SDL_Renderer* renderer;
    private void* mPixels;
    private int mPitch;

    //Constructor. x , y : resolution of the window
    this(const char* title, ushort x, ushort y){
        SDL_Init(SDL_INIT_VIDEO);
        window = SDL_CreateWindow(title , SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, x, y, SDL_WINDOW_OPENGL);
        if (window == null) {
//                throw new Exception();
        }
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    }
    ~this(){
        SDL_DestroyWindow(window);
        SDL_Quit();

    }
    //Sets main raster.
    public void setMainRaster(IRaster r){
        mainRaster = r;
        sdlTexture = SDL_CreateTextureFromSurface(renderer, mainRaster.getOutput());
    }
    public void init(){
    }
    //Displays the output from the raster when invoked.
    public void refreshFinished(){
//        SDL_BlitSurface(mainRaster.getOutput(), null , screen, null);
        //writeln(0);
        //SDL_LockTexture(sdlTexture, null, &mPixels, &mPitch);
        SDL_UpdateTexture(sdlTexture, null, mainRaster.getOutput().pixels, mainRaster.getOutput().pitch);
        //SDL_UnlockTexture(sdlTexture);
        //sdlTexture = SDL_CreateTextureFromSurface(renderer, mainRaster.getOutput());
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, sdlTexture, null, null);
        SDL_RenderPresent(renderer);

    }
}
