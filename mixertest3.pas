program mixertest3;

uses
  crt,
  SDL3,
  SDL3_mixer;

const maxSound = 5;

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

  Window := SDL_CreateWindow('Mixertest; Press "1" to "5" for soundeffects', 640, 480, windowFlags);
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

  for i := 0 to 0 {maxSound} do                                    { how many mixers ?? }
  begin
    app[i]^.mixer := MIX_CreateMixerDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, nil);
    if app[i]^.mixer = nil then begin
      SDL_Log('Couldn''t create mixer: %s', SDL_GetError);
      Halt(SDL_APP_FAILURE);
    end;
  end;

  for i := 0 to maxSound do
  begin
    app[i]^.audio := MIX_LoadAudio(app[0]^.mixer, audiofname[i], True);
    if app[i]^.audio = nil then begin
      SDL_Log('Couldn''t load audio from %s: %s', audiofname[i], SDL_GetError);
      Halt(SDL_APP_FAILURE);
    end;

    app[i]^.track := MIX_CreateTrack(app[0]^.mixer);
    if app[i]^.track = nil then begin
      SDL_Log('Couldn''t create track: %s', SDL_GetError);
      Halt(SDL_APP_FAILURE);
    end;

    option := SDL_CreateProperties();
    SDL_SetNumberProperty(option, MIX_PROP_PLAY_LOOPS_NUMBER, -1); { Play sound in a loop  }

    Mix_SetTrackGain(app[i]^.track, 0.95);                         { Sound volume [0 .. 1] }

    MIX_SetTrackAudio(app[i]^.track, app[i]^.audio);
  end;
end;

  procedure doInput;
  begin
    while SDL_PollEvent(@Event) do
    begin
      CASE Event._Type of
        SDL_EVENT_QUIT              : exitLoop := TRUE;        { close Window }
        SDL_EVENT_MOUSE_BUTTON_DOWN : exitLoop := TRUE;        { if Mousebutton pressed }
      end;

      CASE Event.key.key of
        SDLK_ESCAPE                 : exitLoop := TRUE;        { close Window with ESC-Key }
        SDLK_1: if NOT MIX_TrackPlaying(app[1]^.track) then MIX_PlayTrack(app[1]^.track, 0);  { Mix_PlayAudio(app[0]^.mixer, app[1]^.audio); }
        SDLK_2: if NOT MIX_TrackPlaying(app[2]^.track) then MIX_PlayTrack(app[2]^.track, 0);  { Mix_PlayAudio(app[0]^.mixer, app[2]^.audio); }
        SDLK_3: if NOT MIX_TrackPlaying(app[3]^.track) then MIX_PlayTrack(app[3]^.track, 0);  { Mix_PlayAudio(app[0]^.mixer, app[3]^.audio); }
        SDLK_4: if NOT MIX_TrackPlaying(app[4]^.track) then MIX_PlayTrack(app[4]^.track, 0);  { Mix_PlayAudio(app[0]^.mixer, app[4]^.audio); }
        SDLK_5: if NOT MIX_TrackPlaying(app[5]^.track) then MIX_PlayTrack(app[5]^.track, 0);  { Mix_PlayAudio(app[0]^.mixer, app[5]^.audio); }
      end;  { CASE Event }
    end;    { SDL_PollEvent }
  end;

begin
  clrscr;
  audiofname[0] := 'music/Mercury.ogg';
  audiofname[1] := 'sound/334227__jradcoolness__laser.ogg';
  audiofname[2] := 'sound/196914__dpoggioli__laser-gun.ogg';
  audiofname[3] := 'sound/245372__quaker540__hq-explosion.ogg';
  audiofname[4] := 'sound/10 Guage Shotgun-SoundBible.com-74120584.ogg';
  audiofname[5] := 'sound/342749__rhodesmas__notification-01.ogg';

  InitSDL;

  MIX_PlayTrack(app[0]^.track, option);       { Background Music plays in a loop }
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
