program mixertest3;

uses
  crt,
  SDL3,
  SDL3_mixer;

const maxSound = 2;

type
  TApp = record
    mixer: PMIX_Mixer;
    track: PMIX_Track;
    audio: PMIX_Audio;
  end;
  PApp = ^TApp;

VAR
  app        : array[0..maxSound] of PApp;
  audiofname : array[0..maxSound] of PChar;
  Event      : TSDL_EVENT;
  exitLoop   : BOOLEAN;
  window     : PSDL_Window;
  renderer   : PSDL_Renderer;
  i          : byte;
  option     : TSDL_PropertiesID;

procedure presentScene;
begin
  SDL_RenderPresent(Renderer);
end;

procedure initSDL;
VAR windowFlags : integer;
begin
  windowFlags := 0;
  if NOT SDL_Init(SDL_INIT_VIDEO) then
  begin
    writeln('Couldn''t initialize SDL');
    HALT(1);
  end;

  Window := SDL_CreateWindow('Mixertest; Press "Key left" & "Key right" for soundeffects', 640, 480, windowFlags);
  if Window = NIL then
  begin
    writeln('Failed to open window');
    HALT(1);
  end;

  Renderer := SDL_CreateRenderer(Window, NIL);
  if Renderer = NIL then
  begin
    writeln('Failed to create renderer');
    HALT(1);
  end;

  for i:= 0 to maxSound do
  begin
    app[i] := SDL_malloc(SizeOf(TApp));
    app[i]^ := Default(TApp);
  end;

  SDL_SetHint(SDL_HINT_MAIN_CALLBACK_RATE, '5');

  if not MIX_Init then
  begin
    SDL_Log('Couldn''t initialize SDL_mixer: %s', SDL_GetError);
    Exit;
  end;

  for i:= 0 to maxSound do
  begin
    app[i]^.mixer := MIX_CreateMixerDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, nil);
    if app[i]^.mixer = nil then begin
      SDL_Log('Couldn''t create mixer: %s', SDL_GetError);
      Halt(SDL_APP_FAILURE);
    end;

    app[i]^.audio := MIX_LoadAudio(app[i]^.mixer, audiofname[i], True);
    if app[i]^.audio = nil then begin
      SDL_Log('Couldn''t load audio from %s: %s', audiofname[i], SDL_GetError);
      Halt(SDL_APP_FAILURE);
    end;

    app[i]^.track := MIX_CreateTrack(app[i]^.mixer);
    if app[i]^.track = nil then begin
      SDL_Log('Couldn''t create track: %s', SDL_GetError);
      Halt(SDL_APP_FAILURE);
    end;

    option := SDL_CreateProperties();
    SDL_SetNumberProperty(option, MIX_PROP_PLAY_LOOPS_NUMBER, -1); // Play sound in a loop

    Mix_SetTrackGain(app[i]^.track, 0.95);                         // Sound volume

    MIX_SetTrackAudio(app[i]^.track, app[i]^.audio);
    //MIX_PlayTrack(app[i]^.track, 0);
  end;
end;

  procedure doInput;
  begin
    while SDL_PollEvent(@Event) do
    begin
      CASE Event._Type of

        SDL_EVENT_QUIT:              exitLoop := TRUE;        { close Window }
        SDL_EVENT_MOUSE_BUTTON_DOWN: exitLoop := TRUE;        { if Mousebutton pressed }
      end;
      CASE Event.key.key of
        SDLK_ESCAPE          : exitLoop := TRUE;              { close Window with ESC-Key }

        SDLK_LEFT,  SDLK_KP_4: if NOT MIX_TrackPlaying(app[0]^.track) then MIX_PlayTrack(app[0]^.track, 0);
        SDLK_RIGHT, SDLK_KP_6: if NOT MIX_TrackPlaying(app[1]^.track) then MIX_PlayTrack(app[1]^.track, 0);
      end;  { CASE Event }
    end;    { SDL_PollEvent }
  end;

begin
  clrscr;

  audiofname[0] := 'sound/10 Guage Shotgun-SoundBible.com-74120584.ogg';
  audiofname[1] := 'sound/342749__rhodesmas__notification-01.ogg';
  audiofname[2] := 'music/Mercury.ogg';

  InitSDL;

  MIX_PlayTrack(app[2]^.track, option);
  SDL_DestroyProperties(option);

  while exitLoop = FALSE do
  begin
    doInput;
    presentScene;
    SDL_Delay(2);
  end;

  for i := 0 to maxSound do
    SDL_free(app[i]);

  MIX_Quit;
  SDL_Quit;
end.
