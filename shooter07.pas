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
*** Shooting enemies
*** without memory holes; tested with: fpc -Criot -gl -gh shooter07.pas
***************************************************************************}

PROGRAM Shooter07;
{$mode FPC} {$H+}    { "$H+" necessary for conversion of String to PChar !!; H+ => AnsiString }
{$COPERATORS OFF}
USES SDL3, SDL3_Image, Math;

CONST SCREEN_WIDTH  = 1280;            { size of the grafic window }
      SCREEN_HEIGHT = 720;             { size of the grafic window }
      PLAYER_SPEED  = 4;
      PLAYER_BULLET_SPEED = 20.0;
      RAND_MAX = 3276;
      MAX_KEYBOARD_KEYS = 350;
      SIDE_PLAYER = 0;
      SIDE_ALIEN = 1;
      FPS = 60;

TYPE TDelegating    = Procedure;            { "T" short for "TYPE" }
     TDelegate      = RECORD
                        logic, draw : TDelegating;
                      end;
     TApp           = RECORD
                        Window   : PSDL_Window;
                        Renderer : PSDL_Renderer;
                        keyboard : ARRAY[0..MAX_KEYBOARD_KEYS] OF integer;
                        delegate : TDelegate;
                      end;
     PEntity        = ^TEntity;
     TEntity        = RECORD
                        x, y, w, h, dx, dy : double;
                        health, reload, side : integer;
                        Texture : PSDL_Texture;
                        next : PEntity;
                      end;
     TStage         = RECORD
                        fighterHead, fighterTail,
                        bulletHead, bulletTail : PEntity;
                      end;

VAR app             : TApp;
    stage           : TStage;
    player,
    enemy,
    bullet          : PEntity;
    CachePlayerTex,
    CacheEnemyTex,
    CacheBulletTex  : PSDL_Texture;
    Event           : TSDL_EVENT;
    exitLoop        : BOOLEAN;
    gTicks          : UInt32;
    gRemainder      : double;
    enemyspawnTimer : integer;

// *****************   INIT   *****************

procedure initEntity(e : PEntity);
begin
  e^.x := 0.0; e^.y := 0.0; e^.dx := 0.0;   e^.dy := 0.0;   e^.Texture := NIL; e^.side := 0;
  e^.w := 0.0; e^.h := 0.0; e^.health := 0; e^.reload := 0; e^.next := NIL;
end;

// *****************   UTIL   *****************

function collision(x1, y1, w1, h1, x2, y2, w2, h2 : double) : Boolean;
begin
  collision := (MAX(x1, x2) < MIN(x1 + w1, x2 + w2)) AND (MAX(y1, y2) < MIN(y1 + h1, y2 + h2));
end;

procedure errorMessage(Message1 : String);
begin
  SDL_ShowSimpleMessageBox(SDL_MessageBOX_ERROR,'Error Box',PChar(Message1),NIL);
  HALT(1);
end;

// *****************   DRAW   *****************

procedure blit(Texture : PSDL_Texture; x, y : double);
VAR dest : TSDL_FRect;
begin
  dest.x := x;
  dest.y := y;
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
  SDL_SetRenderDrawColor(app.Renderer, 32, 32, 32, 255);
  SDL_RenderClear(app.Renderer);
end;

procedure presentScene;
begin
  SDL_RenderPresent(app.Renderer);
end;

// *****************   Stage  *****************

procedure drawBullets;
VAR b : PEntity;
begin
  b := stage.bulletHead^.next;
  while (b <> NIL) do
  begin
    blit(b^.Texture, b^.x, b^.y);
    b := b^.next;
  end;
end;

procedure drawFighters;
VAR e : PEntity;
begin
  e := stage.fighterHead^.next;
  while (e <> NIL) do
  begin
    blit(e^.Texture, e^.x, e^.y);
    e := e^.next;
  end;
end;

procedure draw_Game;
begin
  drawFighters;
  drawBullets;
end;

procedure spawnEnemies;
VAR dest : TSDL_FRect;
begin
  DEC(enemyspawnTimer);
  if enemyspawnTimer <= 0 then
  begin
    NEW(enemy);
    initEntity(enemy);
    stage.fighterTail^.next := enemy;
    stage.fighterTail := enemy;
    enemy^.Texture := CacheEnemyTex;
    SDL_GetTextureSize(enemy^.Texture, @dest.w, @dest.h);
    enemy^.w := dest.w;
    enemy^.h := dest.h;
    enemy^.x := SCREEN_WIDTH;
    enemy^.y := RANDOM(SCREEN_HEIGHT - TRUNC(enemy^.h));
    enemy^.dx := -1 * (2 + (RANDOM(RAND_MAX) MOD 4));
    enemy^.side := SIDE_ALIEN;
    enemy^.health := 1;
    enemyspawnTimer := 30 + (RANDOM(RAND_MAX) MOD FPS);
  end;
end;

function bulletHitFighter(b : PEntity) : BOOLEAN;    { b = Bullet; f = Fighter }
VAR f : PEntity;
begin
  f := stage.fighterHead^.next;
  bulletHitFighter := FALSE;
  while (f <> NIL) do
  begin
    if (f^.side <> b^.side) then
    begin
      if (collision(b^.x, b^.y, b^.w, b^.h, f^.x, f^.y, f^.w, f^.h) = TRUE) then
      begin
        b^.health := 0;
        f^.health := 0;
        bulletHitFighter := TRUE;
      end;
    end;
    f := f^.next;
  end;
end;

procedure doBullets;
VAR b, prev : PEntity;
begin
  prev := stage.bulletHead;
  b := stage.bulletHead^.next;
  while (b <> NIL) do
  begin
    b^.x := b^.x + b^.dx;
    b^.y := b^.y + b^.dy;
    if ((bulletHitFighter(b) = TRUE) OR (b^.x > SCREEN_WIDTH)) then
    begin
      if (b = stage.bulletTail) then
        stage.bulletTail := prev;
      prev^.next := b^.next;
      DISPOSE(b);
      b := prev;
    end;
    prev := b;
    b := b^.next;
  end;
end;

procedure doFighters;
VAR e, prev : PEntity;
begin
  prev := stage.fighterHead;
  e := stage.fighterHead^.next;
  while (e <> NIL) do
  begin
    e^.x := e^.x + e^.dx;
    e^.y := e^.y + e^.dy;
    if ((e <> player) AND ((e^.x < -e^.w) OR (e^.health = 0))) then
    begin
      if (e = stage.fighterTail) then
        stage.fighterTail := prev;
      prev^.next := e^.next;
      DISPOSE(e);
      e := prev;
    end;
    prev := e;
    e := e^.next;
  end;
end;

procedure fireBullet;
VAR dest : TSDL_FRect;
begin
  NEW(bullet);
  initEntity(bullet);
  stage.bulletTail^.next := bullet;
  stage.bulletTail := bullet;
  bullet^.x := player^.x;
  bullet^.y := player^.y;
  bullet^.dx := PLAYER_BULLET_SPEED;
  bullet^.health := 1;
  bullet^.Texture := CacheBulletTex;
  SDL_GetTextureSize(bullet^.Texture, @dest.w, @dest.h);
  bullet^.w := dest.w;
  bullet^.h := dest.h;
  bullet^.x := bullet^.x + (player^.w / 2);
  bullet^.y := bullet^.y + (player^.h / 2) - (bullet^.h / 2);
  bullet^.side := SIDE_PLAYER;
  player^.reload := 8;
end;

procedure doPlayer;
begin
  player^.dx := 0;
  player^.dy := 0;
  if (player^.reload > 0) then DEC(player^.reload);
  if (app.keyboard[SDL_ScanCode_UP]    OR app.keyboard[SDL_ScanCode_KP_8]) = 1 then player^.dy := (-1 * PLAYER_SPEED);
  if (app.keyboard[SDL_ScanCode_DOWN]  OR app.keyboard[SDL_ScanCode_KP_2]) = 1 then player^.dy :=       PLAYER_SPEED;
  if (app.keyboard[SDL_ScanCode_LEFT]  OR app.keyboard[SDL_ScanCode_KP_4]) = 1 then player^.dx := (-1 * PLAYER_SPEED);
  if (app.keyboard[SDL_ScanCode_RIGHT] OR app.keyboard[SDL_ScanCode_KP_6]) = 1 then player^.dx :=       PLAYER_SPEED;
  if ((app.keyboard[SDL_ScanCode_LCTRL] = 1) AND (player^.reload <= 0))        then fireBullet;
end;

procedure initPlayer;
VAR dest : TSDL_FRect;
begin
  NEW(player);
  initEntity(player);
  stage.fighterTail^.next := player;
  stage.fighterTail := player;
  player^.x := 100;
  player^.y := 100;
  player^.Texture := CachePlayerTex;
  SDL_GetTextureSize(player^.Texture, @dest.w, @dest.h);
  player^.w := dest.w;
  player^.h := dest.h;
  player^.side := SIDE_PLAYER;
end;

procedure logic_Game;
begin
  doPlayer;
  doFighters;
  doBullets;
  spawnEnemies;
end;

procedure initStage;
begin
  app.delegate.logic := @logic_Game;
  app.delegate.draw  := @draw_Game;
  NEW(stage.fighterHead);
  NEW(stage.bulletHead);
  initEntity(stage.fighterHead);
  initEntity(stage.bulletHead);
  CacheBulletTex    := loadTexture('gfx/playerBullet.png');
  CacheEnemyTex     := loadTexture('gfx/enemy.png');
  CachePlayerTex    := loadTexture('gfx/player.png');
  stage.fighterTail := stage.fighterHead;
  stage.bulletTail  := stage.bulletHead;
  initPlayer;
  enemyspawnTimer   := 0;
end;

// ***************   INIT SDL   ***************

procedure initSDL;
VAR windowFlags : integer;
begin
  windowFlags := 0;

  if NOT SDL_Init(SDL_INIT_VIDEO) then
    errorMessage(SDL_GetError());

  app.Window := SDL_CreateWindow('Shooter 07', SCREEN_WIDTH, SCREEN_HEIGHT, windowFlags);
  if app.Window = NIL then
    errorMessage(SDL_GetError());

  app.Renderer := SDL_CreateRenderer(app.Window, NIL);
  if app.Renderer = NIL then
    errorMessage(SDL_GetError());

  SDL_HideCursor;
end;

procedure Loesch_Liste(a : PEntity);
VAR t : PEntity;
begin
  while (a <> NIL) do
  begin
    t := a^.next;
    DISPOSE(a);
    a := t;
  end;
end;

procedure cleanUp;
begin
  Loesch_Liste(stage.fighterHead^.next);
  Loesch_Liste(stage.bulletHead^.next);
  DISPOSE(stage.fighterHead);
  DISPOSE(stage.bulletHead);
  if ExitCode <> 0 then WriteLn('CleanUp complete!');
end;

procedure AtExit;
begin
  if ExitCode <> 0 then cleanUp;
  SDL_DestroyTexture (CachePlayerTex);
  SDL_DestroyTexture (CacheEnemyTex);
  SDL_DestroyRenderer(app.Renderer);
  SDL_DestroyWindow  (app.Window);
  SDL_QuitSubSystem(SDL_INIT_VIDEO);
  SDL_Quit;
  if Exitcode <> 0 then WriteLn(SDL_GetError());
  SDL_ShowCursor;
end;

// *****************   Input  *****************

procedure doInput;
begin
  while SDL_PollEvent(@Event) do
  begin
    CASE Event._Type of

      SDL_EVENT_QUIT:              exitLoop := TRUE;        { close Window }
      SDL_EVENT_MOUSE_BUTTON_DOWN: exitLoop := TRUE;        { if Mousebutton pressed }

      SDL_EVENT_KEY_DOWN: begin
                            if (Event.key.scancode < MAX_KEYBOARD_KEYS) then
                              app.keyboard[Event.key.scancode] := 1;
                            if (app.keyboard[SDL_ScanCode_ESCAPE]) = 1 then exitLoop := TRUE;
                          end;   { SDL_Keydown }

      SDL_EVENT_KEY_UP:   begin
                            if (Event.key.scancode < MAX_KEYBOARD_KEYS) then
                              app.keyboard[Event.key.scancode] := 0;
                          end;   { SDL_Keyup }
    end;  { CASE Event }
  end;    { SDL_PollEvent }
end;

// *************   CAPFRAMERATE   *************

procedure CapFrameRate(VAR remainder : double; VAR Ticks : UInt32);
VAR wait, FrameTime : longInt;
begin
  wait := 16 + TRUNC(remainder);
  remainder := remainder - TRUNC(remainder);
  frameTime := SDL_GetTicks - Ticks;
  DEC(wait, frameTime);
  if (wait < 1) then wait := 1;
  SDL_Delay(wait);
  remainder := remainder + 0.667;
  Ticks := SDL_GetTicks;
end;

// *****************   MAIN   *****************

begin
  RANDOMIZE;
  InitSDL;
  AddExitProc(@AtExit);
  InitStage;
  exitLoop := FALSE;
  gTicks := SDL_GetTicks;
  gRemainder := 0;

  while exitLoop = FALSE do
  begin
    prepareScene;
    doInput;
    app.delegate.logic;
    app.delegate.draw;
    presentScene;
    CapFrameRate(gRemainder, gTicks);
  end;

  cleanUp;
  AtExit;
end.
