{**************************************************************************
Copyright (C) 2015-2018 Parallel Realities

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, OR (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

***************************************************************************
The original source and a lot of explanations can be found at:
https://www.parallelrealities.co.uk/tutorials/#Shooter
converted from "C" to "Pascal" by Ulrich 2021
***************************************************************************
*** Drawing the player
*** without memory holes; tested with: fpc -Criot -gl -gh shooter02.pas
***************************************************************************}

PROGRAM Shooter02;
{$mode FPC} {$H+}    { "$H+" necessary for conversion of String to PChar !!; H+ => AnsiString }
{$COPERATORS OFF}
USES SDL3, SDL3_Image, sysutils;

CONST SCREEN_WIDTH  = 1280;            { size of the grafic window }
      SCREEN_HEIGHT = 720;             { size of the grafic window }


TYPE TApp    = RECORD                       { "T" short for "TYPE" }
                 Window   : PSDL_Window;
                 Renderer : PSDL_Renderer;
               end;
     TEntity = RECORD
                 x, y : integer;
                 Texture : PSDL_Texture;
               end;

VAR app      : TApp;
    player   : TEntity;
    Event    : TSDL_EVENT;
    exitLoop : BOOLEAN;

// *****************   UTIL   *****************

procedure errorMessage(Message1 : String);
begin
  SDL_ShowSimpleMessageBox(SDL_MessageBOX_ERROR,'Error Box',PChar(Message1),NIL);
  HALT(1);
end;

// *****************   DRAW   *****************

procedure blit(Texture : PSDL_Texture; x, y : integer);
VAR dest : TSDL_FRect;
begin
  dest.x := x;
  dest.y := y;
  //dest.w := 60;
  //dest.h := 60;

  SDL_GetTextureSize(Texture, @dest.w, @dest.h);

  SDL_RenderTexture(app.Renderer, Texture, NIL, @dest);
end;

function loadTexture(Pfad : String) : PSDL_Texture;
VAR Fmt : PChar;
begin
  loadTexture := IMG_LoadTexture(app.Renderer, PChar(Pfad));
  if loadTexture = NIL then errorMessage(SDL_GetError());
  Fmt := 'Loading %s'#13;
  SDL_LogMessage(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_INFO,  Fmt, PChar(Pfad));
end;

procedure prepareScene;
begin
  SDL_SetRenderDrawColor(app.Renderer, 96, 128, 255, 255);
  SDL_RenderClear(app.Renderer);
end;

procedure presentScene;
begin
  SDL_RenderPresent(app.Renderer);
end;

// ***************   INIT SDL   ***************

procedure initSDL;
begin
  if NOT SDL_Init(SDL_INIT_VIDEO) then
  begin
    writeln('Couldn''t initialize SDL');
    HALT(1);
  end;

  app.Window := SDL_CreateWindow('Shooter 02', SCREEN_WIDTH, SCREEN_HEIGHT, 0);
  if app.Window = NIL then
  begin
    writeln('Failed to open ',SCREEN_WIDTH,' x ',SCREEN_HEIGHT,' window');
    HALT(1);
  end;

  app.Renderer := SDL_CreateRenderer(app.Window, nil);
  if app.Renderer = NIL then
  begin
    writeln('Failed to create renderer');
    HALT(1);
  end;
end;

procedure AtExit;
begin
  //SDL_DestroyTexture (player.Texture);
  SDL_DestroyRenderer(app.Renderer);
  SDL_DestroyWindow  (app.Window);
  SDL_Quit;
  if Exitcode <> 0 then WriteLn(SDL_GetError());
end;

// *****************   Input  *****************

procedure doInput;
begin
  while SDL_PollEvent(@Event) do
  begin
    CASE Event._Type of
      SDL_EVENT_QUIT:              exitLoop := TRUE;        { close Window }
      SDL_EVENT_MOUSE_BUTTON_DOWN: exitloop := TRUE;
    end;  { CASE Event }
  end;    { SDL_PollEvent }
end;

// *****************   MAIN   *****************

begin
  InitSDL;
  AddExitProc(@AtExit);
  exitLoop := FALSE;
  player.Texture := loadTexture('gfx/player.png');
  player.x := 300;
  player.y := 300;

  while exitLoop = FALSE do
  begin
    prepareScene;
    doInput;
    blit(player.Texture, player.x, player.y);
    presentScene;
    SDL_Delay(16);
  end;

  AtExit;
end.
