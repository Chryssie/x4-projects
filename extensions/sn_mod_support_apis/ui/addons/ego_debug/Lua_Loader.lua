--[[
Simple api for loading in mod lua files.
This works around a bug in the x4 ui.xml style lua loading which fails
to initialize the globals table.

Usage is kept simple:
    When the ui reloads or a game is loaded, a ui event is raised.
    User MD code will set up a cue to trigger on this event and signal to
    lua which file to load.
    Lua will then "require" the file, effectively loading it into the game.

This lua file is itself included by modding an official ui.xml. Lua added
in this way is imported correctly into X4, though there are limited
official ui.xml files which can be modified in this way.
    

Example from MD:

    <cue name="Load_Lua_Files" instantiate="true">
    <conditions>
        <event_ui_triggered screen="'Lua_Loader'" control="'Ready'" />
    </conditions>
    <actions>
        <raise_lua_event name="'Lua_Loader.Load'" 
            param="'extensions.sn_named_pipes_api.Named_Pipes'"/>
    </actions>
    </cue>
  
Here, the cue name can be anything, and the param is the specific
path to the lua file to load, without extension.
The file extension may be ".lua" or ".txt", where the latter may be
needed to distribute lua files through steam workshop.
The lua file needs to be loose, not packed in a cat/dat.

When a loading is complete, a message is printed to the debuglog, and
a ui signal is raised. The "control" field will be "Loaded " followed
by the original file_path. This can be used to set up loading
dependencies, so that one lua file only loads after a prior one.

Example dependency condition:

    <conditions>
        <event_ui_triggered screen="'Lua_Loader'" 
            control="'Loaded extensions.sn_named_pipes_api.Named_Pipes'" />
    </conditions>
    
TODO: allow for more md arguments, including specifying dependendencies
which are resolved at this level (eg. store and delay the require until
all dependencies are met).
]]
local function on_Load_Lua_File(_, file_path)

    -- Since lua files cannot be distributed with steam workshop stuff,
    -- but txt can, use a trick to change the package search path to
    -- also look for txt files (which can be put on steam).
    -- This is done on every load, since the package.path was observed to
    -- get reset after Init runs (noticed in x4 3.3hf1).
    if not string.find(package.path, "?.txt;") then
        package.path = "?.txt;"..package.path
    end

    require(file_path)
    -- Removing the debug message; if a user really wants to know,
    -- they can listen to the ui event.
    --DebugError("LUA Loader API: loaded "..file_path)

    -- Generic signal that the load completed, for use when there
    -- are inter-lua dependencies (to control loading order).
    AddUITriggeredEvent("Lua_Loader", "Loaded "..file_path)
end

local function Announce_Reload()
    --DebugError("LUA Loader API: Signalling 'Lua_Loader, Ready'")
    -- Send a ui signal, telling all md cues to rerun.
    AddUITriggeredEvent("Lua_Loader", "Ready")
end

local function Init()    
    --DebugError("LUA Loader API: Running Init()")
    -- Hook up an md->lua signal.
    RegisterEvent("Lua_Loader.Load", on_Load_Lua_File)
    
    -- Re-announce the UI signal on game reload, signalled by MD.
    -- (Used since ui gets set up and signals thrown away before md loads).
    RegisterEvent("Lua_Loader.Signal", Announce_Reload)

    -- Also call the function once on ui reload itself, to catch /reloadui
    -- commands while the md is running.
    Announce_Reload()
end
Init()