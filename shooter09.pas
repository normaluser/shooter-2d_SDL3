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
*** Effects and Background Grafics
*** without memory holes; tested with: fpc -Criot -gl -gh shooter09.pas
***************************************************************************}

PROGRAM Shooter09;
{$mode FPC} {$H+}    { "$H+" necessary for conversion of String to PChar !!; H+ => AnsiString }
{$COPERATORS OFF}
USES SDL3, SDL3_Image, Math;

CONST SCREEN_WIDTH  = 1280;            { size of the grafic window }
      SCREEN_HEIGHT = 720;             { size of the grafic window }
      PLAYER_SPEED  = 4;
      PLAYER_BULLET_SPEED = 20.0;
      ALIEN_BULLET_SPEED = 8;
      RAND_MAX = 3276;
      MAX_KEYBOARD_KEYS = 350;
      SIDE_PLAYER = 0;
      SIDE_ALIEN = 1;
      FPS = 60;
      MAX_STARS = 500;

TYPE TDelegating = Procedure;               { "T" short for "TYPE" }
     TDelegate   = RECORD
                     logic, draw : TDelegating;
                   end;
     TApp        = RECORD
                     Window   : PSDL_Window;
                     Renderer : PSDL_Renderer;
                     keyboard : ARRAY[0..MAX_KEYBOARD_KEYS] OF integer;
                     delegate : TDelegate;
                   end;
     PEntity     = ^TEntity;
     TEntity     = RECORD
                     x, y, w, h, dx, dy : double;
                     health, reload, side : integer;
                     Texture : PSDL_Texture;
                     next : PEntity;
                   end;
     PExplosion  = ^TExplosion;
     TExplosion  = RECORD
                     x, y, dx, dy : double;
                     r, g, b, a : integer;
                     next : PExplosion;
                   end;
     PDebris     = ^TDebris;
     TDebris     = RECORD
                     x, y, dx, dy : double;
                     rect : TSDL_FRect;
                     Texture : PSDL_Texture;
                     life : integer;
                     next : PDebris;
                   end;
     TStage      = RECORD
                     fighterHead,   fighterTail,
                     bulletHead,    bulletTail    : PEntity;
                     explosionHead, explosionTail : PExplosion;
                     debrisHead,    debrisTail    : PDebris;
                   end;
     TStar       = RECORD
                     x, y, speed : integer;
                   end;

VAR app                  : TApp;
    stage                : TStage;
    player,
    enemy,
    bullet               : PEntity;
    enemyTexture,
    bulletTexture,
    alienbulletTexture,
    playerTexture,
    background,
    explosionTexture     : PSDL_Texture;
    Event                : TSDL_EVENT;
    exitLoop             : BOOLEAN;
    gTicks               : UInt32;
    gRemainder           : double;
    backgroundX,
    enemyspawnTimer,
    resetTimer           : integer;
    stars                : ARRAY[0..MAX_STARS] OF TStar;

// *****************   INIT   *****************

procedure initEntity(e : PEntity);
begin
  e^.x := 0.0; e^.y := 0.0; e^.dx := 0.0;   e^.dy := 0.0;   e^.Texture := NIL; e^.side := 0;
  e^.w := 0.0; e^.h := 0.0; e^.health := 0; e^.reload := 0; e^.next := NIL;
end;

procedure initDebris(e : PDebris);
begin
  e^.x := 0.0;  e^.y := 0.0;  e^.dx := 0.0;  e^.dy := 0.0;
  e^.life := 0; e^.next := NIL; e^.Texture := NIL;
end;

procedure initExplosion(e : PExplosion);
begin
  e^.x := 0.0; e^.y := 0.0; e^.dx := 0.0; e^.dy := 0.0;
  e^.r := 0;   e^.g := 0;   e^.b  := 0;   e^.a  := 0;   e^.next := NIL;
end;

// *****************   UTIL   *****************

function collision(x1, y1, w1, h1, x2, y2, w2, h2 : double) : Boolean;
begin
  collision := (MAX(x1, x2) < MIN(x1 + w1, x2 + w2)) AND (MAX(y1, y2) < MIN(y1 + h1, y2 + h2));
end;

procedure calcSlope(x1, y1, x2, y2 : double; VAR dx, dy : double);
VAR steps : double;
begin
  steps := MAX(ABS(x1-x2), ABS(y1-y2));
  if steps <> 0.0 then
  begin
    dx := (x1 - x2) / steps;
    dy := (y1 - y2) / steps;
  end
  else
  begin
    dx := 0.0;
    dy := 0.0;
  end;
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

procedure blitRect(Texture : PSDL_Texture; src : PSDL_FRect; x, y : double);
VAR dest : TSDL_FRect;
begin
  dest.x := x;
  dest.y := y;
  dest.w := src^.w;
  dest.h := src^.h;
  SDL_RenderTexture(app.Renderer, Texture, src, @dest);
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

// **************   Background  ***************

procedure drawBackground;
VAR dest : TSDL_FRect;
    x : double;
begin
  x := backgroundX;
  while x < SCREEN_WIDTH do
  begin
    dest.x := x;
    dest.y := 0;
    dest.w := SCREEN_WIDTH;
    dest.h := SCREEN_HEIGHT;
    SDL_RenderTexture(app.Renderer, background, NIL, @dest);
    x := x + SCREEN_WIDTH;
  end;
end;

procedure drawStarfield;
VAR i, c : integer;
begin
  for i := 0 to PRED(MAX_STARS) do
  begin
    c := 32 * stars[i].speed;
    if c > 255 then c := 255;
    SDL_SetRenderDrawColor(app.Renderer, c, c, c, 255);
    SDL_RenderLine(app.Renderer, stars[i].x, stars[i].y, stars[i].x + 3, stars[i].y);
  end;
end;

procedure doStarField;
VAR i : integer;
begin
  for i := 0 to PRED(MAX_STARS) do
  begin
    DEC(stars[i].x, stars[i].speed);
    if stars[i].x < 0 then
      INC(stars[i].x, SCREEN_WIDTH);
  end;
end;

procedure doBackGround;
begin
  DEC(backgroundX);
  if backgroundX < (-SCREEN_WIDTH) then
    backgroundX := 0;
end;

procedure initStarfield;
VAR i : integer;
begin
  for i := 0 to PRED(MAX_STARS) do
  begin
    stars[i].x := (RANDOM(RAND_MAX) MOD SCREEN_WIDTH);
    stars[i].y := (RANDOM(RAND_MAX) MOD SCREEN_HEIGHT);
    stars[i].speed := 1 + (RANDOM(RAND_MAX) MOD 8);
  end;
end;

// *****************   Stage  *****************

procedure drawExplosions;
VAR e : PExplosion;
begin
  SDL_SetRenderDrawBlendMode(app.Renderer, SDL_Blendmode_ADD);
  SDL_SetTextureBlendMode(explosionTexture, SDL_Blendmode_ADD);
  e := stage.explosionHead^.next;
  while (e <> NIL) do
  begin
    SDL_SetTextureColorMod(explosionTexture, e^.r, e^.g, e^.b);
    SDL_SetTextureAlphaMod(explosionTexture, e^.a);
    blit(explosionTexture, e^.x, e^.y);
    e := e^.next;
  end;
  SDL_SetRenderDrawBlendMode(app.Renderer, SDL_BLENDMODE_NONE);
end;

procedure drawDebris;
VAR d : PDebris;
begin
  d := stage.debrisHead^.next;
  while (d <> NIL) do
  begin
    blitRect(d^.Texture, @d^.rect, d^.x, d^.y);
    d := d^.next;
  end;
end;

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

procedure addDebris(e : PEntity);
VAR d : PDebris;
    x, y, w, h : double;
begin
  w := e^.w / 2;
  h := e^.h / 2;
  x := 0; y := 0;
  while y <= h do
  begin
    while x <= w do
    begin
      NEW(d);
      initDebris(d);
      stage.debrisTail^.next := d;
      stage.debrisTail := d;
      d^.x := e^.x + (e^.w / 2);
      d^.y := e^.y + (e^.h / 2);
      d^.dx := (RANDOM(RAND_MAX) MOD 5) - (RANDOM(RAND_MAX) MOD 5);
      d^.dy := -1 * (5 + (RANDOM(RAND_MAX) MOD 12));
      d^.life := FPS * 2;
      d^.Texture := e^.Texture;
      d^.rect.x := x;
      d^.rect.y := y;
      d^.rect.w := w;
      d^.rect.h := h;
      x := x + w;
    end;
    x := 0;
    y := y + h;
  end;
end;

procedure addExplosions(x, y: double; num : integer);
VAR e : PExplosion;
    i : integer;
begin
  for i := 0 to PRED(num) do
  begin
    NEW(e);
    initExplosion(e);
    stage.explosionTail^.next := e;
    stage.explosionTail := e;
    e^.x  := x + (RANDOM(RAND_MAX) MOD 32) - (RANDOM(RAND_MAX) MOD 32);
    e^.y  := y + (RANDOM(RAND_MAX) MOD 32) - (RANDOM(RAND_MAX) MOD 32);
    e^.dx :=     (RANDOM(RAND_MAX) MOD 10) - (RANDOM(RAND_MAX) MOD 10);
    e^.dy :=     (RANDOM(RAND_MAX) MOD 10) - (RANDOM(RAND_MAX) MOD 10);
    e^.dx := e^.dx / 10;
    e^.dy := e^.dy / 10;
    CASE (RANDOM(RAND_MAX) MOD 4) of
      0 : begin e^.r := 255; end;
      1 : begin e^.r := 255;
                e^.g := 128; end;
      2 : begin e^.r := 255;
                e^.g := 255; end;
    else  begin e^.r := 255;
                e^.g := 255;
                e^.b := 255; end;
    end;   { end of CASE }
    e^.a := (RANDOM(RAND_MAX) MOD (FPS * 3));
  end;
end;

procedure draw_Game;
begin
  drawBackground;
  drawStarfield;
  drawFighters;
  drawDebris;
  drawExplosions;
  drawBullets;
end;

procedure clipPlayer;
begin
  if player <> NIL then
  begin
    if (player^.x < 0) then player^.x := 0;
    if (player^.y < 0) then player^.y := 0;
    if (player^.x > (SCREEN_WIDTH  - player^.w)) then player^.x := (SCREEN_WIDTH  - player^.w);
    if (player^.y > (SCREEN_HEIGHT - player^.h)) then player^.y := (SCREEN_HEIGHT - player^.h);
  end;
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
    enemy^.Texture := enemyTexture;
    SDL_GetTextureSize(enemy^.Texture, @dest.w, @dest.h);
    enemy^.w := dest.w;
    enemy^.h := dest.h;
    enemy^.x := SCREEN_WIDTH;
    enemy^.y := RANDOM(SCREEN_HEIGHT - TRUNC(enemy^.h));
    enemy^.dx := -1 * (2 + (RANDOM(RAND_MAX) MOD 4));
    enemy^.side := SIDE_ALIEN;
    enemy^.health := 1;
    enemy^.reload := FPS * (1 + (RANDOM(RAND_MAX) MOD 3));
    enemyspawnTimer := 30 + (RANDOM(RAND_MAX) MOD FPS);
  end;
end;

procedure doDebris;
VAR d, prev : PDebris;
begin
  prev := stage.debrisHead;
  d := stage.debrisHead^.next;
  while (d <> NIL) do
  begin
    d^.x := d^.x + d^.dx;
    d^.y := d^.y + d^.dy;
    d^.dy := d^.dy + 0.5;
    DEC(d^.life);
    if (d^.life <= 0) then
    begin
      if (d = stage.debrisTail) then
        stage.debrisTail := prev;
      prev^.next := d^.next;
      DISPOSE(d);
      d := prev;
    end;
    prev := d;
    d := d^.next;
  end;
end;

procedure doExplosions;
VAR e, prev : PExplosion;
begin
  prev := stage.ExplosionHead;
  e := stage.ExplosionHead^.next;
  while (e <> NIL) do
  begin
    e^.x := e^.x + e^.dx;
    e^.y := e^.y + e^.dy;
    DEC(e^.a);
    if (e^.a <= 0) then
    begin
      if (e = stage.ExplosionTail) then
        stage.ExplosionTail := prev;
      prev^.next := e^.next;
      DISPOSE(e);
      e := prev;
    end;
    prev := e;
    e := e^.next;
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
        addExplosions(f^.x, f^.y, 32);
        addDebris(f);
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
    if ((bulletHitFighter(b) = TRUE) OR (b^.x < -b^.w) OR (b^.y < -b^.h) OR
        (b^.x > SCREEN_WIDTH) OR (b^.y > SCREEN_HEIGHT)) then
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
    if ((e <> player) AND (e^.x < -e^.w)) then
      e^.health := 0;
    if (e^.health = 0) then
    begin
      if (e = player) then
        player := NIL;
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

procedure fireAlienbullet(e : PEntity);
VAR dest : TSDL_FRect;
begin
  NEW(bullet);
  initEntity(bullet);
  stage.bulletTail^.next := bullet;
  stage.bulletTail := bullet;
  bullet^.x := e^.x;
  bullet^.y := e^.y;
  bullet^.health := 1;
  bullet^.Texture := alienbulletTexture;
  SDL_GetTextureSize(bullet^.Texture, @dest.w, @dest.h);
  bullet^.w := dest.w;
  bullet^.h := dest.h;
  bullet^.x := bullet^.x + (e^.w / 2) - (bullet^.w / 2);
  bullet^.y := bullet^.y + (e^.h / 2) - (bullet^.h / 2);
  calcSlope((player^.x + (player^.w / 2)), (player^.y + (player^.h / 2)), (e^.x), (e^.y), bullet^.dx, bullet^.dy);
  bullet^.dx := bullet^.dx * ALIEN_BULLET_SPEED;
  bullet^.dy := bullet^.dy * ALIEN_BULLET_SPEED;
  bullet^.side := SIDE_ALIEN;
  e^.reload := RANDOM(FPS * 2);
end;

procedure doEnemies;
VAR e : PEntity;
begin
  e := stage.fighterHead^.next;
  while (e <> NIL) do
  begin
    if ((e <> player) AND (player <> NIL)) then
    begin
      DEC(e^.reload);
      if (e^.reload <= 0) then
        fireAlienbullet(e);
    end;
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
  bullet^.Texture := bulletTexture;
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
  if (player <> NIL) then
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
end;

procedure initPlayer;
VAR dest : TSDL_FRect;
begin
  NEW(player);
  initEntity(player);
  stage.fighterTail^.next := player;
  stage.fighterTail := player;
  player^.health := 1;
  player^.x := 100;
  player^.y := 100;
  player^.Texture := playerTexture;
  SDL_GetTextureSize(player^.Texture, @dest.w, @dest.h);
  player^.w := dest.w;
  player^.h := dest.h;
  player^.reload := 0;
  player^.side := SIDE_PLAYER;
end;

procedure resetStage;
VAR e, t : PEntity;
begin
  e := stage.fighterHead^.next;
  while (e <> NIL) do
  begin
    t := e^.next;
    DISPOSE(e);
    e := t;
  end;

  e := stage.bulletHead^.next;
  while (e <> NIL) do
  begin
    t := e^.next;
    DISPOSE(e);
    e := t;
  end;

  stage.fighterTail := stage.fighterHead;
  stage.bulletTail  := stage.bulletHead;
  initPlayer;
  initStarfield;
  enemyspawnTimer := 0;
  resetTimer := FPS * 3;
end;

procedure resetLists;
VAR ex, u : PExplosion;
    d, v  : PDebris;
begin
  ex := stage.explosionHead^.next;
  while (ex <> NIL) do
  begin
    u := ex^.next;
    DISPOSE(ex);
    ex := u;
  end;

  d := stage.debrisHead^.next;
  while (d <> NIL) do
  begin
    v := d^.next;
    DISPOSE(d);
    d := v;
  end;

  stage.explosionTail := stage.explosionHead;
  stage.debrisTail  := stage.debrisHead;
end;

procedure logic_Game;
begin
  doBackGround;
  doStarfield;
  doPlayer;
  doEnemies;
  doFighters;
  doBullets;
  doExplosions;
  doDebris;
  spawnEnemies;
  clipPlayer;
  if (player = NIL) then
  begin
    DEC(resetTimer);
    if (resetTimer <= 0) then
      resetStage;
  end;
end;

procedure initStage;
begin
  app.delegate.logic := @logic_Game;
  app.delegate.draw  := @draw_Game;
  NEW(stage.fighterHead);
  NEW(stage.bulletHead);
  NEW(stage.explosionHead);
  NEW(stage.debrisHead);
  initEntity(stage.fighterHead);
  initEntity(stage.bulletHead);
  initExplosion(stage.explosionHead);
  initDebris(stage.debrisHead);
  stage.fighterTail   := stage.fighterHead;
  stage.bulletTail    := stage.bulletHead;
  stage.explosionTail := stage.explosionHead;
  stage.debrisTail    := stage.debrisHead;
  bulletTexture       := loadTexture('gfx/playerBullet.png');
  enemyTexture        := loadTexture('gfx/enemy.png');
  alienbulletTexture  := loadTexture('gfx/alienBullet.png');
  playerTexture       := loadTexture('gfx/player.png');
  background          := loadTexture('gfx/background.png');
  explosionTexture    := loadTexture('gfx/explosion.png');
  resetStage;
end;

// ***************   INIT SDL   ***************

procedure initSDL;
VAR windowFlags : integer;
begin
  windowFlags := 0;

  if NOT SDL_Init(SDL_INIT_VIDEO) then
    errorMessage(SDL_GetError());

  app.Window := SDL_CreateWindow('Shooter 09', SCREEN_WIDTH, SCREEN_HEIGHT, windowFlags);
  if app.Window = NIL then
    errorMessage(SDL_GetError());

  app.Renderer := SDL_CreateRenderer(app.Window, NIL);
  if app.Renderer = NIL then
    errorMessage(SDL_GetError());

  SDL_HideCursor;
end;

procedure cleanUp;
begin
  DISPOSE(player);
  DISPOSE(stage.debrisHead);
  DISPOSE(stage.explosionHead);
  DISPOSE(stage.fighterHead);
  DISPOSE(stage.bulletHead);
  if ExitCode <> 0 then WriteLn('CleanUp complete!');
end;

procedure AtExit;
begin
  if ExitCode <> 0 then cleanUp;
  SDL_DestroyTexture (alienbulletTexture);
  SDL_DestroyTexture (playerTexture);
  SDL_DestroyTexture (bulletTexture);
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

  resetStage;
  resetLists;
  cleanUp;
  AtExit;
end.
