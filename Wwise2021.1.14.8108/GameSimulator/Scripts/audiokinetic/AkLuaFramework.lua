--[[ ***********************
Escape condition used in the game loop
***********************]]
function AkEscapeLoopCondition()
	local checkButton
    if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then
        checkButton = VK_ESCAPE
    else
        checkButton = AK_GAMEPAD_BUTTON_10
    end
    return AkIsButtonPressedThisFrame( checkButton ) or kEndOfTests
end

--[[ ***********************
Returns true if and only if the button is being pressed in the current game frame.
***********************]]
function AkIsButtonPressedThisFrame( in_nButton )	
	if( kButtonsCurrentlyDown[ in_nButton ] ) then -- button already pressed
		return false
	else
		if( AkLuaGameEngine.IsButtonPressed( in_nButton ) ) then
			kButtonsCurrentlyDown[ in_nButton ] = true
			return true
		end
	end
end

--[[ ***********************
This method is used to avoid recognizing a button being pressed twice in the same game frame.
***********************]]
function AkButtonCleanUp()
	for key,bIsKeyDown in pairs( kButtonsCurrentlyDown ) do
		if( not AkLuaGameEngine.IsButtonPressed( key ) ) then
			kButtonsCurrentlyDown[ key ] = false
		end
	end
end

--[[ ***********************
This method contains the calls necessary for one game tick for the sound engine
***********************]]
function AkGameTick()		
	if ( not AK.SoundEngine.IsInitialized() ) then
		return
	end
	
	--Execute all user-registered per-tick calls
	for key,funcInfo in pairs(g_GameTickCalls) do		
		funcInfo._Func(funcInfo)	
	end
	
	AK.SoundEngine.RenderAudio()
	AkLuaGameEngine.Render()
	AkLuaGameEngine.ExecuteEventCallbacks()
	AkLuaGameEngine.ExecuteBankCallbacks()
	AkButtonCleanUp()
end

--[[ ***********************
Game loop that renders audio (and communication) until the escape condition is valid
***********************]]
function AkGameLoop()	
	local fDeltaFramesMs = 1/kFramerate * 1000 -- approximate time between frames, in ms
    if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then
	    print("\t\tPress escape to quit the game loop")
	else
	     AutoLogTestMsg( "****** "..kButtonNameMapping.AK_GAMEPAD_BUTTON_10.." to quit the game loop ******",0,1 )
    end	
	
	kEndOfTests = false;
    while( not AkEscapeLoopCondition() ) do
		
		AkHandleCoroutines()		
		
		AkGameTick()		
		
		os.sleep( fDeltaFramesMs )
	end	
end

--[[ ***********************
This function runs the game loop for in_ms at a frame rate of kFramerate frames/s, with communication if AK_LUA_RELEASE is not defined
***********************]]
function AkRunGameLoopForPeriod( in_ms )
	local fDeltaFramesMs = 1/kFramerate * 1000 -- approximate time between frames, in ms
	
	local initial_time = os.gettickcount()
	
	if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then
	    print("\t\tPress escape to quit this loop")
	else
	    print("\t\tPress Start to quit this loop")
    end
    kEndOfTests = false;
	while( ( os.gettickcount() - initial_time < in_ms ) and ( not AkEscapeLoopCondition() ) ) do		
		AkGameTick()		
		os.sleep( fDeltaFramesMs )
	end	
end

--[[ ***********************
This method will start the coroutines from the game loop.
***********************]]
function AkHandleCoroutines()
	if( g_coroutineHandle ) then
		if( coroutine.status( g_coroutineHandle ) ~= 'dead' ) then
			success, errMsg = coroutine.resume( g_coroutineHandle )
			if success == false then
				print(errMsg)
			end
		end
    end
end

--[[ ***********************
Retrieve configured audio settings
***********************]]
function GetAudioSettings( out_audioSettings )

	AK.SoundEngine.GetAudioSettings( out_audioSettings )
end

--[[ ***********************
Here we define the SoundEngine DefaultInitSettings
***********************]]
function GetDefaultInitSettings( out_initSettings )

	AK.SoundEngine.GetDefaultInitSettings( out_initSettings )
end

--[[ ***********************
Here we define the SoundEngine DefaultPlatformInitSettings
***********************]]
function GetDefaultPlatformInitSettings( out_platformInitSettings )

	AK.SoundEngine.GetDefaultPlatformInitSettings( out_platformInitSettings )
end

--[[ ***********************
Here we define the SoundEngine DefaultDeviceSettings
***********************]]
function GetDefaultDeviceSettings( out_deviceSettings )

	AK.StreamMgr.GetDefaultDeviceSettings( out_deviceSettings )
	
	out_deviceSettings.fMaxCacheRatio = 2
    
end

--[[ ***********************
Here we define the SoundEngine DefaultStreamSettings
***********************]]
function GetDefaultStreamSettings( out_stmSettings )

	AK.StreamMgr.GetDefaultSettings( out_stmSettings )

end

--[[ ***********************
Initialize the Sound Engine.

<<< NOTE: >>>
To override the Default Sound Engine Settings in your script: >>>
1) Copy the current function in your script under a different name. (i.e. LocalAkInitSE() ).
2) Add your custom Sound Engine settings in the section below (i.e. initSettings.uDefaultPoolSize = 1024*1024).
3) Make sure to use your custom function (i.e. "LocalAkInitSE()")  instead of the default ("AkInitSE") at the bottom of your script.
***********************]]
function AkInitSE()

	--Create the various parameter structures required to initialize the SoundEngine.
	local initSettings = AkInitSettings:new_local()
	local platformInitSettings = AkPlatformInitSettings:new_local()
	local deviceSettings = AkDeviceSettings:new_local()
	local stmSettings = AkStreamMgrSettings:new_local()
	
	--Get the default Sound Engine settings.
	GetDefaultInitSettings( initSettings )
	GetDefaultPlatformInitSettings( platformInitSettings )
	GetDefaultStreamSettings( stmSettings )
	GetDefaultDeviceSettings( deviceSettings )
	
	-- <<< Add your Custom Sound Engine settings here: >>>
	
	if AK_PLATFORM_XBOXSERIESX then
		-- XSX platform default disable XMA, which is right for games.  But we test it, so enable it for GameSim.
		platformInitSettings.uMaxXMAVoices = 128
	end

	if g_UseMultiCore then
		AutoLogTestMsg( "****** MULTI CORE IS ENABLED ******" )
		initSettings.bUseTaskScheduler = true
	end
	
	if g_OverrideSESettings ~= nil then
		g_OverrideSESettings(initSettings, platformInitSettings, deviceSettings, stmSettings);
	end
	
	--Comment out the following line if you changed the Init Memory Settings for PrepareEvent/PrepareBank.
	AkInitSEParam( initSettings, platformInitSettings, deviceSettings, stmSettings )
	
	--Uncomment the following lines if you changed the Init Memory Settings for PrepareEvent/PrepareBank.
	--AkInitDefaultIOSystem( stmSettings, deviceSettings )
	--AkInitParamsPrivate( initSettings, platformInitSettings )
end

-- Reinit only the sound and music engines (not stream mgr, not comm)
-- This allows running subsequent tests with different init settings / platform init settings.
-- Note that it is not possible to change the I/O init settings this way (because the service is not reinitialized!)
function AkReinitSE(in_banks)
	local initSettings = AkInitSettings:new_local()
	local platformInitSettings = AkPlatformInitSettings:new_local()	
	
	--Get the default Sound Engine settings.
	GetDefaultInitSettings( initSettings )
	GetDefaultPlatformInitSettings( platformInitSettings )

	if g_OverrideSESettings ~= nil then
		g_OverrideSESettings(initSettings, platformInitSettings, nil, nil);
	end

	AK.MusicEngine.Term()
	AK.SoundEngine.Term();
	AK.SoundEngine.Init(initSettings, platformInitSettings);
	AK.MusicEngine.Init(nil);
	if in_banks ~= nil then
		for i=1,#in_banks do
			local filename = in_banks[i]
			print("Loading "..filename)
			AkLoadBank(filename)
		end
	end
end

-- Reinit the sound engine with Vorbis HW Acceleration turned on.
-- This function should only be called for platforms supporting the feature.
function AkEnableVorbisHwAcceleration(in_banks)
	local overrideFn = g_OverrideSESettings
	g_OverrideSESettings = function(initSettings, platformInitSettings, deviceSettings, stmSettings)
		if (overrideFn ~= nil) then
			overrideFn(initSettings, platformInitSettings, deviceSettings, stmSettings)
		end
		platformInitSettings.bVorbisHwAcceleration = true
	end
	AkReinitSE(in_banks)
end

--[[ ***********************
Initialize IO system.
***********************]]
g_lowLevelIO = {}
-- Default one-device system.
function AkInitDefaultIOSystem( in_deviceSettings ) 
	
	-- Create a device BLOCKING or DEFERRED, according to setting's scheduler flag.
	local result = AK_Fail
	if ( in_deviceSettings.uSchedulerTypeFlags == AK_SCHEDULER_BLOCKING ) then
		
		-- Initialize our instance of the default File System/LowLevelIO hook BLOCKING.
		g_lowLevelIO["Default"] = CAkFilePackageLowLevelIOBlocking:new() -- global variable
		result = g_lowLevelIO["Default"]:Init( in_deviceSettings, true )
		
	elseif ( in_deviceSettings.uSchedulerTypeFlags == AK_SCHEDULER_DEFERRED_LINED_UP ) then
		
		-- Initialize our instance of the default File System/LowLevelIO hook DEFERRED.
		g_lowLevelIO["Default"] = CAkFilePackageLowLevelIODeferred:new() -- global variable
		result = g_lowLevelIO["Default"]:Init( in_deviceSettings, true )
		
	end
	assert( result == AK_Success, "Could not create the Low-Level I/O system." )
end

-- Multi-device system with a default and a RAM device.
-- Params:
-- - in_deviceSettingsDefault: device settings for default device.
-- - in_deviceSettingsRAM: device settings for RAM device.
-- - in_bRAMShuffleOrder: stress-testing feature. RAM device will complete low-level IO requests out of order.
-- - in_uRAMDelay: stress-testing feature. RAM device waits in_uRAMDelay ms before completing requests. This lets the device push many requests before they are completed.
function AkInitMultiIOSystem_Default_RAM(in_deviceSettingsDefault, in_deviceSettingsRAM, in_bRAMShuffleOrder, in_uRAMDelay)
	
	print( "Initializing multi-device I/O system: Default + RAM" )
	
	-- Create the Low-Level IO device dispatcher and register to the Stream Manager.
	local dispatcher = CAkDefaultLowLevelIODispatcher:new() -- global variable
	AK.StreamMgr.SetFileLocationResolver( dispatcher )
	
	-- Create a RAM device first and register it to the dispatcher (the dispatcher should ask this one first).
	g_lowLevelIO["RAM"] = RAMLowLevelIOHook:new()
	assert( g_lowLevelIO["RAM"] ~= nil )
	local result = g_lowLevelIO["RAM"]:Init( in_deviceSettingsRAM, in_bRAMShuffleOrder, in_uRAMDelay )
	assert( result == AK_Success, "Could not create the Low-Level I/O system." )
	dispatcher:AddDevice( g_lowLevelIO["RAM"] )
	
	-- Create the default device.
	AkInitDefaultIOSystem( in_deviceSettingsDefault )
	
	-- Register it to the dispatcher.
	dispatcher:AddDevice( g_lowLevelIO["Default"] )
	
end

-- Inject I/O errors in RAM device.
function AkSetRAMDeviceErrorProbability( in_prob )
	g_lowLevelIO["RAM"]:SetErrorProbability( in_prob )
end

-- Enable/disable handling of cancellation in RAM device (deferred only). True by default.
function AkEnableRAMDeviceCancels( in_bEnableCancels )
	g_lowLevelIO["RAM"]:EnableCancels( in_bEnableCancels )
end

-- Default override function to setup a RAM device. 
-- Usage: assign g_OverrideLowLevelIOInit = AkDefaultLowLevelIOOverrideRAM prior to calling the default main.
function AkDefaultLowLevelIOOverrideRAM(in_deviceSettingsDefault)

	-- Prepare device settings for the RAM device.
	local deviceSettingsRAM = AkDeviceSettings:new_local()
	GetDefaultDeviceSettings( deviceSettingsRAM )
	-- Need to specify a deferred scheduler. Additionnally, here are a few standard parameters.
	deviceSettingsRAM.uIOMemorySize = 1 * 1024 * 1024
	deviceSettingsRAM.uGranularity = 4 * 1024
	deviceSettingsRAM.uSchedulerTypeFlags = AK_SCHEDULER_DEFERRED_LINED_UP
	deviceSettingsRAM.fTargetAutoStmBufferLength = 100
	deviceSettingsRAM.uMaxConcurrentIO = 128
	deviceSettingsRAM.fMaxCacheRatio = 2

	-- Init multi device system.
	AkInitMultiIOSystem_Default_RAM(in_deviceSettingsDefault, deviceSettingsRAM, false, 0)
end

--[[ ***********************
Initialize the Sound Engine Platform
***********************]]
function AkInitParamsPrivate( in_initSettings, in_platformInitSettings)
	AK.SoundEngine.Init( in_initSettings, in_platformInitSettings )	
	AK.MusicEngine.Init( nil )	
end

--[[ ***********************
Last phase of the Sound Engine initialization: 
Here we apply the Sound Engine Settings.
***********************]]
-- You can define g_OverrideLowLevelIOInit in order to override the low-level IO initialization.
-- g_OverrideLowLevelIOInit receives the default device settings that were setup (and possibly overridden) in AkInitSE.
-- Typically, you would call AkInitDefaultIOSystem() or one of the multi-device init services. 
function AkInitSEParam( in_initSettings, in_platformInitSettings, in_deviceSettings, in_stmSettings )
	
	-- Create the stream manager and the one and only default low-level device
	streamMgr = AK.StreamMgr.Create( in_stmSettings )
	if streamMgr == nil then 
		assert( false, "Failed creating Stream Manager" )
		return
	end
	
	if g_OverrideLowLevelIOInit ~= nil then
		g_OverrideLowLevelIOInit(in_deviceSettings)
	else
		AkInitDefaultIOSystem(in_deviceSettings) 
	end
	
	AkInitParamsPrivate(in_initSettings, in_platformInitSettings)
	
end

--[[ ***********************
Terminate the sound engine.
***********************]]
function AkTermSE()
	
	collectgarbage()

	-- Terminate the music engine
	AK.MusicEngine.Term()
    
	-- Terminate the sound engine
	AK.SoundEngine.Term()
	
	-- Term and delete all low-level devices
	for k,device in pairs(g_lowLevelIO) do 
		device:Term()
		device:delete()
	end
	
    -- Terminate the streaming manager
    if( AK.IAkStreamMgr:Get() ~= NULL ) then
		AK.IAkStreamMgr:Get():Destroy()
    end
end

--[[ ***********************
Initialize communications.
***********************]]
function AkInitComm()

	local settingsComm = AkCommSettings:new_local()
	
	AK.Comm.GetDefaultInitSettings( settingsComm )
	
	result = AK.Comm.Init( settingsComm )
	if result ~= AK_Success then print "Failed creating communication services"  end

end

--[[ ***********************
Terminate communications.
***********************]]
function AkTermComm()

	AK.Comm.Term()

end

--[[ ***********************
Lua callback for the LoadBank method
***********************]]
function AkLoadBankCallBackFunction( in_bankID, in_eLoadStatus, in_cookie )
    print( "************ LoadBank callback ************" )
    print( string.format( "in_bankID: %s, in_eLoadStatus: %d, in_cookie: %d", in_bankID, in_eLoadStatus, in_cookie ) )
    if( not AK_LUA_RELEASE ) then
    	if( in_eLoadStatus == AK_Success ) then
			AK.SoundEngine.PostMsgMonitor( string.format( "Loaded bank with ID: %d", in_bankID ) )
		else
			AK.SoundEngine.PostMsgMonitor( string.format( "Failed to load bank with ID: %d", in_bankID ) )
    	end
    end 
    print( "***************************************" )
end

--[[ ***********************
Lua callback for the UnloadBank method
***********************]]
function AkUnloadBankCallBackFunction( in_bankID, in_eLoadStatus, in_cookie )
    print( "************ UnloadBank callback ************" )
    print( string.format( "in_bankID: %d, in_eLoadStatus: %d, in_cookie: %d", in_bankID, in_eLoadStatus, in_cookie ) )
    
    print( "***************************************" )
end

--[[ ***********************
Lua callback for the PostEvent method
***********************]]
function AkPostEventCallBackFunction( in_callbackType, in_data )
    print( "************ Event callback ************" )
    -- This shows callback use
    if( in_callbackType == AK_Marker ) then
        print( string.format( "Identifier: %s, position: %s, label: %s", in_data.uIdentifier, in_data.uPosition, in_data.strLabel ) )
    elseif( in_callbackType == AK_Duration ) then
        print( string.format( "Duration is: %f, Estimated Duration is: %f", in_data.fDuration , in_data.fEstimatedDuration ) )
	else 
        assert( in_callbackType == AK_EndOfEvent )
        print( "End of event!" )
    end
	sourcePosition = 0
	result, sourcePosition = AK.SoundEngine.GetSourcePlayPosition( in_data.playingID, sourcePosition )
	if( result == AK_Success ) then
		print( string.format( "Source position: %s", sourcePosition ) )
	end
    print( "****************************************" )
end

--[[ ***********************
Interactive Music Timer Lua callback for the PostEvent method.
-- Available Flags: AK_MusicSyncBeat, AK_MusicSyncBar, AK_MusicSyncEntry, AK_MusicSyncExit, AK_MusicSyncAll
-- Usage sample in Game Simulator: AK.SoundEngine.PostEvent( "Play", MyGameObjectID, AK_MusicSyncAll, "AkMusicCallbackFunction", 0 )
***********************]]
function AkMusicCallbackFunction( in_callbackType, in_callbackInfo )

	print(string.format( "BarDuration: %f", in_callbackInfo.segmentInfo.fBarDuration) )
	print(string.format( "BeatDuration: %f", in_callbackInfo.segmentInfo.fBeatDuration) )
	print(string.format( "GridDuration: %f", in_callbackInfo.segmentInfo.fGridDuration) )
	print(string.format( "GridOffset: %f", in_callbackInfo.segmentInfo.fGridOffset) )
	
	if( in_callbackType == AK_MusicSyncBeat ) then
		print("Music Timer callback > Beat")
	end
	if( in_callbackType == AK_MusicSyncBar ) then
		print("Music Timer callback >> Bar")
	end
	if( in_callbackType == AK_MusicSyncEntry ) then
		print("Music Timer callback >>> Entry Cue")
	end
	if( in_callbackType == AK_MusicSyncExit ) then
		print("Music Timer callback >>>> Exit Cue")
	end
	
	if( in_callbackType == AK_MusicSyncGrid ) then
		print("Music Timer callback >>>> Grid Cue")
	end
	if( in_callbackType == AK_MusicSyncUserCue ) then
		print("Music Timer callback >>>> User Cue")
	end
	if( in_callbackType == AK_MusicSyncPoint ) then
		print("Music Timer callback >>>> Sync Point")
	end
	
end

--[[ ***********************
Stop all playing sounds, the sound engine and all communications
***********************]]
function AkStop()
	if( AK.SoundEngine.IsInitialized() ) then
		result = AK.SoundEngine.UnregisterAllGameObj()
	    assert( result == AK_Success, "Error unregistering all game objects" )
	    
	    AK.SoundEngine.StopAllObsolete()
		AK.SoundEngine.ClearBanks()
	end
	
	if( not AK_LUA_RELEASE ) then
		AkTermComm()
	end
	AkTermSE()
end

--[[ ***********************
Load a bank synchronously, per name.
***********************]]
function AkLoadBank( in_strBankName )
	local bankID = 0
	local result = 0
		
	result, bankID = AK.SoundEngine.LoadBank( in_strBankName, bankID )
	if (result ~= AK_BankAlreadyLoaded and result ~= AK_Success) then
		print( string.format( "Error(%d) loading bank [%s]", result, in_strBankName ) )
	end
	return result
end

--[[ ***********************
Load a File Package, per name.
***********************]]
-- Default package loading/unloading in Low-Level IO.
function AkLoadPackage( in_strPackageName )	-- Returns result, packageID
	return AkLoadPackageFromDevice( g_lowLevelIO["Default"], in_strPackageName )
end
-- in_uPackage can be either the string that was used to load it, or the ID returned by AkLoadPackageFromDevice
function AkUnloadPackage( in_uPackage )
	return AkUnloadPackageFromDevice( g_lowLevelIO["Default"], in_uPackage )
end

-- Internal: Wrappers for device::LoadFilePackage() and device::UnloadFilePackage()
function AkLoadPackageFromDevice( device, in_strPackageName )
	local result = 0
	local packageID = 0
	print( string.format( "Loading package [%s]...", in_strPackageName ) )
	result, packageID = device:LoadFilePackage( in_strPackageName )
	
	if (result == AK_Success or result == AK_InvalidLanguage) then
		print( string.format( "Successful. Returned ID=[%u]", packageID ) )
		if (result == AK_InvalidLanguage) then
			print( "Warning: Invalid language set with file package" )
		end
	else
		print( string.format( "Error loading file package [%s]", in_strPackageName ) )
	end		
	
	return result, packageID
end
-- in_uPackage can be either the string that was used to load it, or the ID returned by AkLoadPackageFromDevice
function AkUnloadPackageFromDevice( device, in_uPackage )
	device:UnloadFilePackage( in_uPackage )
end

--[[ ***********************
Unload a bank synchronously, per name.
***********************]]
function AkUnloadBank( in_strBankName )
	local bankID = 0
	local result = 0	
	
	result = AK.SoundEngine.UnloadBank( in_strBankName )
	if ( result ~= AK_Success ) then
		print( string.format( "Error unloading bank [%s]", in_strBankName ) )
	end
	return result
end

--[[ ***********************
Registers game objects in_nGameObjectStart to in_nGameObjectEnd
***********************]]
function AkRegisterGameObject( in_nGameObjectStart, in_nGameObjectEnd )
	for GO = in_nGameObjectStart, in_nGameObjectEnd do
		local result = AK.SoundEngine.RegisterGameObj( GO  )
		if ( result ~= AK_Success) then
			print( string.format( "Error registering game object [%d]", GO ) )
		end
	end
end

--[[ ***********************
Unregisters game objects in_nGameObjectStart to in_nGameObjectEnd
***********************]]
function AkUnregisterGameObject( in_nGameObjectStart, in_nGameObjectEnd)
	for GO = in_nGameObjectStart, in_nGameObjectEnd do
		local result = AK.SoundEngine.UnregisterGameObj( GO )
		if ( result ~= AK_Success) then
			print( string.format( "Error unregistering game object [%d]", GO ) )
		end
	end
end

--[[**************************
New Soundbanks helpers "Asynchronous" variable: g_GlobalUnloadIdentifier
****************************]]
-- 1073741824 is the decimal nomination for 0x40000000 or 0b01000000000000000000000000000000
g_GlobalUnloadIdentifier = 10000 --1073741824

--[[**************************
New Soundbanks helpers "Asynchronous": GetCookie
****************************]]
function GetCookie( in_IsLoad, in_EventID )
	if( in_IsLoad == true ) then
		return in_EventID + g_GlobalUnloadIdentifier
	else
		return in_EventID
	end
end

--[[**************************
New Soundbanks helpers "Asynchronous": GetEventIDFromCookie
****************************]]
function GetEventIDFromCookie( in_Cookie )

	if( in_Cookie >= g_GlobalUnloadIdentifier ) then
		return in_Cookie - g_GlobalUnloadIdentifier
	else
		return in_Cookie
	end
end

--[[**************************
New Soundbanks helpers "Asynchronous": GetIsLoadFromCookie
****************************]]
function GetIsLoadFromCookie( in_Cookie )
	if( in_Cookie >= g_GlobalUnloadIdentifier ) then
		return true
	else
		return false
	end
end

--[[ ***********************
Lua callback for the PrepareEventAsync method
****************************]]
function PrepareEventCallBackFunction( in_EventID, in_eLoadStatus, in_cookie )
    
    local PreparedID = GetEventIDFromCookie( in_cookie )
    local ActionString
    local FailureString
    
    if( GetIsLoadFromCookie( in_cookie ) == true ) then
		ActionString = "prepared"
		FailureString = "prepare"
	else
		ActionString = "unprepared"
		FailureString = "unprepare"
	end
    
    if( in_eLoadStatus == AK_Success ) then
		print( string.format( "Successfully %s the Event identified as # %s", ActionString, PreparedID ) )
		if( GetIsLoadFromCookie(in_cookie) ) then
			g_PreparedEventMemory[PreparedID] = g_PreparedEventMemory[PreparedID] + 1
		else
			if (g_PreparedEventMemory[PreparedID] > 0) then -- unprepare of an unprepared id yields success: clamp to 0
			g_PreparedEventMemory[PreparedID] = g_PreparedEventMemory[PreparedID] - 1
		end
		end
		
    else
		print( string.format( "Failed to %s the Event identified as # %s", FailureString, PreparedID ) )
    end
end

--[[ ***********************
Lua callback for the AkLoadBankAsync method
****************************]]
function AsyncLoadBankCallBackFunction ( in_bankID, in_MemoryPtr, in_eLoadStatus, in_cookie )
		
    local PreparedID = GetEventIDFromCookie( in_cookie )
    local ActionString
    local FailureString
    
    if( GetIsLoadFromCookie( in_cookie ) == true ) then
		ActionString = "loaded bank"
		FailureString = "loading bank"
	else
		ActionString = "unloaded bank"
		FailureString = "unloading bank"
	end

    if( in_eLoadStatus == AK_Success or in_eLoadStatus == AK_BankAlreadyLoaded) then
		print( string.format( "Successfully %s identified as # %s", ActionString, PreparedID ) )
		if( GetIsLoadFromCookie(in_cookie) ) then
			g_LoadBankMemory[PreparedID] = g_LoadBankMemory[PreparedID] + 1
		else
			g_LoadBankMemory[PreparedID] = g_LoadBankMemory[PreparedID] - 1
		end
		
    else
		print( string.format( "Error %s identified as # %s", FailureString, PreparedID ) )
    end
end


--[[ ***********************
Lua callback for the AkPrepareBankAsync method
****************************]]
function AkAsyncPrepareBankCallBackFunction ( in_bankID, in_MemoryPtr, in_eLoadStatus, in_cookie )

    local PreparedID = GetEventIDFromCookie( in_cookie )
    local ActionString
    local FailureString
    
    if( GetIsLoadFromCookie( in_cookie ) == true ) then
		ActionString = "prepared bank"
		FailureString = "preparing bank"
	else
		ActionString = "unprepared bank"
		FailureString = "unpreparing bank"
	end

    if( in_eLoadStatus == AK_Success ) then
		print( string.format( "Successfully %s identified as # %s", ActionString, PreparedID ) )
		if( GetIsLoadFromCookie(in_cookie) ) then
			g_PrepareBankMemory[PreparedID] = g_PrepareBankMemory[PreparedID] + 1
		else
			g_PrepareBankMemory[PreparedID] = g_PrepareBankMemory[PreparedID] - 1
		end
		
    else
		print( string.format( "Error %s identified as # %s", FailureString, PreparedID ) )
    end
end


--[[ ***********************
Lua callback for the PrepareGameSyncAsync method
****************************]]
function PrepareGameSyncCallBackFunction( in_eLoadStatus, in_cookie )

    local PreparedID = GetEventIDFromCookie( in_cookie )
    local ActionString
    local FailureString
    
    if( GetIsLoadFromCookie( in_cookie ) == true ) then
		ActionString = "prepared"
		FailureString = "prepare"
	else
		ActionString = "unprepared"
		FailureString = "unprepare"
	end
    
    if( in_eLoadStatus == AK_Success ) then
		print( string.format( "Successfully %s the Game Sync identified as # %s", ActionString, PreparedID ) )
		if( GetIsLoadFromCookie(in_cookie) ) then
			g_PreparedGameSyncEventMemory[PreparedID] = g_PreparedGameSyncEventMemory[PreparedID] + 1
		else
			g_PreparedGameSyncEventMemory[PreparedID] = g_PreparedGameSyncEventMemory[PreparedID] - 1
		end
		
    else
		print( string.format( "Failed to %s the Game Sync identified as # %s", FailureString, PreparedID ) )
    end
end

--[[ ***********************
Lua callback for the AkLoadPackageAsync method
Users must declare a g_PackageBankMemory table in their scripts.
****************************]]
function AsyncLoadPackageCallBackFunction( in_packageID, in_eLoadStatus, in_cookie )

    local PreparedID = GetEventIDFromCookie( in_cookie )
    local ActionString
    local FailureString
    
    if( GetIsLoadFromCookie( in_cookie ) == true ) then
		ActionString = "loaded package"
		FailureString = "loading package"
	else
		ActionString = "unloaded package"
		FailureString = "unloading package"
	end

    if( in_eLoadStatus == AK_Success or in_eLoadStatus == AK_InvalidLanguage ) then
		print( string.format( "Successfully %s identified as # %s", ActionString, PreparedID ) )
		if( GetIsLoadFromCookie(in_cookie) ) then
			g_PackageBankMemory[PreparedID] = g_PackageBankMemory[PreparedID] + 1
		else
			g_PackageBankMemory[PreparedID] = g_PackageBankMemory[PreparedID] - 1
		end
		
    else
		print( string.format( "Error %s identified as # %s", FailureString, PreparedID ) )
    end
end

--[[ ***********************
Wait on completion of Async operation
****************************]]

function AkWaitAsync( in_IsLoad, in_Memory, in_UniqueIdentifier )
	if( AkLuaGameEngine.IsOffline() ) then
		if( in_IsLoad ) then
			while( in_Memory[in_UniqueIdentifier] == 0 ) do
				os.sleep( 10 ) -- so that our busy wait doesn't hog the cpu
				AkLuaGameEngine.ExecuteBankCallbacks() -- only execute bank callbacks: don't render audio while waiting, as that yields a non-deterministic number of audio frames
			end
		else
			AkGameTick() -- ensure one audio frame has elapsed for voices to be stopped
			while( in_Memory[in_UniqueIdentifier] ~= 0 ) do
				os.sleep( 10 )
				AkLuaGameEngine.ExecuteBankCallbacks()
			end
		end
	else
		if( in_IsLoad ) then
			while( in_Memory[in_UniqueIdentifier] == 0 ) do
				AkGameTick()
			end
		else
			while( in_Memory[in_UniqueIdentifier] ~= 0 ) do
				AkGameTick()
			end
		end
	end
end

--[[ ***********************
Prepare an Event asynchronously
****************************]]
function PrepareEventAsync( in_IsLoad, in_EventStringArray, in_NumStringInArray, in_UniqueIdentifier )
	local l_cookie = GetCookie( in_IsLoad, in_UniqueIdentifier )
	
	if( in_IsLoad ) then
		print( "Preparing the Event Async" )
		result = AK.SoundEngine.PrepareEvent( Preparation_Load, in_EventStringArray, in_NumStringInArray, "PrepareEventCallBackFunction", l_cookie )
	else
		print( "Unpreparing the Event Async" )
		result = AK.SoundEngine.PrepareEvent( Preparation_Unload, in_EventStringArray, in_NumStringInArray, "PrepareEventCallBackFunction", l_cookie )
	end
	
	if( result ~= AK_Success ) then
		print( "PrepareEvent failed. You may not have enough memory." )
	end
end

function AkWaitPrepareEventAsync( in_IsLoad, in_UniqueIdentifier )
	AkWaitAsync(in_IsLoad, g_PreparedEventMemory, in_UniqueIdentifier)
end

--[[ ***********************
Load a bank asynchronously, per name.
****************************]]
function AkLoadBankAsync( in_IsLoad, in_BankName, in_UniqueIdentifier )
	local l_cookie = GetCookie( in_IsLoad, in_UniqueIdentifier )

	local resultLoad
	local bankIDLoad = 0
	if( in_IsLoad ) then
		print( "Loading the Bank Async" )
		resultLoad, bankIDLoad = AK.SoundEngine.LoadBank( in_BankName, "AsyncLoadBankCallBackFunction", l_cookie, bankIDLoad )
	else
		print( "Unloading the Bank Async" )
		resultLoad = AK.SoundEngine.UnloadBank( in_BankName, "AsyncLoadBankCallBackFunction", l_cookie )
	end
	
	if( result ~= AK_Success ) then
		print( string.format( "Error loading bank [%s] Async. You may not have enough memory.",in_BankName ))
	end
end

function AkWaitLoadBankAsync( in_IsLoad, in_UniqueIdentifier )
	AkWaitAsync(in_IsLoad, g_LoadBankMemory, in_UniqueIdentifier)
end

--[[ ***********************
Prepare a Game Sync asynchronously, per name.
****************************]]
function PrepareGameSyncAsync( in_IsLoad, in_type, in_GroupName, in_GameSyncStringArray, in_NumStringInArray, in_UniqueIdentifier )

	if( AkLuaGameEngine.IsOffline() ) then
		--When in offline mode, asynchronous preparation is indeed a problem...
		--Make it synchroneous,
		if( in_IsLoad ) then
			result = AK.SoundEngine.PrepareGameSyncs (Preparation_Load, in_type, in_GroupName, in_GameSyncStringArray, in_NumStringInArray )
		else
			result = AK.SoundEngine.PrepareGameSyncs (Preparation_Unload, in_type, in_GroupName, in_GameSyncStringArray, in_NumStringInArray )
		end
		
		-- Fake the callback, because the callback will not arrive by itself.
		PrepareGameSyncCallBackFunction( result, GetCookie( in_IsLoad, in_UniqueIdentifier ) )
		
	else
		if( in_IsLoad ) then
			print( "Preparing the GameSync Async" )
			result = AK.SoundEngine.PrepareGameSyncs( Preparation_Load, in_type, in_GroupName ,in_GameSyncStringArray, in_NumStringInArray,"PrepareGameSyncCallBackFunction", GetCookie( in_IsLoad, in_UniqueIdentifier ) )
		else
			print( "Unpreparing the GameSync Async" )
			result = AK.SoundEngine.PrepareGameSyncs( Preparation_Unload, in_type, in_GroupName ,in_GameSyncStringArray, in_NumStringInArray,"PrepareGameSyncCallBackFunction", GetCookie( in_IsLoad, in_UniqueIdentifier ) )
		end

		if( result ~= AK_Success ) then
			print( "PrepareGameSync Async failed. You may not have enough memory." )
		end
	end
end


--[[ ***********************
Prepare a Bank asynchronously, per name.
****************************]]
function AkPrepareBankAsync( in_IsLoad,  in_BankName, in_AllOrStructureOnly, in_UniqueIdentifier )

AkCheckParameters (4, (debug.getinfo(1,"n").name), in_IsLoad,  in_BankName, in_AllOrStructureOnly, in_UniqueIdentifier)
	
		if( in_IsLoad ) then
			print( "Preparing the Bank Async" )
			result = AK.SoundEngine.PrepareBank( Preparation_Load,  in_BankName, "AkAsyncPrepareBankCallBackFunction", GetCookie( in_IsLoad, in_UniqueIdentifier ), in_AllOrStructureOnly  )
		else
			print( "Unpreparing the Bank Async" )
			result = AK.SoundEngine.PrepareBank( Preparation_Unload, in_BankName, "AkAsyncPrepareBankCallBackFunction", GetCookie( in_IsLoad, in_UniqueIdentifier ), in_AllOrStructureOnly )
		end

		if( result ~= AK_Success ) then
			print( "Prepare Bank Async failed. You may not have enough memory." )
		end

end

function AkWaitPrepareBankAsync( in_IsLoad, in_UniqueIdentifier )
	AkWaitAsync(in_IsLoad, g_PrepareBankMemory, in_UniqueIdentifier)
end

--[[ ***********************
Load/unload a file package asynchronously, per name.
NOTE: Only a specific set of devices support asynchronous loading.
****************************]]
function AkLoadPackageAsync( device, in_IsLoad, in_PckName, in_UniqueIdentifier )
	local l_cookie = GetCookie( in_IsLoad, in_UniqueIdentifier )

	local resultLoad
	local pckIDLoad = 0
	if( in_IsLoad ) then
		print( "Loading the Package Async" )
		resultLoad, pckIDLoad = device:LoadFilePackage( in_PckName, "AsyncLoadPackageCallBackFunction", l_cookie, false, pckIDLoad )
	else
		print( "Unloading the Bank Async" )
		resultLoad = device:UnloadFilePackage( in_PckName, "AsyncLoadPackageCallBackFunction", l_cookie )
	end
	
	if( result ~= AK_Success ) then
		print( string.format( "Error loading package [%s] Async. You may not have enough memory.",in_PckName ))
	end
end

--[[ ***********************
The method will verify that the correct amount of parameters is assigned to the function.
****************************]]
function AkCheckParameters(in_NumberOfParameters, in_FunctionName, in_Param1, in_Param2, in_Param3, in_Param4, in_Param5, in_Param6, in_Param7, in_Param8, in_Param9, in_Param10)

	if(in_NumberOfParameters > 0) then
		if (in_Param1 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end

	if(in_NumberOfParameters > 1) then
		if (in_Param2 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end

	if(in_NumberOfParameters > 2) then
		if (in_Param3 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end
	
	if(in_NumberOfParameters > 3) then
		if (in_Param4 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end
	
	if(in_NumberOfParameters > 4) then
		if (in_Param5 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end
	
	if(in_NumberOfParameters > 5) then
		if (in_Param6 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end

	if(in_NumberOfParameters > 6) then
		if (in_Param7 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end

	if(in_NumberOfParameters > 7) then
		if (in_Param8 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end
	
	if(in_NumberOfParameters > 8) then
		if (in_Param9 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end
	
	if(in_NumberOfParameters > 9) then
		if (in_Param10 == nil) then
			print (">>> ERROR in " .. in_FunctionName)
			print (">>> Missing or Invalid Parameter.")
		end
	end
	
end

--This is a table of tables.  It will contain the parameters for each function as well as the function
g_GameTickCalls = {}

-- Use this function to add a call that should be made each tick
-- The routine can receive parameters.  The parameters must be defined in pairs: a string name and the actual value of the parameter
-- This returns the index of the routine in the call order.
-- See the example with AkRampRTPC below
function AkRegisterGameTickCall(in_routine, ...)
	local index = #g_GameTickCalls + 1
	local newCallTable = {}
	newCallTable._Func = in_routine
	newCallTable._Index = index
	
	--Iterate over the extra arguments (the parameters of the target function)
	for n=1,select('#',...),2 do
		local paramName = select(n,...)
		local paramValue = select(n+1,...)
		newCallTable[paramName] = paramValue
	end	
	
	g_GameTickCalls[index] = newCallTable	
	return index
end

-- Unregisters a game tick call
-- See example in AkRampRTPCTick
function AkUnregisterGameTickCall(index)

	table.remove(g_GameTickCalls, index)
	
	-- update the _Index value for the remaining items in the table
	for key,funcInfo in pairs(g_GameTickCalls) do		
		funcInfo._Index = key
	end
	
end

-- Removes all tick calls
function AkClearAllGameTickCalls()
	g_GameTickCalls = {}
end

-- This is the function that does the actual work of setting the RTPC for the AkRampRTPC functionality
-- It is called at each tick.  Do not call this function directly.  
function AkRampRTPCTick(params)	
	AK.SoundEngine.SetRTPCValue(params.Name, params.Value, params.Object)
	
	--Increment the value for the next call
	params.Value = params.Value + params.Inc
	
	--If we finished ramping, remove the call
	if ( params.Inc > 0 ) then
    	if (params.Value > params.Stop) then				
	   	   AkUnregisterGameTickCall(params._Index)
	   end		
	else
		if ( params.Value < params.Stop ) then
			AkUnregisterGameTickCall(params._Index)
		end
	end		
end

-- Use this function to start a ramp of a RTPC.  
-- Parameters: 
-- RTPC_Name: the name of the RTPC as defined in the Wwise project
-- StartValue: the initial value of the RTPC
-- StopValue : the target value of the RTPC
-- Time: the time over which the value will change.
-- GameObj: the gameobject id.  (Optional. Default is g_AkDefaultEmitter)
function AkRampRTPC(in_RTPC_Name, in_StartValue, in_StopValue, in_Time, in_GameObj)
	if in_Time == 0 then
		AK.SoundEngine.SetRTPCValue(in_RTPC_Name, in_StopValue, in_GameObj)
		return
	end

	--Compute the increment we will need for each tick
	local increment = 1
	if AkLuaGameEngine.IsOffline() then
		increment = (in_StopValue - in_StartValue)/(in_Time/AK_AUDIOBUFFERMS)
	else
		increment = (in_StopValue - in_StartValue)/(in_Time *kFramerate /1000)	
	end
	
	if(in_GameObj == nil) then
		in_GameObj = g_AkDefaultEmitter
	end
	
	AkRegisterGameTickCall(AkRampRTPCTick, 
		"Name", in_RTPC_Name, 		
		"Value", in_StartValue, 
		"Stop", in_StopValue, 
		"Inc", increment,
		"Object", in_GameObj)
end



function AkSetListenerPosition(ListenerID, x, y)
	local listenerPos = AkListenerPosition:new_local() 
	listenerPos.OrientationFront.X = 0
	listenerPos.OrientationFront.Y = 0
	listenerPos.OrientationFront.Z = 1

	listenerPos.OrientationTop.X = 0 
	listenerPos.OrientationTop.Y = 1 -- head is up
	listenerPos.OrientationTop.Z = 0 

	--Set starting position
	listenerPos.Position.X = x
	listenerPos.Position.Y = 0 
	listenerPos.Position.Z = y
	AK.SoundEngine.SetListenerPosition(listenerPos, ListenerID)
end

function AkNormalizeListenerPos( listenerPos )
	listenerPos.OrientationFront = AkNormalize( listenerPos.OrientationFront )
	listenerPos.OrientationTop = AkNormalize( listenerPos.OrientationTop )
	return listenerPos
end

function AkNormalize( xyz )
	local norm = 	math.sqrt( xyz.X * xyz.X + xyz.Y * xyz.Y + xyz.Z * xyz.Z )
	xyz.X = xyz.X/norm
	xyz.Y = xyz.Y/norm
	xyz.Z = xyz.Z/norm
	return xyz
end

function AkSetGameObjectPosition(ObjID, x, y, ox, oy)
	local soundPos = AkSoundPosition:new_local() 
 
	soundPos.Position.X = x
	soundPos.Position.Y = 0
	soundPos.Position.Z = y

	if (ox ~= nil and oy ~= nil) then
		soundPos.Orientation.X = ox
		soundPos.Orientation.Y = 0
		soundPos.Orientation.Z = oy
	else
		--Pointing toward the Y axis (in 2D)
		soundPos.Orientation.X = 0 
		soundPos.Orientation.Y = 0
		soundPos.Orientation.Z = 1
	end
		
	AK.SoundEngine.SetPosition( ObjID, soundPos )
end

function AkSign(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
	end
end

function AkMoveListenerOnPathTick(params)	
	function GetTargetX(in_params)			
		return in_params.Path[(in_params.Target-1) *3 + 1]
	end
	function GetTargetY(in_params)
		return in_params.Path[(in_params.Target-1) *3 + 2]
	end
	function GetTargetTime(in_params)
		local t = kFramerate / 1000;
		if AkLuaGameEngine.IsOffline() then
			t = 1/AK_AUDIOBUFFERMS;		
		end
		return in_params.Path[(in_params.Target-1) *3 + 3] * t
	end
	function GetTargetCount(in_params)
		return table.maxn(params.Path) / 3
	end

	if params.xInc == nil or params.yInc == nil then
		params.xInc = 0
		params.yInc = 0
	end

	-- Use sign to prevent oscillating indefinitly if we overshoot
	-- and use the increment check if we'll overshoot on the next tick and stop
	reachedX = (AkSign(params.xInc) * (GetTargetX(params) - params.Pos.Position.X - params.xInc)) < 0.01
	reachedY = (AkSign(params.yInc) * (GetTargetY(params) - params.Pos.Position.Z - params.yInc)) < 0.01

	-- Make sure we're on target point if we're close enough (correct overshoot)
	if reachedX then
		params.Pos.Position.X = GetTargetX(params)
	end
	if reachedY then
		params.Pos.Position.Z = GetTargetY(params)
	end

	AK.SoundEngine.SetListenerPosition(params.Pos, params.Listener)

	if reachedX and reachedY then
		-- We're done with this segment
		lastTargetTime = GetTargetTime(params)

		-- Setup next target if we're not done
		params.Target = params.Target + 1
		if (params.Target <= GetTargetCount(params)) then
			dt = GetTargetTime(params) - lastTargetTime
			params.xInc = (GetTargetX(params) - params.Pos.Position.X) / dt
			params.yInc = (GetTargetY(params) - params.Pos.Position.Z) / dt
		else
			-- else, this is the end of the path.
			AkUnregisterGameTickCall(params._Index)
			return
		end
	end

	-- We're not done, compute next position
	params.Pos.Position.X = params.Pos.Position.X + params.xInc
	params.Pos.Position.Z = params.Pos.Position.Z + params.yInc
end

-- Moves a listener object along the given path
-- Params:
-- ListenerID: the listener to move
-- PathArray: Array of points and timing in the form of {x, y, time}.  You must have a multiple of 3 entries in the array
-- See AkMoveListenerOnLine for an example
function AkMoveListenerOnPath(ListenerID, PathArray)		
	assert(#PathArray % 3 == 0, "PathArray must have 3 numbers per point: x, y, time")
	local listenerPos = AkListenerPosition:new_local() 
	listenerPos.OrientationFront.X = 0
	listenerPos.OrientationFront.Y = 0
	listenerPos.OrientationFront.Z = 1

	listenerPos.OrientationTop.X = 0 
	listenerPos.OrientationTop.Y = 1 -- head is up
	listenerPos.OrientationTop.Z = 0 

	--Set starting position	
	listenerPos.Position.X = PathArray[1]
	listenerPos.Position.Y = 0 
	listenerPos.Position.Z = PathArray[2] 	
	AkRegisterGameTickCall(AkMoveListenerOnPathTick,
		"Listener", ListenerID,
		"Pos", listenerPos,
		"Path", PathArray,
		"Target", 1)
end

function AkMoveListenerOnLine(ListenerID, x1, y1, x2, y2, Time)
	 local path ={
		x1,y1,0,
		x2,y2,Time}	
	AkMoveListenerOnPath(ListenerID, path)	
end

function AkMoveListenerOnArcTick(params)
	
	if (math.abs(params.Angle - params.Stop) < 0.001) then
		--Make sure we're on the target point
		params.Pos.Position.X = params.Radius * math.cos(params.Stop)
		params.Pos.Position.Z = params.Radius * math.sin(params.Stop)
		AK.SoundEngine.SetListenerPosition(params.Pos, params.Listener)
				
		--This is the end of the arc
		AkUnregisterGameTickCall(params._Index)
		return
		
	else
		params.Pos.Position.X = params.Radius * math.cos(params.Angle)
		params.Pos.Position.Z = params.Radius * math.sin(params.Angle)		
		AK.SoundEngine.SetListenerPosition(params.Pos, params.Listener)
	end
	
	--Compute next position
	params.Angle = params.Angle + params.Inc	
end

--Moves a listener on a circle arc
--Parameters
--ListenerID: the listener to move
--Radius: the radius of the arc
--StartAngle: the angle where the listener starts (front is 0, back is 180)
--StopAngle: the target angle
--Time: the time it takes to go from StartAngle to StopAngle
function AkMoveListenerOnArc(ListenerID, Radius, StartAngle, StopAngle, Time)
	--Convert degrees in radians
	StartAngle = (StartAngle-90) * math.pi / 180
	StopAngle = (StopAngle-90) * math.pi / 180
	
	local listenerPos = AkListenerPosition:new_local() 
	listenerPos.OrientationFront.X = 0
	listenerPos.OrientationFront.Y = 0
	listenerPos.OrientationFront.Z = 1

	listenerPos.OrientationTop.X = 0 
	listenerPos.OrientationTop.Y = 1 -- head is up
	listenerPos.OrientationTop.Z = 0 

	--Set starting position	
	listenerPos.Position.X = Radius * math.cos(StartAngle)
	listenerPos.Position.Y = 0 
	listenerPos.Position.Z = Radius * math.sin(StartAngle)	
	
	local increment = 1
	if AkLuaGameEngine.IsOffline() then
		increment = (StopAngle-StartAngle) / (Time/AK_AUDIOBUFFERMS)
	else
		increment = (StopAngle-StartAngle) / (Time * kFramerate / 1000)		
	end
	
	AkRegisterGameTickCall(AkMoveListenerOnArcTick,
		"Listener", ListenerID,
		"Pos", listenerPos,
		"Radius", Radius,
		"Angle", StartAngle,
		"Stop", StopAngle,
		"Inc", increment)		
end

function AkTurnListenerTick(params)
	
	if (math.abs(params.Angle - params.Stop) < 0.001) then
		--Make sure we're on the target point
		params.Pos.OrientationFront.X = math.cos(params.Stop)		
		params.Pos.OrientationFront.Z = math.sin(params.Stop)		
		AK.SoundEngine.SetListenerPosition(params.Pos, params.Listener)
				
		--This is the end of the arc
		AkUnregisterGameTickCall(params._Index)
		return		
	else
		params.Pos.OrientationFront.X = math.cos(params.Angle)
		params.Pos.OrientationFront.Z = math.sin(params.Angle)		
		AK.SoundEngine.SetListenerPosition(params.Pos, params.Listener)
	end
	
	--Compute next position
	params.Angle = params.Angle + params.Inc	
end

--Rotates the orientation of a listener
--Parameters
--ListenerID: the listener to move
--StartAngle: the angle where the listener starts (front is 0, back is 180)
--StopAngle: the target angle
--Time: the time it takes to go from StartAngle to StopAngle
function AkTurnListener(ListenerID, StartAngle, StopAngle, Time)
	--Convert degrees in radians
	StartAngle = (StartAngle+90) * math.pi / 180
	StopAngle = (StopAngle+90) * math.pi / 180
	
	local listenerPos = AkListenerPosition:new_local() 
	listenerPos.OrientationFront.X = math.cos(StartAngle)
	listenerPos.OrientationFront.Y = 0
	listenerPos.OrientationFront.Z = math.sin(StartAngle)

	listenerPos.OrientationTop.X = 0 
	listenerPos.OrientationTop.Y = 1 -- head is up
	listenerPos.OrientationTop.Z = 0 

	--Set starting position	
	listenerPos.Position.X = 0
	listenerPos.Position.Y = 0 
	listenerPos.Position.Z = 0
	
	local increment = 1
	if AkLuaGameEngine.IsOffline() then
		increment = (StopAngle-StartAngle) / (Time/AK_AUDIOBUFFERMS)
	else
		increment = (StopAngle-StartAngle) / (Time * kFramerate / 1000)		
	end
	
	AkRegisterGameTickCall(AkTurnListenerTick,
		"Listener", ListenerID,
		"Pos", listenerPos,		
		"Angle", StartAngle,
		"Stop", StopAngle,
		"Inc", increment)	
end

function AkMoveGameObjectOnPathTick(params)	
	
	function GetX(in_params)			
		return in_params.Path[(in_params.Target-1) *3 + 1]
	end
	function GetY(in_params)
		return in_params.Path[(in_params.Target-1) *3 + 2]
	end
	function GetNbFrames(in_params)
		if AkLuaGameEngine.IsOffline() then
			return in_params.Path[(in_params.Target-1) *3 + 3] / AK_AUDIOBUFFERMS
		else
			return in_params.Path[(in_params.Target-1) *3 + 3] * kFramerate/ 1000
		end		
	end	
	
	if (params.xInc == nil or math.abs(params.Pos.Position.X - GetX(params, params.Target)) < math.abs(params.xInc)) then
		--Make sure we're on the target point
		params.Pos.Position.X = GetX(params)
		params.Pos.Position.Z = GetY(params)
		params.SetPositionFcn(params.GameObject, params.Pos)
		
		--We have finished this segment of the path.  Compute the next segment		
		params.Target = params.Target + 1
		if (params.Target > table.maxn(params.Path) / 3) then
			--This is the end of the path.  
			AkUnregisterGameTickCall(params._Index)
			return
		end
		
		params.xInc = (GetX(params) - params.Pos.Position.X) / GetNbFrames(params)
		params.yInc = (GetY(params) - params.Pos.Position.Z) / GetNbFrames(params)
	else
		params.SetPositionFcn(params.GameObject, params.Pos)
	end
	
	
	--Compute next position
	params.Pos.Position.X = params.Pos.Position.X + params.xInc
	params.Pos.Position.Z = params.Pos.Position.Z + params.yInc
end

function AkMoveGameObjectOnPathTick3D(params)	
	
	function GetX(in_params)			
		return in_params.Path[(in_params.Target-1) *4 + 1]
	end
	function GetY(in_params)
		return in_params.Path[(in_params.Target-1) *4 + 2]
	end
	function GetZ(in_params)
		return in_params.Path[(in_params.Target-1) *4 + 3]
	end
	function GetNbFrames(in_params)
		if AkLuaGameEngine.IsOffline() then
			return in_params.Path[(in_params.Target-1) *4 + 4] / AK_AUDIOBUFFERMS
		else
			return in_params.Path[(in_params.Target-1) *4 + 4] * kFramerate/ 1000
		end		
	end	
	
	if (params.xInc == nil or math.abs(params.Pos.Position.X - GetX(params, params.Target)) < math.abs(params.xInc)) then
		--Make sure we're on the target point
		params.Pos.Position.X = GetX(params)
		params.Pos.Position.Y = GetY(params)
		params.Pos.Position.Z = GetZ(params)
		params.SetPositionFcn(params.GameObject, params.Pos)
		
		--We have finished this segment of the path.  Compute the next segment		
		params.Target = params.Target + 1
		if (params.Target > table.maxn(params.Path) / 4) then
			--This is the end of the path.  
			AkUnregisterGameTickCall(params._Index)
			return
		end
		
		params.xInc = (GetX(params) - params.Pos.Position.X) / GetNbFrames(params)
		params.yInc = (GetY(params) - params.Pos.Position.Y) / GetNbFrames(params)
		params.zInc = (GetZ(params) - params.Pos.Position.Z) / GetNbFrames(params)
	else
		params.SetPositionFcn(params.GameObject, params.Pos)
	end
	
	--Compute next position
	params.Pos.Position.X = params.Pos.Position.X + params.xInc
	params.Pos.Position.Y = params.Pos.Position.Y + params.yInc
	params.Pos.Position.Z = params.Pos.Position.Z + params.zInc
end

-- Moves a GameObject object along the given path
-- Params:
-- PathArray: Array of points and timing in the form of {x, y, time}.  You must have a multiple of 3 entries in the array
-- GameObjectID: the GameObject to move (optional.  Default is g_AkDefaultObject)
-- See AkMoveGameObjectOnLine for an example
function AkMoveGameObjectOnPath(PathArray, GameObjectID)	
	assert(#PathArray % 3 == 0, "PathArray must have 3 numbers per point: x, y, time")
	local GameObjectPos = AkSoundPosition:new_local() 
	GameObjectPos.Orientation.X = 0
	GameObjectPos.Orientation.Y = 0
	GameObjectPos.Orientation.Z = 1

	--Set starting position	
	GameObjectPos.Position.X = PathArray[1]
	GameObjectPos.Position.Y = 0 
	GameObjectPos.Position.Z = PathArray[2] 	
	
	if ( GameObjectID == nil ) then		
		GameObjectID = g_AkDefaultEmitter
	end
	
	AkRegisterGameTickCall(AkMoveGameObjectOnPathTick,
		"SetPositionFcn", AK.SoundEngine.SetPosition,
		"GameObject", GameObjectID,
		"Pos", GameObjectPos,
		"Path", PathArray,
		"Target", 1)
end

function AkMoveGameObjectOnLine(x1, y1, x2, y2, Time, GameObjectID)
	 local path ={
		x1,y1,0,
		x2,y2,Time}	
	AkMoveGameObjectOnPath(path, GameObjectID)	
end

function AkMoveSpatialAudioObjectOnLine(x1, y1, x2, y2, Time, GameObjectID)
	 local path ={
		x1,y1,0,
		x2,y2,Time}	
	AkMoveGameObjectOnPath(path, GameObjectID)	
end

function AkMoveSpatialAudioObjectOnLine3D(x1, y1, z1, x2, y2, z2, Time, GameObjectID)
	 local path ={
		x1,y1,z1,0,
		x2,y2,z2,Time}	
	AkMoveSpatialAudioObjectOnPath3D(path, GameObjectID)	
end

function AkMoveGameObjectOnArcTick(params)
	
	if (math.abs(params.Angle - params.Stop) < 0.001) then
		--Make sure we're on the target point
		params.Pos.Position.X = params.Radius * math.cos(params.Stop)
		params.Pos.Position.Z = params.Radius * math.sin(params.Stop)
		AK.SoundEngine.SetPosition(params.GameObject, params.Pos)
				
		--This is the end of the arc
		AkUnregisterGameTickCall(params._Index)
		return
		
	else
		params.Pos.Position.X = params.Radius * math.cos(params.Angle)
		params.Pos.Position.Z = params.Radius * math.sin(params.Angle)		
		AK.SoundEngine.SetPosition(params.GameObject, params.Pos)
	end
	
	--Compute next position
	params.Angle = params.Angle + params.Inc	
end

--Moves a GameObject on a circle arc
--Parameters
--Radius: the radius of the arc
--StartAngle: the angle where the GameObject starts (front is 0, back is 180)
--StopAngle: the target angle
--Time: the time it takes to go from StartAngle to StopAngle
-- GameObjectID: the GameObject to move (optional.  Default is g_AkDefaultObject)
function AkMoveGameObjectOnArc(Radius, StartAngle, StopAngle, Time, GameObjectID)

	if ( GameObjectID == nil ) then
		GameObjectID = g_AkDefaultEmitter
	end
	
	--Convert degrees in radians
	StartAngle = (StartAngle-90) * math.pi / 180
	StopAngle = (StopAngle-90) * math.pi / 180
	
	local GameObjectPos = AkSoundPosition:new_local() 
	GameObjectPos.Orientation.X = 0
	GameObjectPos.Orientation.Y = 0
	GameObjectPos.Orientation.Z = 1	

	--Set starting position	
	GameObjectPos.Position.X = Radius * math.cos(StartAngle)
	GameObjectPos.Position.Y = 0 
	GameObjectPos.Position.Z = Radius * math.sin(StartAngle)

	local increment = 1
	if AkLuaGameEngine.IsOffline() then
		increment = (StopAngle-StartAngle) / (Time/AK_AUDIOBUFFERMS)
	else
		increment = (StopAngle-StartAngle) / (Time * kFramerate / 1000)		
	end	
	
	AkRegisterGameTickCall(AkMoveGameObjectOnArcTick,
		"GameObject", GameObjectID,
		"Pos", GameObjectPos,
		"Radius", Radius,
		"Angle", StartAngle,
		"Stop", StopAngle,
		"Inc", increment)		
end

function AkTurnGameObjectTick(params)
	
	if (math.abs(params.Angle - params.Stop) < 0.001) then
		--Make sure we're on the target point
		params.Pos.Orientation.X = math.cos(params.Stop)		
		params.Pos.Orientation.Z = math.sin(params.Stop)		
		AK.SoundEngine.SetPosition(params.GameObject, params.Pos)
				
		--This is the end of the arc
		AkUnregisterGameTickCall(params._Index)
		return		
	else
		params.Pos.Orientation.X = math.cos(params.Angle)
		params.Pos.Orientation.Y = math.sin(params.Angle)		
		AK.SoundEngine.SetPosition(params.GameObject, params.Pos)
	end
	
	--Compute next position
	params.Angle = params.Angle + params.Inc	
end

--Rotates the orientation of a GameObject
--Parameters
--StartAngle: the angle where the GameObject starts (front is 0, back is 180)
--StopAngle: the target angle
--Time: the time it takes to go from StartAngle to StopAngle
-- GameObjectID: the GameObject to move (optional.  Default is g_AkDefaultObject)
function AkTurnGameObject(StartAngle, StopAngle, Time, GameObjectID)
	
	if ( GameObjectID == nil ) then
		GameObjectID = g_AkDefaultEmitter
	end
	
	--Convert degrees in radians
	StartAngle = (StartAngle-90) * math.pi / 180
	StopAngle = (StopAngle-90) * math.pi / 180
	
	local GameObjectPos = AkSoundPosition:new_local() 
	GameObjectPos.Orientation.X = math.cos(StartAngle)
	GameObjectPos.Orientation.Y = 0
	GameObjectPos.Orientation.Z = math.sin(StartAngle)

	--Set starting position	
	GameObjectPos.Position.X = 0
	GameObjectPos.Position.Y = 0 
	GameObjectPos.Position.Z = 0
	
	local increment = 1
	if AkLuaGameEngine.IsOffline() then
		increment = (StopAngle-StartAngle) / (Time/AK_AUDIOBUFFERMS)
	else
		increment = (StopAngle-StartAngle) / (Time * kFramerate / 1000)		
	end
	
	AkRegisterGameTickCall(AkTurnGameObjectTick,
		"GameObject", GameObjectID,
		"Pos", GameObjectPos,		
		"Angle", StartAngle,
		"Stop", StopAngle,
		"Inc", increment)	
end

-- PRIVATE
-- Required by AkWaitUntilEventIsFinished
function AkHandleEndOfEventCallback( in_callbackType, in_data )
	if (in_callbackType == AK_EndOfEvent) then
		g_eventFinished = true
    end
end

-- Wait until an event fired with appropriate EndOfEvent callback
-- Often to be used in conjunction with  AkPlayEventUntilDone
function AkWaitUntilEventIsFinished()
	g_waitTicks = 10000
	g_eventFinished = false
	while( not( g_eventFinished )) do
		if ( AkLuaGameEngine.IsOffline()) then
			AkGameTick()
		else
			coroutine.yield()
		end
		g_waitTicks = g_waitTicks - 1
		if (g_waitTicks == 0) then
			print( "*** ERROR AkWaitUntilEventIsFinished(): Timed out waiting for event to finish!" )
			break
		end
	end
end

function AkMarkerCallBackFunction( in_callbackType, in_data )    	
	if in_callbackType == AK_Marker then
		if in_data.strLabel ~= nil then
			LogTestMsg( in_data.strLabel )
		end
	end
	if (in_callbackType == AK_EndOfEvent) then
		g_eventFinished = true
    end
end

function MarkerCallbackDefault(in_data)
	if in_data.strLabel ~= nil then
		print( string.format( "Identifier: %s, position: %s, label: %s", in_data.uIdentifier, in_data.uPosition, in_data.strLabel ) )
	else
		print( string.format( "Identifier: %s, position: %s, label: %s", in_data.uIdentifier, in_data.uPosition ) )
	end
end

function DurationDefault(in_data)
	print( string.format( "Duration is: %f, Estimated Duration is: %f", in_data.fDuration , in_data.fEstimatedDuration ) )
end

function GetSrcPosDefault(in_data)
	local result
	local sourcePosition = 0
	result, sourcePosition	= AK.SoundEngine.GetSourcePlayPosition( in_data.playingID, sourcePosition )
	if( result == AK_Success ) then
		print( string.format( "Source position: %s", sourcePosition ) )
	end
end

g_OverridenCallbacks = 
{
	MarkerCB = MarkerCallbackDefault,
	EndOfEventCB = nil,
	DurationCB = DurationDefault,
	GetSrcPos = nil,
}

function AkGenericCallbackFunction( in_callbackType, in_data )
	if in_callbackType == AK_Marker and g_OverridenCallbacks.MarkerCB ~= nil then
		g_OverridenCallbacks.MarkerCB(in_data)
	elseif in_callbackType == AK_Duration and g_OverridenCallbacks.DurationCB ~= nil then
		g_OverridenCallbacks.DurationCB(in_data)
	else		
		g_eventFinished = true		
		if g_OverridenCallbacks.EndOfEventCB ~= nil then		
			g_OverridenCallbacks.EndOfEventCB(in_data)
		end
    end
	
	if g_OverridenCallbacks.GetSrcPos ~= nil then
		g_OverridenCallbacks.GetSrcPos(in_data)
	end
end

function IsBitSet(mask, singlebitmask)		
	local div = mask / singlebitmask 
	return (div >= 1) and not (div >= 2)
end

function BitOr(A, B)
	if not IsBitSet(A,B) then return A + B end
	return A
end

--Naming function for the AkPlay routine.  (See GetTestNameFromParams for rules)
function AkPlayNaming(in_Options)	
	if type(in_Options[1]) == "string" then		
		return in_Options[1]
	end	
	return in_Options.Event or in_Options[1][1]
end

--[[
AkPlay will play a sound to its end.  Optionally, it can print pre & post messages and call all the callbacks during the playback.
If your test only need a PostEvent call, use this.

AkPlay takes EITHER a string or a table as parameters
AkPlay("MyEvent") will simply call PostEvent("MyEvent") and wait for the end. Calling without the accolades is sugar only, it can only work if the event name is the sole parameter.
AkPlay({"MyEvent"}) is equivalent
AkPlay({Event="MyEvent"}) is equivalent

It is mandatory to have an event name by one of these methods.

Other parameters are optional and must be in table form
- GameObject: Specify the game object to play on.  Ex: AkPlay( {Event="MyEvent", GameObject=2} ) 
- WaitTime: Specify a different timeout for finishing playback.  Default is 30 seconds. Ex: AkPlay( {Event="MyEvent", WaitTime=12000} ) 
- Comment: Prints a comment at the begining of the test. Useful to explain what to expect. Ex AkPlay( {Event="MyEvent", Comment="This is my test!"} ) 
- CommentEnd: Prints a comment at the end of the test.
- PostEventFlags: The AK_Callback flags AK_Marker, AK_Duration, AK_EnableGetSourcePlayPosition, AK_EndOfEvent, combined.  AK_EndOfEvent is always added regardless, you don't need to specify it
- MarkerCB: Marker callback function (not the name, the function itself). By default adding AK_Marker will print all markers and their position. No need to override if it is the only thing you do.
- EndOfEventCB: EndOfEvent callback function. Override if you need to do something else than wait the end.
- DurationCB: Duration callback. No default behavior.
- GetSrcPosCB: If AK_EnableGetSourcePlayPosition is set, this will get called for ANY of the callbacks. By default setting AK_EnableGetSourcePlayPosition will call GetSourcePlayPosition and print the position. Override only if you need to do something else.

This is lua, the order of the parameters in the table don't matter.
Ex: AkPlay( {Comment="This is my test!", Event="MyEvent", MarkerCB=MyMarkerFunc, PostEventFlags=AK_Marker} ) 

The AkPlay helper has a Naming function (above this comment). By default, the name of the test will be the name of the Event.
To have a different name, override the function, as explained in GetTestNameFromParams.
--]]

function AkPlay(in_Options)
	g_eventFinished = false
	
	--Fill default values
	local GO = g_AkDefaultEmitter
	local waitTime = 30000
	local CBFlags = AK_EndOfEvent
	local comment
	local commentEnd
		
	--Either use the named parameter, or the first, for the event name
	local event
	if type(in_Options) == "string" then	--Support simplest syntax AkPlay("MyEvent")
		event = in_Options	
	else		
		--Apply caller overrides	
		GO = in_Options.GameObject or g_AkDefaultEmitter
		waitTime = in_Options.WaitTime or 30000
		CBFlags = BitOr((in_Options.PostEventFlags or 0), AK_EndOfEvent)
		comment = in_Options.Comment
		commentEnd = in_Options.CommentEnd
		event = in_Options.Event or in_Options[1]	--Event doesn't have to be named, it can be first too.
		
		g_OverridenCallbacks.MarkerCB = in_Options.MarkerCB or MarkerCallbackDefault
		if in_Options.MarkerCB ~= nil then 
			BitOr(CBFlags, AK_Marker) 
		end
		
		g_OverridenCallbacks.EndOfEventCB = in_Options.EndOfEventCB
		
		g_OverridenCallbacks.DurationCB = in_Options.DurationCB or DurationDefault
		if in_Options.DurationCB ~= nil then 
			BitOr(CBFlags, AK_Duration) 
		end
		
		if in_Options.GetSrcPosCB ~= nil then 
			BitOr(CBFlags, AK_EnableGetSourcePlayPosition) 
		end		
		if IsBitSet(CBFlags, AK_EnableGetSourcePlayPosition) then
			g_OverridenCallbacks.GetSrcPos = in_Options.GetSrcPosCB or GetSrcPosDefault
		else
			g_OverridenCallbacks.GetSrcPos = nil
		end
	end
	
	--Play!
	if comment ~= nil then
		LogTestMsg(comment, 1)
	end
		
	local playingID = AK.SoundEngine.PostEvent(event, GO, CBFlags, "AkGenericCallbackFunction", 0)
	if( playingID ~= AK_INVALID_PLAYING_ID ) then
		Wait(waitTime, "g_eventFinished")
		if commentEnd ~= nil then
			LogTestMsg(commentEnd,1)
		end
	else
		LogTestMsg("Error posting " .. event,1)
	end
	return playingID
end

-- Wait until an event fired with appropriate EndOfEvent callback, but wait for a maximum of X millisecond
-- in_delayTime: Maximum time the function waits (in milliseconds)
function AkWaitUntilEventIsFinishedMaxDuration(in_delayTime)  
	g_eventFinished = false
	if ( not AK_LUA_RELEASE ) and ( AkLuaGameEngine.IsOffline() ) then		
		local numIter = in_delayTime/AK_AUDIOBUFFERMS				
		while (( numIter > 0 ) and (not( g_eventFinished ))) do			
			numIter = numIter - 1
			InternalGameTick()
		end
	else
		testStartTime = os.gettickcount()
		while(( os.gettickcount() - testStartTime < in_delayTime ) and (not( g_eventFinished ))) do
			if ( AkLuaGameEngine.IsOffline()) then
				AkGameTick()
			else
				coroutine.yield()
			end
		end
	end
end

-- Playback of an event using the end of event callback to block process until the event has finished playing
-- Parameters: 
-- PlayEventName: the name of the playback event to trigger
-- GameObj: the gameobject id, automatically registering and unregistering default game object if not specified
-- in_maxDuration: default is nil, the maximum time it waits (in milliseconds)
function AkPlayEventUntilDone( in_PlayEventName, in_GameObj, in_maxDuration )
	-- Default values
	in_GameObj = in_GameObj or g_AkDefaultEmitter
	
	playingID = AK.SoundEngine.PostEvent(in_PlayEventName, in_GameObj, AK_EndOfEvent,"AkHandleEndOfEventCallback",0)
	if( playingID ~= AK_INVALID_PLAYING_ID ) then
		if( in_maxDuration == nil ) then
			AkWaitUntilEventIsFinished()
		else
			AkWaitUntilEventIsFinishedMaxDuration( in_maxDuration )
			AK.SoundEngine.ExecuteActionOnEvent( in_PlayEventName, AkActionOnEventType_Stop, in_GameObj, 0, AkCurveInterpolation_Linear )
			Wait(100)
		end
	else
		LogTestMsg("AK.SoundEngine.PostEvent failed for event:" .. in_PlayEventName,1)
	end
end


-- Playback of an event for a certain duration while activating the sound engine capture output function
-- Parameters: 
-- PlayEventName: the name of the playback event to trigger
-- WAVfilename: Name of the WAV file to capture
-- GameObj: the gameobject id, automatically registering and unregistering default game object if not specified
function AkPlayAndRecordWAV( in_PlayEventName, in_WAVfilename, in_GameObj )
	if ( in_GameObj == nil ) then
		in_GameObj = g_AkDefaultEmitter
	end
	AkStartOutputCapture( in_WAVfilename )
	local playingID = AK.SoundEngine.PostEvent(in_PlayEventName, in_GameObj, AK_EndOfEvent,"AkHandleEndOfEventCallback",0)
	if (playingID ~= AK_INVALID_PLAYING_ID) then
		AkWaitUntilEventIsFinished()
	else
		LogTestMsg("AK.SoundEngine.PostEvent failed for event:" .. in_PlayEventName,1)
	end
	AkStopOutputCapture( )
end

-- Playback of an event for a certain duration
-- Parameters: 
-- PlayEventName: the name of the playback event to trigger
-- Duration: Time (in ms) to play the sound for
-- GameObj: the gameobject id, automatically registering and unregistering default game object if not specified
function AkPlayForDuration( in_PlayEventName, in_Duration, in_GameObj )
	if ( in_GameObj == nil ) then
		in_GameObj = g_AkDefaultEmitter
	end
	AK.SoundEngine.PostEvent(in_PlayEventName, in_GameObj)
	Wait( in_Duration )
	AK.SoundEngine.ExecuteActionOnEvent( in_PlayEventName, AkActionOnEventType_Stop, in_GameObj, 0, AkCurveInterpolation_Linear )
end

-- Wraps an event in performance monitoring calls and dump performance metrics
-- Parameters: 
-- PlayEventName: the name of the playback event to trigger
-- PerfBenchMetricName: Name of the metrics statistic to output 
-- Duration: Time (in ms) to play the sound for
-- GameObj: the gameobject id, automatically registering and unregistering default game object if not specified
function AkPerfBenchEvent( in_PlayEventName, in_PerfBenchMetricName, in_Duration, in_GameObj )
	if ( in_GameObj == nil ) then
		in_GameObj = g_AkDefaultEmitter
	end
	AK.SoundEngine.PostEvent(in_PlayEventName, in_GameObj)
	Wait(1000)
	AkLuaGameEngine.StartPerfMon()
	Wait( in_Duration )
	AkLuaGameEngine.StopPerfMon()
	AkLuaGameEngine.DumpMetrics( in_PerfBenchMetricName )
	Wait(1000)
	AK.SoundEngine.StopAllObsolete()
end

-- Playback of a given number of instances of an event for a certain duration
-- Parameters: 
-- PlayEventName: the name of the playback event to trigger
-- PerfBenchMetricName: Name of the metrics statistic to output 
-- Duration: Time (in ms) to play the sound for
-- NumberOfEventsToPost: Repeat event this many times on same game object
-- GameObj: the gameobject id, automatically registering and unregistering default game object if not specified
function AkPlayNEventsForDuration( in_PlayEventName, in_Duration, in_NumberOfEventsToPost, in_GameObj )
	if ( in_GameObj == nil ) then
		in_GameObj = g_AkDefaultEmitter
	end
	for i = 0, in_NumberOfEventsToPost-1 do		
		AK.SoundEngine.PostEvent(in_PlayEventName, in_GameObj)
	end	
	Wait( in_Duration )
	AK.SoundEngine.ExecuteActionOnEvent( in_PlayEventName, AkActionOnEventType_Stop, AK_INVALID_GAME_OBJECT, 0, AkCurveInterpolation_Linear )
end

function AkGetCombinationString(...)
	local str = ""
	for n=1,select('#',...) do
		str = str .. "_" .. tostring(select(n,...))
	end	
	return str
end

--This table contains all routine entries with their names and parameters 
g_TestTable = {}

--[[
	--Generate the array of tests with the given variables and routines.
	--Define all your variables and their possibilities.
	--They can be strings, numbers or any other lua type you wish.
	g_ChannelsPossibilities = {"0_1", "1_0", "1_1", "2_0", "2_1", "4_0", "5_1"}
	g_TypePossibilities = {"SFX", "Music"}

	--Define your test functions that will be called as coroutines
	--They must have one parameter.  This parameter is an array for all the variables you defined (Channels and Type in this example)
	function StartVirtualTest(inVariables)
		local inChannels = inVariables[1]	-- the Channels is the first item because we put it first in AkGenerateRoutinesWithPermutations
		local inType = inVariables[2]		-- the Type is the second item because we put it second in AkGenerateRoutinesWithPermutations
		
		print("StartVirtualTest "..AkGetCombinationString(inVariables))
	end	

	function BecomeVirtualTest(inVariables)
		local inChannels = inVariables[1]	-- the Channels is the first item because we put it first in AkGenerateRoutinesWithPermutations
		local inType = inVariables[2]		-- the Type is the second item because we put it second in AkGenerateRoutinesWithPermutations
		
		print("BecomeVirtualTest"..AkGetCombinationString(inVariables))
	end	

	--Call AkGenerateRoutinesWithPermutations
	AkGenerateRoutinesWithPermutations(g_ChannelsPossibilities, g_TypePossibilities, StartVirtualTest, BecomeVirtualTest)	
	--Could also be written this way:
	--AkGenerateRoutinesWithPermutations({"0_1", "1_0", "1_1", "2_0", "2_1", "4_0", "5_1"}, {"SFX", "Music"}, StartVirtualTest, BecomeVirtualTest)	
	--This will generate 28 CoRoutines.  StartVirtualTest and BecomeVirtualTest will be called for each permutation of the parameters (7 channels and SFX or Music)
	
	By default, the name of the test routine will be the function name plus all parameters separated by underscores, like this:
	StartVirtualTest_0_1_SFX, BecomeVirtualTest_0_1_SFX, StartVirtualTest_0_1_Music, etc
	
	The name generation can be overriden, see the function GetTestNameFromParams.
--]]
function AkGenerateRoutinesWithPermutations(...)

	local Combinations = {}
	Combinations.Variables = {}
	Combinations.Routines = {}	
	
	local expected = 1	--Compute how many calls we will do	
	
	--Go through all the parameters and sort them between the Variables and Routines
	for n=1,select('#',...) do
		local param = select(n,...)
		if param ~= nil then
			if type(param) == "function" then
				table.insert(Combinations.Routines, param)
			else
				table.insert(Combinations.Variables, param)
				Combinations.Variables[#Combinations.Variables].Counter = 1	--Init the counter to the first possibility			
				expected = expected * #Combinations.Variables[#Combinations.Variables] --Compute how many calls we will do
			end
		end
	end
		
	expected = expected * #Combinations.Routines
			
	local finished = 0
	--Always increment the last variable first
	
	while(finished < expected) do
		--Build the parameter array with all the current values		
		local values = {}
		for var=1, #Combinations.Variables do		
			local varTable = Combinations.Variables[var]
			values[var] = varTable[varTable.Counter]			
		end
		for routine=1,#Combinations.Routines do		
			finished = finished + 1			
			
			--Create a test routine entry (see CoHandleTests and TransformTestArray for the structure)
			local entry = {}
			entry.Name = GetTestNameFromParams(Combinations.Routines[routine], values)
			entry.Func = Combinations.Routines[routine]
			entry.Params = values			
			table.insert(g_TestTable, entry)
		end
					
		--Find the next permutation
		--Always increment the last variable first		
		local lastIndex = #Combinations.Variables		
		local currentVar = Combinations.Variables[lastIndex]
		currentVar.Counter = currentVar.Counter + 1	
		while lastIndex > 1 and currentVar.Counter > #currentVar do						
			--Reached the last possibility on that variable.  Go to next variable and restart
			currentVar.Counter = 1
			lastIndex = lastIndex - 1						
			currentVar = Combinations.Variables[lastIndex]	
			currentVar.Counter = currentVar.Counter + 1			
		end	
	end	
end

-- ****************
-- Global variables: overwrite these in your Lua script if you want to use other values
-- ****************
-- Tables to remember button presses
kButtonsCurrentlyDown = { }

-- Desired framerate (frames/s)
kFramerate = 30

-- Leave time to connect to Wwise?
kConnectToWwise = true
kTimeToConnect = 5000 -- milliseconds

-- **********************************************************************
-- Global stuff.  This section is always executed.
-- **********************************************************************

-- Functions can automatically register/unregister game object if not specified
g_AkDefaultEmitter = 999999999
g_AkDefaultListener = 999999998

-- initialize g_testName only if not nitialized in main test script. This is done in order not to break old scripts.
if g_testName == nil then
	g_testName = {}	
end

-- **********************************************************************
-- This dictionary is needed for the QA automated tests to work properly.
-- **********************************************************************

--Platform string name dictionary
if AK_PLATFORM_PC then
kButtonNameMapping = 
{ 
AK_GAMEPAD_BUTTON_01 = "1 / A",
AK_GAMEPAD_BUTTON_02 = "2 / B", 
AK_GAMEPAD_BUTTON_03 = "3 / X", 
AK_GAMEPAD_BUTTON_04 = "4 / Y", 
AK_GAMEPAD_BUTTON_05 = "5 / Left shoulder", 
AK_GAMEPAD_BUTTON_06 = "6 / Right shoulder", 
AK_GAMEPAD_BUTTON_07 = "7 / Back", 
AK_GAMEPAD_BUTTON_08 = "8 / Start", 
AK_GAMEPAD_BUTTON_09 = "9 / Left thumb down", 
AK_GAMEPAD_BUTTON_10 = "0 / Right thumb down", 
AK_GAMEPAD_BUTTON_11 = "F1 / Directional pad up", 
AK_GAMEPAD_BUTTON_12 = "F2 / Directional pad right", 
AK_GAMEPAD_BUTTON_13 = "F3 / Directional pad down", 
AK_GAMEPAD_BUTTON_14 = "F4 / Directional pad left", 
AK_GAMEPAD_BUTTON_15 = "F5 / 'N/A'", 
AK_GAMEPAD_BUTTON_16 = "F6 / 'N/A'",
AK_HOME_BUTTON = "Home",
AK_GAMEPAD_ANALOG_01 = "Left thumb X axis",
AK_GAMEPAD_ANALOG_02 = "Left thumb Y axis",
AK_GAMEPAD_ANALOG_03 = "Left Trigger(+)",
AK_GAMEPAD_ANALOG_04 = "Right thumb X axis",
AK_GAMEPAD_ANALOG_05 = "Right thumb Y axis",
AK_GAMEPAD_ANALOG_06 = "Right Trigger(-)",
AK_GAMEPAD_ANALOG_07 = "'N/A'",
AK_GAMEPAD_ANALOG_08 = "'N/A'",
AK_GAMEPAD_ANALOG_09 = "'N/A'",
VK_SPACE = "Space", --Already used in: "NextPreviousRepeat", "SmartPause" & "AskAttendedMode".
VK_RETURN = "Return", --Already used in: "NextPreviousRepeat" & "AskAttendedMode".
VK_ESCAPE = "Esc",  --Already used in: "CoEndOfTest" and "NextPreviousRepeat".
VK_LEFT = "Left", --Already used in: "NextPreviousRepeat".
VK_RIGHT = "Right", --Already used in: "NextPreviousRepeat".
VK_UP = "Up",
VK_DOWN = "Down",
}
elseif AK_PLATFORM_MAC then
kButtonNameMapping = 
{ 
AK_GAMEPAD_BUTTON_01 = "1 / A",
AK_GAMEPAD_BUTTON_02 = "2 / B", 
AK_GAMEPAD_BUTTON_03 = "3 / X", 
AK_GAMEPAD_BUTTON_04 = "4 / Y", 
AK_GAMEPAD_BUTTON_05 = "5 / Left shoulder", 
AK_GAMEPAD_BUTTON_06 = "6 / Right shoulder", 
AK_GAMEPAD_BUTTON_07 = "7 / Back", 
AK_GAMEPAD_BUTTON_08 = "8 / Start", 
AK_GAMEPAD_BUTTON_09 = "9 / Left thumb down", 
AK_GAMEPAD_BUTTON_10 = "0 / Right thumb down", 
AK_GAMEPAD_BUTTON_11 = "F1 / Directional pad up", 
AK_GAMEPAD_BUTTON_12 = "F2 / Directional pad right", 
AK_GAMEPAD_BUTTON_13 = "F3 / Directional pad down", 
AK_GAMEPAD_BUTTON_14 = "F4 / Directional pad left", 
AK_GAMEPAD_BUTTON_15 = "F5 / 'N/A'", 
AK_GAMEPAD_BUTTON_16 = "F6 / 'N/A'",
AK_HOME_BUTTON = "Home",
AK_GAMEPAD_ANALOG_01 = "Left thumb X axis",
AK_GAMEPAD_ANALOG_02 = "Left thumb Y axis",
AK_GAMEPAD_ANALOG_03 = "Left Trigger(+)",
AK_GAMEPAD_ANALOG_04 = "Right thumb X axis",
AK_GAMEPAD_ANALOG_05 = "Right thumb Y axis",
AK_GAMEPAD_ANALOG_06 = "Right Trigger(-)",
AK_GAMEPAD_ANALOG_07 = "'N/A'",
AK_GAMEPAD_ANALOG_08 = "'N/A'",
AK_GAMEPAD_ANALOG_09 = "'N/A'",
VK_SPACE = "Space", --Already used in: "NextPreviousRepeat", "SmartPause" & "AskAttendedMode".
VK_RETURN = "Return", --Already used in: "NextPreviousRepeat" & "AskAttendedMode".
VK_ESCAPE = "Esc",  --Already used in: "CoEndOfTest" and "NextPreviousRepeat".
VK_LEFT = "Left", --Already used in: "NextPreviousRepeat".
VK_RIGHT = "Right", --Already used in: "NextPreviousRepeat".
VK_UP = "Up",
VK_DOWN = "Down",
}

elseif( AK_PLATFORM_XBOX ) then

kButtonNameMapping = 
{ 
AK_GAMEPAD_BUTTON_01 = "A", --Already used in: "NextPreviousRepeat", "SmartPause" & "AskAttendedMode".
AK_GAMEPAD_BUTTON_02 = "B", --Already used in: "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_03 = "X", --Already used in: "NextPreviousRepeat" & "AskAttendedMode".
AK_GAMEPAD_BUTTON_04 = "Y", --Already used in: "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_05 = "Left shoulder",
AK_GAMEPAD_BUTTON_06 = "Right shoulder",
AK_GAMEPAD_BUTTON_07 = "Left trigger",
AK_GAMEPAD_BUTTON_08 = "Right trigger",
AK_GAMEPAD_BUTTON_09 = "Back",
AK_GAMEPAD_BUTTON_10 = "Start", --Already used in: "CoEndOfTest" and "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_11 = "Directional pad up",
AK_GAMEPAD_BUTTON_12 = "Directional pad right",
AK_GAMEPAD_BUTTON_13 = "Directional pad down",
AK_GAMEPAD_BUTTON_14 = "Directional pad left",
AK_GAMEPAD_BUTTON_15 = "Left thumb down",
AK_GAMEPAD_BUTTON_16 = "Right thumb down",
AK_HOME_BUTTON = "N/A",
AK_GAMEPAD_ANALOG_01 = "Left thumb X axis",
AK_GAMEPAD_ANALOG_02 = "Left thumb Y axis",
AK_GAMEPAD_ANALOG_03 = "Right thumb X axis",
AK_GAMEPAD_ANALOG_04 = "Right thumb Y axis",
AK_GAMEPAD_ANALOG_05 = "Left trigger value",
AK_GAMEPAD_ANALOG_06 = "Right trigger value",
AK_GAMEPAD_ANALOG_07 = "N/A",
AK_GAMEPAD_ANALOG_08 = "N/A",
AK_GAMEPAD_ANALOG_09 = "N/A"
}

elseif( AK_PLATFORM_IOS or AK_PLATFORM_ANDROID or AK_PLATFORM_LINUX or AK_PLATFORM_GGP ) then

kButtonNameMapping = 
{ 
AK_GAMEPAD_BUTTON_01 = 	"A",
AK_GAMEPAD_BUTTON_02 = 	"B",
AK_GAMEPAD_BUTTON_03 = 	"X",
AK_GAMEPAD_BUTTON_04 = 	"Y",
AK_GAMEPAD_BUTTON_05 = 	"'N/A'",
AK_GAMEPAD_BUTTON_06 = 	"'N/A'",
AK_GAMEPAD_BUTTON_07 = 	"'N/A'",
AK_GAMEPAD_BUTTON_08 = 	"'N/A'",
AK_GAMEPAD_BUTTON_09 = 	"Select",
AK_GAMEPAD_BUTTON_10 = 	"Start",
AK_GAMEPAD_BUTTON_11 = 	"Directional pad up", 
AK_GAMEPAD_BUTTON_12 = 	"Directional pad right",
AK_GAMEPAD_BUTTON_13 = 	"Directional pad down", 
AK_GAMEPAD_BUTTON_14 = 	"Directional pad left", 
AK_GAMEPAD_BUTTON_15 = 	"'N/A'",
AK_GAMEPAD_BUTTON_16 = 	"'N/A'",
AK_HOME_BUTTON = 		"'N/A'",
AK_GAMEPAD_ANALOG_01 = 	"Left thumb X axis",
AK_GAMEPAD_ANALOG_02 = 	"Left thumb Y axis",
AK_GAMEPAD_ANALOG_03 = 	"Right thumb X axis",
AK_GAMEPAD_ANALOG_04 = 	"Right thumb Y axis",
AK_GAMEPAD_ANALOG_05 = 	"'N/A'",
AK_GAMEPAD_ANALOG_06 = 	"'N/A'",
AK_GAMEPAD_ANALOG_07 = 	"'N/A'",
AK_GAMEPAD_ANALOG_08 = 	"'N/A'",
AK_GAMEPAD_ANALOG_09 = 	"'N/A'",
VK_SPACE = 				"'N/A'",
VK_RETURN = 			"'N/A'",
VK_ESCAPE = 			"'N/A'",
VK_LEFT = 				"'N/A'",
VK_RIGHT = 				"'N/A'",
VK_UP = 				"'N/A'",
VK_DOWN =				"'N/A'",
}

elseif( AK_PLATFORM_SONY) then

kButtonNameMapping = 
{ 
AK_GAMEPAD_BUTTON_01 = "Cross", --Already used in: "NextPreviousRepeat", "SmartPause" & "AskAttendedMode".
AK_GAMEPAD_BUTTON_02 = "Circle", --Already used in: "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_03 = "Square", --Already used in: "NextPreviousRepeat" & "AskAttendedMode".
AK_GAMEPAD_BUTTON_04 = "Triangle",  --Already used in: "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_05 = "L", 
AK_GAMEPAD_BUTTON_06 = "R", 
AK_GAMEPAD_BUTTON_07 = "N/A", 
AK_GAMEPAD_BUTTON_08 = "N/A", 
AK_GAMEPAD_BUTTON_09 = "Select", 
AK_GAMEPAD_BUTTON_10 = "Start", --Already used in: "CoEndOfTest" and "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_11 = "Directional pad up", 
AK_GAMEPAD_BUTTON_12 = "Directional pad right", 
AK_GAMEPAD_BUTTON_13 = "Directional pad down", 
AK_GAMEPAD_BUTTON_14 = "Directional pad left", 
AK_GAMEPAD_BUTTON_15 = "N/A", 
AK_GAMEPAD_BUTTON_16 = "N/A",
AK_HOME_BUTTON = "N/A",
AK_GAMEPAD_ANALOG_01 = "Left thumb X axis",
AK_GAMEPAD_ANALOG_02 = "Left thumb Y axis",
AK_GAMEPAD_ANALOG_03 = "Right thumb X axis",
AK_GAMEPAD_ANALOG_04 = "Right thumb Y axis",
AK_GAMEPAD_ANALOG_05 = "N/A",
AK_GAMEPAD_ANALOG_06 = "N/A",
AK_GAMEPAD_ANALOG_07 = "N/A",
AK_GAMEPAD_ANALOG_08 = "N/A",
AK_GAMEPAD_ANALOG_09 = "N/A"
}

elseif( AK_PLATFORM_NX ) then

kButtonNameMapping = 
{ 
AK_GAMEPAD_BUTTON_01 = "A", --Already used in: "NextPreviousRepeat", "SmartPause" & "AskAttendedMode".
AK_GAMEPAD_BUTTON_02 = "B", --Already used in: "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_03 = "X", --Already used in: "NextPreviousRepeat" & "AskAttendedMode".
AK_GAMEPAD_BUTTON_04 = "Y",  --Already used in: "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_05 = "L", 
AK_GAMEPAD_BUTTON_06 = "R", 
AK_GAMEPAD_BUTTON_07 = "N/A", 
AK_GAMEPAD_BUTTON_08 = "N/A", 
AK_GAMEPAD_BUTTON_09 = "Select", 
AK_GAMEPAD_BUTTON_10 = "Start", --Already used in: "CoEndOfTest" and "NextPreviousRepeat".
AK_GAMEPAD_BUTTON_11 = "Directional pad up", 
AK_GAMEPAD_BUTTON_12 = "Directional pad right", 
AK_GAMEPAD_BUTTON_13 = "Directional pad down", 
AK_GAMEPAD_BUTTON_14 = "Directional pad left", 
AK_GAMEPAD_BUTTON_15 = "N/A", 
AK_GAMEPAD_BUTTON_16 = "N/A",
AK_HOME_BUTTON = "N/A",
AK_GAMEPAD_ANALOG_01 = "Left thumb X axis",
AK_GAMEPAD_ANALOG_02 = "Left thumb Y axis",
AK_GAMEPAD_ANALOG_03 = "Right thumb X axis",
AK_GAMEPAD_ANALOG_04 = "Right thumb Y axis",
AK_GAMEPAD_ANALOG_05 = "N/A",
AK_GAMEPAD_ANALOG_06 = "N/A",
AK_GAMEPAD_ANALOG_07 = "N/A",
AK_GAMEPAD_ANALOG_08 = "N/A",
AK_GAMEPAD_ANALOG_09 = "N/A"
}

end

AK_NotImplemented 				= 0
AK_Success 						= 1
AK_Fail 						= 2
AK_PartialSuccess 				= 3
AK_NotCompatible 				= 4
AK_AlreadyConnected 			= 5
AK_InvalidFile 					= 7
AK_AudioFileHeaderTooLarge 		= 8
AK_MaxReached 					= 9
AK_InvalidID 					= 14
AK_IDNotFound 					= 15
AK_InvalidInstanceID 			= 16
AK_NoMoreData 					= 17
AK_InvalidStateGroup 			= 20
AK_ChildAlreadyHasAParent 		= 21
AK_InvalidLanguage 				= 22
AK_CannotAddItseflAsAChild 		= 23
AK_InvalidParameter 			= 31
AK_ElementAlreadyInList 		= 35
AK_PathNotFound 				= 36
AK_PathNoVertices 				= 37
AK_PathNotRunning 				= 38
AK_PathNotPaused 				= 39
AK_PathNodeAlreadyInList 		= 40
AK_PathNodeNotInList 			= 41
AK_DataNeeded 					= 43
AK_NoDataNeeded 				= 44
AK_DataReady 					= 45
AK_NoDataReady 					= 46
AK_InsufficientMemory 			= 52
AK_Cancelled 					= 53
AK_UnknownBankID 				= 54
AK_BankReadError 				= 56
AK_InvalidSwitchType 			= 57
AK_FormatNotReady 				= 63
AK_WrongBankVersion 			= 64
AK_FileNotFound 				= 66
AK_DeviceNotReady 				= 67
AK_BankAlreadyLoaded 			= 69
AK_RenderedFX 					= 71
AK_ProcessNeeded 				= 72
AK_ProcessDone 					= 73
AK_MemManagerNotInitialized 	= 74
AK_StreamMgrNotInitialized 		= 75
AK_SSEInstructionsNotSupported 	= 76
AK_Busy 						= 77
AK_UnsupportedChannelConfig 	= 78
AK_PluginMediaNotAvailable 		= 79
AK_MustBeVirtualized 			= 80
AK_CommandTooLarge 				= 81
AK_RejectedByFilter 			= 82
AK_InvalidCustomPlatformName 	= 83
AK_DLLCannotLoad 				= 84
AK_DLLPathNotFound 				= 85
AK_NoJavaVM 					= 86
AK_OpenSLError 					= 87
AK_PluginNotRegistered 			= 88
AK_DataAlignmentError 			= 89
AK_DeviceNotCompatible 			= 90
AK_DuplicateUniqueID 			= 91
AK_InitBankNotLoaded 			= 92
AK_DeviceNotFound 				= 93
AK_PlayingIDNotFound			= 94

-- AKRESULT error codes enumeration
kResultCode = 
{
    [AK_NotImplemented] = "AK_NotImplemented",							-- This feature is not implemented.
    [AK_Success] = "AK_Success",										-- The operation was successful.
    [AK_Fail] = "AK_Fail",												-- The operation failed.
    [AK_PartialSuccess] = "AK_PartialSuccess",							-- The operation succeeded partially.
    [AK_NotCompatible] = "AK_NotCompatible",							-- Incompatible formats
    [AK_AlreadyConnected] = "AK_AlreadyConnected",						-- The stream is already connected to another node.
    [AK_InvalidFile] = "AK_InvalidFile",								-- An unexpected value causes the file to be invalid.
    [AK_AudioFileHeaderTooLarge] = "AK_AudioFileHeaderTooLarge",		-- The file header is too large.
    [AK_MaxReached] = "AK_MaxReached",									-- The maximum was reached.
    [AK_InvalidID] = "AK_InvalidID",									-- The ID is invalid.
    [AK_IDNotFound] = "AK_IDNotFound",									-- The ID was not found.
    [AK_InvalidInstanceID] = "AK_InvalidInstanceID",					-- The InstanceID is invalid.
    [AK_NoMoreData] = "AK_NoMoreData",									-- No more data is available from the source.
	[AK_InvalidStateGroup] = "AK_InvalidStateGroup",					-- The StateGroup is not a valid channel.
	[AK_ChildAlreadyHasAParent] = "AK_ChildAlreadyHasAParent",			-- The child already has a parent.
	[AK_InvalidLanguage] = "AK_InvalidLanguage",						-- The language is invalid (applies to the Low-Level I/O).
	[AK_CannotAddItseflAsAChild] = "AK_CannotAddItseflAsAChild",		-- It is not possible to add itself as its own child.
	[AK_InvalidParameter] = "AK_InvalidParameter",						-- Something is not within bounds.
	[AK_ElementAlreadyInList] = "AK_ElementAlreadyInList",				-- The item could not be added because it was already in the list.
	[AK_PathNotFound] = "AK_PathNotFound",								-- This path is not known.
	[AK_PathNoVertices] = "AK_PathNoVertices",							-- Stuff in vertices before trying to start it
	[AK_PathNotRunning] = "AK_PathNotRunning",							-- Only a running path can be paused.
	[AK_PathNotPaused] = "AK_PathNotPaused",							-- Only a paused path can be resumed.
	[AK_PathNodeAlreadyInList] = "AK_PathNodeAlreadyInList",			-- This path is already there.
	[AK_PathNodeNotInList] = "AK_PathNodeNotInList",					-- This path is not there.
	[AK_DataNeeded] = "AK_DataNeeded",									-- The consumer needs more.
	[AK_NoDataNeeded] = "AK_NoDataNeeded",								-- The consumer does not need more.
	[AK_DataReady] = "AK_DataReady",									-- The provider has available data.
	[AK_NoDataReady] = "AK_NoDataReady",								-- The provider does not have available data.
	[AK_InsufficientMemory] = "AK_InsufficientMemory",					-- Memory error.
	[AK_Cancelled] = "AK_Cancelled",									-- The requested action was cancelled (not an error).
	[AK_UnknownBankID] = "AK_UnknownBankID",							-- Trying to load a bank using an ID which is not defined.
	[AK_BankReadError] = "AK_BankReadError",							-- Error while reading a bank.
	[AK_InvalidSwitchType] = "AK_InvalidSwitchType",					-- Invalid switch type (used with the switch container)
    [AK_FormatNotReady] = "AK_FormatNotReady",							-- Source format not known yet.
	[AK_WrongBankVersion] = "AK_WrongBankVersion",						-- The bank version is not compatible with the current bank reader.
    [AK_FileNotFound] = "AK_FileNotFound",								-- File not found.
    [AK_DeviceNotReady] = "AK_DeviceNotReady",							-- Specified ID doesn't match a valid hardware device: either the device doesn't exist or is disabled.
	[AK_BankAlreadyLoaded] = "AK_BankAlreadyLoaded",					-- The bank load failed because the bank is already loaded.
	[AK_RenderedFX] = "AK_RenderedFX",									-- The effect on the node is rendered.
	[AK_ProcessNeeded] = "AK_ProcessNeeded",							-- A routine needs to be executed on some CPU.
	[AK_ProcessDone] = "AK_ProcessDone",								-- The executed routine has finished its execution.
	[AK_MemManagerNotInitialized] = "AK_MemManagerNotInitialized",		-- The memory manager should have been initialized at this point.
	[AK_StreamMgrNotInitialized] = "AK_StreamMgrNotInitialized",		-- The stream manager should have been initialized at this point.
	[AK_SSEInstructionsNotSupported] = "AK_SSEInstructionsNotSupported",-- The machine does not support SSE instructions (required on PC).
	[AK_Busy] = "AK_Busy",												-- The system is busy and could not process the request.
	[AK_UnsupportedChannelConfig] = "AK_UnsupportedChannelConfig",		-- Channel configuration is not supported in the current execution context.
	[AK_PluginMediaNotAvailable] = "AK_PluginMediaNotAvailable",		-- Plugin media is not available for effect.
	[AK_MustBeVirtualized] = "AK_MustBeVirtualized",					-- Sound was Not Allowed to play.
	[AK_CommandTooLarge] = "AK_CommandTooLarge",						-- SDK command is too large to fit in the command queue.
	[AK_RejectedByFilter] = "AK_RejectedByFilter",						-- A play request was rejected due to the MIDI filter parameters.
	[AK_InvalidCustomPlatformName] = "AK_InvalidCustomPlatformName",	-- Detecting incompatibility between Custom platform of banks and custom platform of connected application
	[AK_DLLCannotLoad] = "AK_DLLCannotLoad",							-- Plugin DLL could not be loaded, either because it is not found or one dependency is missing.
	[AK_DLLPathNotFound] = "AK_DLLPathNotFound",						-- Plugin DLL search path could not be found.
	[AK_NoJavaVM] = "AK_NoJavaVM",										-- No Java VM provided in AkInitSettings.
	[AK_OpenSLError] = "AK_OpenSLError",								-- OpenSL returned an error.  Check error log for more details.
	[AK_PluginNotRegistered] = "AK_PluginNotRegistered",				-- Plugin is not registered.  Make sure to implement a AK::PluginRegistration class for it and use "AK_STATIC_LINK_PLUGIN" in the game binary.
	[AK_DataAlignmentError] = "AK_DataAlignmentError",					-- A pointer to audio data was not aligned to the platform's required alignment (check AkTypes.h in the platform-specific folder)
	[AK_DeviceNotCompatible] = "AK_DeviceNotCompatible",				-- Incompatible Audio device.
	[AK_DuplicateUniqueID] = "AK_DuplicateUniqueID",					-- Two Wwise objects share the same ID.
	[AK_InitBankNotLoaded] = "AK_InitBankNotLoaded",					-- The Init bank was not loaded yet, the sound engine isn't completely ready yet.
	[AK_DeviceNotFound] = "AK_DeviceNotFound",							-- The specified device ID does not match with any of the output devices that the sound engine is currently using.
}
-- **********************************************************************
-- Those functions are needed for the QA automated test to work properly.
-- **********************************************************************

-- Call this with path between AK_AUTOMATEDTESTS_PATH and GeneratedSoundBanks\. Usually this is the WwiseProject's name.
-- If in_language is not specified, "English(US)" is used.
-- IMPORTANT: Don't use forwardslashes or backslashes in arguments, as type of slashes used in file paths is platform-specific.
-- Instead, use GetDirSlashChar() helper below.
-- Example: 
-- Say your soundbanks are in $(AK_AUTOMATEDTESTS_PATH)/PluginTests/CompressorTest/GeneratedSoundBanks/Windows/.
-- Call this:
-- SetDefaultBasePathAndLanguage( "PluginTests" .. GetDirSlashChar() .. "CompressorTest" )

function SetDefaultBasePathAndLanguage( in_projectName, in_language )	
	SetDefaultBasePathAndLanguageQA( FindBasePathForProject(in_projectName), in_language )	
end


-- This function can be used on it's own, if you want to specify a full path to the SoundBanks. 
-- The default "SetDefaultBasePathAndLanguage" function, used in most "Automated Tests", requires a relative path from the "AutomatedTests" folder.
-- Unfortunately, this approach is not convenient for scripts refering to Projects located outside the "AutomatedTests" folder. That's exactly what this function is for.
function SetDefaultBasePathAndLanguageQA( in_basePath, in_language )

	for k,device in pairs(g_lowLevelIO) do 
		if AK_PLATFORM_SONY then
			device:AddBasePath("/host/") -- This must be called first, to be last in the locations list
			device:AddBasePath("/app0/")
		end

		local result = device:SetBasePath( in_basePath ) -- g_lowLevelIO is defined by audiokinetic\AkLuaFramework.lua	
		AKASSERT( result == AK_Success, "Base path set error" )	
	end
		
	g_basePath = in_basePath
	
	-- We need this variable for iOS
	-- This variable is set when uploading bank with iTunes
	--if ( os.getenv("GAMESIMULATOR_FLAT_HIERARCHY") == nil) then
		--If you want to leave the language "undefined" in the lowLevelIO, you have to set "in_language" to  "none".
		if not(in_language == "none") then
			if (in_language == nil or in_language=="") then
				in_language = "English(US)"
			end
			
			local result = AK.StreamMgr.SetCurrentLanguage( in_language )
			AKASSERT( result == AK_Success, "Language set error" )
		end
	--end
end


-- Returns platform-specific character used to split directories in paths.
function GetDirSlashChar()	
	if( AK_PLATFORM_PC or AK_PLATFORM_XBOX ) then		
		return "\\"
	else
		return "/"
	end
end


function LogTestMsg( in_strMsg,LineFeed )  -- this function will log a message in the lua console and in the Wwise profiler.
	if( not AK_LUA_RELEASE ) then
		if (LineFeed) then
			print( in_strMsg )
			print( " " )
			AK.Monitor.PostString( in_strMsg, AK.Monitor.ErrorLevel_Message )
			AK.Monitor.PostString( " ", AK.Monitor.ErrorLevel_Message )
		else
			print( in_strMsg )
			AK.Monitor.PostString( in_strMsg, AK.Monitor.ErrorLevel_Message )
		end
	else
		if (LineFeed) then
			print( in_strMsg )
			print( " " )
		else
			print( in_strMsg )
		end
	end
end

function AutoLogTestMsg ( in_strMsg,in_PreLineFeed,in_PostLinefeed )

	local remainingString = in_strMsg
	
	if g_maxLogChar == nil then
		g_maxLogChar = 55  -- maximum of characters per line. Can be overridden in your main script
	end
	
	if in_PreLineFeed ~= nil then  -- apply pre linefeed if needed
		for line = 1, in_PreLineFeed do
			if( not AK_LUA_RELEASE ) then
				print (" ") 
				AK.Monitor.PostString( " ", AK.Monitor.ErrorLevel_Message )
			else
				print( " " )
		    end
		end
	end
	
	while string.len (remainingString) > g_maxLogChar do -- split too long test messages
		local currentChar = "x"
		local searchPos = g_maxLogChar

		while currentChar ~= " " do
			currentChar = string.sub (remainingString, searchPos, searchPos)
			searchPos = searchPos -1
		end
		
		if( not AK_LUA_RELEASE ) then  -- only send to Wwise capture log if not gamesim release
			print (string.sub(remainingString, 1, searchPos))
			AK.Monitor.PostString( string.sub(remainingString, 1, searchPos), AK.Monitor.ErrorLevel_Message )
	
		else
			print (string.sub(remainingString, 1, searchPos))
		end
		remainingString = string.sub(remainingString,searchPos + 2)
	end
	
	if remainingString ~= nil then
		if( not AK_LUA_RELEASE ) then  -- print the rest of the string once it is smaller than g_maxLogChar
			print (remainingString)
			AK.Monitor.PostString( remainingString, AK.Monitor.ErrorLevel_Message )
		else
			print( remainingString )
		end
	end

	if in_PostLinefeed ~= nil then  -- apply post linefeed if needed
		for line = 1, in_PostLinefeed do
			if( not AK_LUA_RELEASE ) then
				print (" ") 
				AK.Monitor.PostString(" ", AK.Monitor.ErrorLevel_Message )
			else
				print( " " )
		    end
		end
	end

end

--This variable is useful only in OFFLINE mode.  It simulates the output of os.gettickcount
g_TickCount = 0
function InternalGameTick()
	AkGameTick()
	g_TickCount = g_TickCount + 1
end

-- Wait for delayTime ms or if stopVarName becomes true
-- stopVarName should be the string name of the variable to observe. It is optional (omit if not needed)
function Wait(delayTime, stopVarName)  -- useful whenever you need a delay in a coroutine, without blocking the flow of the gameloop	
	local stop = false
	if ( AkLuaGameEngine.IsOffline() ) then		
		local numIter = delayTime/AK_AUDIOBUFFERMS				
		while ( numIter > 0 and not stop) do						
			numIter = numIter - 1
			InternalGameTick()
			if stopVarName ~= nil and _G[stopVarName] ~= nil then stop = _G[stopVarName] end
		end
	else
		testStartTime = os.gettickcount()
		while( os.gettickcount() - testStartTime < delayTime and not stop) do
			coroutine.yield()
			if stopVarName ~= nil and _G[stopVarName] ~= nil then stop = _G[stopVarName] end
		end
	end
end

-- This function is the same as the "Wait" above but will take in accound the performance test mode and dirty the cache if needed.
function PerfWait(delayTime) 
	if ( AkLuaGameEngine.IsOffline() ) then		
		local numIter = delayTime/AK_AUDIOBUFFERMS		
		while ( numIter > 0 ) do			
			numIter = numIter - 1
			InternalGameTick()			
			if g_PerfMode ~= "Best" then
				AkLuaGameEngine.DirtyCache()
			end
		end
	else
		testStartTime = os.gettickcount()
		while( os.gettickcount() - testStartTime < delayTime ) do
			coroutine.yield()			
		end
		if g_PerfMode ~= "Best" then
			AkLuaGameEngine.DirtyCache()
		end
	end
end

-- Useful to generate a time out
function TimeOut()
	LogTestMsg( "****** Now entering an infinite loop ******")
	while(true) do
	end
end

-- Useful to fake a crash
function Crash()
	LogTestMsg( "****** This instance will now crash ******")
	AkLuaGameEngine.Crash()
end

--[[ ***********************
Register all plug-ins.
***********************]]
function AkRegisterPlugIns()
	AK.SoundEngine.RegisterAllPlugins()
end

function CoWaitStartTest() -- You should always put this coroutine as the first test in your test array. It will give you time to connect to Wwise					
	if IsUnattended() == true then -- If in unattended mode, make a pause to give user time to connect.
		Pause()
	end
		
	if ( not AkLuaGameEngine.IsOffline() ) then
		Wait(500)
	end

end
g_testName[CoWaitStartTest]="CoWaitStartTest" -- give a printable name to CoWaitStartTest


function CoEndOfTest() -- You should always put this coroutine as the last one in your test array. It will end your test gracefully.

	AutoLogTestMsg( "****** All tests are finished ******",1,0 )	
	if ( not IsUnattended() )then		
		if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then		
			AutoLogTestMsg( "****** Press "..kButtonNameMapping.VK_ESCAPE.." to Exit Game Loop ******",0,1 )
			
		else			
			AutoLogTestMsg( "****** "..kButtonNameMapping.AK_GAMEPAD_BUTTON_10.." to Exit Game Loop ******",0,1 )
		end    
	end
	kEndOfTests = true
end

g_testName[CoEndOfTest]="CoEndOfTest" -- give a printable name to CoEndOfTest

function FindFunctionNameInGlobalTable(func)
	for key in pairs(_G) do			
		if _G[key] == func then			
			return key
		end
	end	
	return "Unknown"
end

function ReplaceBadCharacters(testName)	
	testName = string.gsub(testName, "|", "_")
	testName = string.gsub(testName, "\\", "_")
	testName = string.gsub(testName, "?", "_")
	testName = string.gsub(testName, "*", "_")
	testName = string.gsub(testName, "<", "_")
	testName = string.gsub(testName, "\"", "_")				
	testName = string.gsub(testName, ":", "_")
	testName = string.gsub(testName, ">", "_")
	testName = string.gsub(testName, "+", "_")											
	testName = string.gsub(testName, "]", "_")				
	testName = string.gsub(testName, "/", "_")
	testName = string.gsub(testName, ",", "_")	
	return testName
end

--[[
The numerous ways of naming a RoboQA test:
1) If the variable g_TestNamingFunc points to a function, then this function is called to generate the name. Function and parameters are passed
2) If the function MyFunc has a friend named "MyFuncNaming", then this function is called to genereate the name.  Only the Parameters are passed
3) If g_testName has a name for this function, then it is used.
4) Using the plain function name: g_testsArray = { MyFunc } -> Generates test named "MyFunc"
5) If used with parameters, parameters are appended: g_testsArray = { MyFunc, "Play_Sound", 22 } -> Generates "MyFunc_Play_Sound_22"
--]]
function GetTestNameFromParams(func, params)
	local name = nil
	local funcName = FindFunctionNameInGlobalTable(func)
	if g_TestNamingFunc ~= nil then	--Do we have an overriding naming function?
		name = g_TestNamingFunc(funcName, params)
	else	
		--Is there an explicit name function for this function?
		if _G[funcName .. "Naming"] ~= nil then
			name = _G[funcName .. "Naming"](params)
		end
	end
	
	if name == nil or type(name) ~= "string" then
		if g_testName[func] ~= nil then	--Do we have a specific name provided through the old array?
			name = g_testName[func]
		else
			name = funcName
		end		
		
		--Default naming: function followed by each non-empty param spaced by underscore
		for i=1,#params do			
			if params[i] ~= nil and type(params[i]) ~= "table" and tostring(params[i]) ~= "" then
				name = name .. "_" .. tostring(params[i])
			end
		end
	end	
	return name
end

function AkInsertTestRoutine(func, name, ...)
	local test = {}
	test.Func = func
	test.Params = {...}
	if (name == nil) then
		test.Name = GetTestNameFromParams(func, test.Params)
	else
		test.Name = name
	end
	
	table.insert(g_TestTable, test)
end

function AkGetTestName(func)
	for i=1,#g_TestTable do
		if func == g_TestTable[i].Func then
			return g_TestTable[i].Name
		end
	end
end

function TransformTestArray()
	local iTest = 1
	if (g_testsArray == nil) then
		return
	end
	
	while (iTest <= #g_testsArray) do
		local routine = {}		
		routine.Func = g_testsArray[iTest]
		
		--Gather optional parameters
		iTest = iTest + 1
		routine.Params = {}
		while g_testsArray[iTest] ~= nil and type(g_testsArray[iTest]) ~= "function" do
			table.insert(routine.Params, g_testsArray[iTest])
			iTest = iTest + 1
		end
		
		routine.Name = GetTestNameFromParams(routine.Func, routine.Params)
		
		table.insert(g_TestTable, routine)
	end
end

function ResetEngineState()
	if( AK.SoundEngine.IsInitialized() ) then
		AK.SoundEngine.SetDefaultListeners( nil, 0)		
		AK.SoundEngine.StopAllObsolete()
		AK.SoundEngine.UnregisterAllGameObj()
		AK.SpatialAudio.ResetStochasticEngine()
	end					
		
	AkClearAllGameTickCalls()
end

function CoHandleTests()  -- this is the coroutine that will execute each tests declared in g_testsArray. It will wait for user input to control the test flow.	
	
	--Transform the simple test array in the form we need.  The table of routines allow for parameters more easily
	TransformTestArray()

	local testIndex = 1
	while (testIndex <= #g_TestTable) do
	
		local current = g_TestTable[testIndex]
		currentTest = current.Func	--Legacy. The global variable currentTest is used in automated scripts.
		
		if skipMode == true then
			AutoLogTestMsg ("-> "..current.Name,0,1)			
			skipMode = false
		else
			LogTestMsg("-> "..current.Name)

			local coroutineName = ReplaceBadCharacters(current.Name)
			if ( ProfilerCapture() ) then			
				AkStartProfilerCapture(ProfilerCaptureFileName(coroutineName))
			end	

			if ( kCaptureOneFilePerCoroutine ) then								
				AkStartOutputCapture( ReplaceBadCharacters(current.Name)..".wav" )
			end
			
			-- Register default game object
			if( AK.SoundEngine.IsInitialized() ) then
				AK.SoundEngine.RegisterGameObj( g_AkDefaultListener, "AkDefaultListener")
				AK.SoundEngine.SetDefaultListeners( {g_AkDefaultListener}, 1)			
				AK.SoundEngine.RegisterGameObj( g_AkDefaultEmitter, "AkDefaultEmitter")
			end

			if (current.Params == nil) then
				current.Func()
			else							
				current.Func(unpack(current.Params))
			end
			
			if ( kCaptureOneFilePerCoroutine ) then							
				AkStopOutputCapture()
			end
			
			if ( ProfilerCapture() ) then							
				AkStopProfilerCapture()
			end	
			
			testIndex = testIndex + 1			
		end
		
		if not IsUnattended() then -- ask for user input only if not in unattended mode. IsUnattended() should be declared in main script.		
			NextPreviousRepeat()	
		end
		
		if (buttonPressed == executeButton) then
			testIndex = testIndex			
		elseif (buttonPressed == backwardButton) then		
			if testIndex >= 2 then
				testIndex = testIndex - 1				
			end
			
			skipMode = true
		elseif (buttonPressed == forwardButton) then			
			if testIndex < table.maxn(g_TestTable) then  			
				testIndex = testIndex + 1				
			end
			
			skipMode = true			
		elseif (buttonPressed == exitButton) then		
			testIndex = table.maxn(g_TestTable) -- last index is usually the End of test			
		elseif (buttonPressed == repeatButton) then		
			testIndex = testIndex - 1
		end
		
		ResetEngineState()				
	end	
end

function CoHandleTestsAutomated()  -- this is the coroutine that will execute each tests declared in g_testsArray.
	
	TransformTestArray()
	
	local testIndex = 1
	while (testIndex <= #g_TestTable) do
	
		local current = g_TestTable[testIndex]
		currentTest = current.Func	--Legacy. The global variable currentTest is used in automated scripts.
		
		-- Startup routines can be skipped
		if (current.Func ~= CoWaitStartTest and current.Func ~= CoEndOfTest) then
		
			LogTestMsg("-> "..current.Name)
			--Before starting the co-routine, reset the random seed. 
			math.randomseed(12345)
			
			local coroutineName = ReplaceBadCharacters(current.Name)
			if ( ProfilerCapture() ) then							
				AkStartProfilerCapture(ProfilerCaptureFileName(coroutineName))
			end	
			
			local captureFileName = ReplaceBadCharacters(current.Name)..".wav"
			if ( kCaptureOneFilePerCoroutine ) then
				AkStartOutputCapture( captureFileName )
			end
			
			-- Register default game object
			if( AK.SoundEngine.IsInitialized() ) then
				AK.SoundEngine.RegisterGameObj( g_AkDefaultListener, "AkDefaultListener")
				AK.SoundEngine.SetDefaultListeners( {g_AkDefaultListener}, 1)
				AK.SoundEngine.RegisterGameObj( g_AkDefaultEmitter, "AkDefaultEmitter")
			end

			-- Execute the coroutine until it finishes.		
			local routine = coroutine.create(current.Func)
			while(coroutine.status(routine) ~= "dead") do	
				InternalGameTick()				
				io.flush()	--Make sure the stdout is flushed ("standard output", the output where all the "print" go)	
				local success = true
				local errMsg = ""
				if (current.Params == nil) then
					success, errMsg = coroutine.resume( routine )
				else
					success, errMsg = coroutine.resume( routine, unpack(current.Params) )
				end
					
				if success == false then
					print(errMsg)
				end				
			end		
			if ( kCaptureOneFilePerCoroutine ) then
				AkStopOutputCapture()
			end
	
			if ( ProfilerCapture() ) then							
				AkStopProfilerCapture()
			end	
			
		end
		
		testIndex = testIndex + 1
						
		ResetEngineState()
	end	
	kEndOfTests = true
end

-- This function handles the "profiler" argument that can be passed to the GameSimulator 
-- to start/stop the Game Profiler Capture for each coroutine.
function ProfilerCapture()
	--Process arguments passed to the GameSimulator.
	for i,ARG in ipairs(arg) do
		local argStart, argEnd = string.find(ARG, "-profiler")
		if argStart ~= nil then
			--"profiler" argument found. Game Profiler Capture will be executed in CoHandleTests & CoHandleTestsAutomated.
			return true
		end
	end
	return false
end

-- This function computes the file name that will be given to the "game profiler capture" files for each coroutine.
function ProfilerCaptureFileName(in_coroutineName)
	--Here we find the LUA script name of the running script.
	local luaScriptName = AkFileNameFromPath(LUA_SCRIPT,false)

	--Here we generate an ID based on the OS time/date to append to the "Game Profiler Capture" file name 
	--to make sure the Game Profiling files won't be overwritten from 1 session to another.
	--local captureTimeID = os.time()
	local captureTimeID = os.date("%Hh%Mm%Ss")
	
	--Here we generate the unique profilerFileName
	profilerFileName = captureTimeID.."_"..luaScriptName.."_"..in_coroutineName..".prof"

	return MultiPlatformCompliantName(profilerFileName)
end

--This functions finds the file name (including file name extension, if present) from a full path.
function AkFileNameFromPath(in_path, in_withExtension)
	
	--Since in LUA you can't perform a find from the end of file, we reverse the string to perform the find. 
	local reversedPath = string.reverse(in_path)

	--Here we find the position of the slash (/) in the reversed path. If "nil", there's no file name extension.
	local slashPosition = string.find(reversedPath, GetDirSlashChar())

	--There's no slash... we probably received a file name as input.
	local fileName 
	if slashPosition == nil then
		fileName = in_path
	--There's a slash... find the file name with extension.
	else
		fileName = string.sub(in_path, -(slashPosition-1))
	end

	HandleFileNameExtension(fileName, in_withExtension )
	
	return out_fileName
end

--This function deals (leaves it or trims it) with the file name extension.
function HandleFileNameExtension(in_fileName,in_withExtension)
	--User specified that he wants the file name extension. Return in_fileName.
	if ( in_withExtension == nil or  in_withExtension == true ) then
		out_fileName = in_fileName
		return out_fileName

	--Here we will trim the file name extension (if one is present) to the user request.
	else
		--Since in LUA you can't perform a find from the end of file, we reverse the string to perform the find. 
		local reversedFileName = string.reverse (in_fileName)

		--Here we find the position of the period (.) of the file name extension in the file name. If "nil", there's no file name extension.
		local fileNameExtensionLength = string.find (reversedFileName, ".", 1, true)

		-- A file name extension was found.
		out_fileName = in_fileName
		if (fileNameExtensionLength ~= nil) then 

			--Here we save the trimmed file name prefix in a variable.
			local fileNameWithoutExtension = string.sub ( in_fileName, 1,  -(fileNameExtensionLength+1))
	
			out_fileName = fileNameWithoutExtension
		end

		return out_fileName
	end
end

-- This function will take a file name (with or without a file name extension) 
-- and trim it to a specified length to make sure it can be written on any platform medium.
function MultiPlatformCompliantName(in_name)	
	local maxFileNameLength
	
	maxFileNameLength = 128

	--Here we find the original file name length (including file name extension).
	local originalFileNameLength = string.len (in_name)

	--The file name received in parameter is already Multi-Platform Compliant... we return and use it.
	if (originalFileNameLength <= maxFileNameLength) then
		local out_name = in_name
		return out_name
		
	--Name received in parameter is too long. Here we compute a Multi-Platform Compliant Name.	
	else
		--Since in LUA you can't perform a find from the end of file, we reverse the string to perform the find. 
		local reversedFileName = string.reverse (in_name)
		
		--Here we find the position of the period (.) of the file name extension in the file name. If "nil", there's no file name extension.
		local fileNameExtensionLength = string.find (reversedFileName, ".", 1, true)
		
		-- A file name extension was found.
		if (fileNameExtensionLength ~= nil) then 
			--Here we save the file name extension (including the period) in a variable.
			local fileNameExtension = string.sub (in_name, -fileNameExtensionLength, -1)
		
			--Here we save the trimmed file name prefix in a variable.
			local fileNamePrefix = string.sub ( in_name, 1, (maxFileNameLength - (fileNameExtensionLength)))
			
			--Here we compute the Multi-Platform Compliant Name.
			out_name = fileNamePrefix..fileNameExtension

		--It's a file without a file name extension.
		else
			out_name = string.sub ( in_name, 1, maxFileNameLength)
		end

		--Here we return the computed Multi-Platform Compliant Name.
		return out_name	
	end
end

function NextPreviousRepeat()  -- this function waits for user input to control flow of tests.

	if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then
		executeButton = VK_SPACE
		backwardButton = VK_LEFT 
		forwardButton = VK_RIGHT 
		repeatButton =  VK_RETURN
		exitButton = VK_ESCAPE
		
		AutoLogTestMsg( "---- Press "..kButtonNameMapping.VK_SPACE.." to execute, "..kButtonNameMapping.VK_RETURN.." to repeat test ----",1,0 )
		AutoLogTestMsg( "---- "..kButtonNameMapping.VK_LEFT.." or "..kButtonNameMapping.VK_RIGHT.." arrow for previous or next test ----",0,1 )
				
	else
		executeButton = AK_GAMEPAD_BUTTON_01
		forwardButton = AK_GAMEPAD_BUTTON_02
		backwardButton = AK_GAMEPAD_BUTTON_03
		repeatButton =  AK_GAMEPAD_BUTTON_04
		exitButton = AK_GAMEPAD_BUTTON_10
		AutoLogTestMsg( "---- Press "..kButtonNameMapping.AK_GAMEPAD_BUTTON_01.." to execute, "..kButtonNameMapping.AK_GAMEPAD_BUTTON_04.." to repeat test ----",1,0 )
		AutoLogTestMsg( "---- "..kButtonNameMapping.AK_GAMEPAD_BUTTON_03.." or "..kButtonNameMapping.AK_GAMEPAD_BUTTON_02.." for previous or next test     ----",0,1 )
		
	end
	
	while(  not AkIsButtonPressedThisFrameInternal( executeButton ) ) do
	
		if AkIsButtonPressedThisFrameInternal( repeatButton )	then 
		
			buttonPressed = repeatButton
			return 
			
		elseif AkIsButtonPressed( backwardButton )	then 
		
			buttonPressed = backwardButton
			Wait(100)
			return 
			
		elseif AkIsButtonPressed( forwardButton )	then 
		
			buttonPressed = forwardButton
			Wait(100)
			return 
			
		elseif AkIsButtonPressedThisFrameInternal( exitButton )	then 
		
			buttonPressed = exitButton
			return 
			
		end
		
		coroutine.yield()
		
	end
	
	buttonPressed = executeButton
	Wait(150)
	return

end

function Pause()  -- this function considers if test is attended or unattended and skips Pause when unattended	
	
	if not IsUnattended() then 
	
		if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then
			resumeButton = VK_SPACE
			AutoLogTestMsg( "------ Press "..kButtonNameMapping.VK_SPACE.." to continue ------",0,1 )
		else
			resumeButton = AK_GAMEPAD_BUTTON_01 
			AutoLogTestMsg( "------ "..kButtonNameMapping.AK_GAMEPAD_BUTTON_01.." to continue  ------",0,1 )	
		end
		
		while(  not AkIsButtonPressedThisFrameInternal( resumeButton ) ) do
			coroutine.yield()
		end
		
		Wait(200)
		return AkIsButtonPressedThisFrameInternal( resumeButton )
	else
		if (not AkLuaGameEngine.IsOffline()) then
			Wait(200) -- do minimal wait even in unattended mode
		end
	end
end

function PauseUnattended()  -- this function will pause even in unattended mode

	if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then
		resumeButton = VK_SPACE
		AutoLogTestMsg( "------ Press "..kButtonNameMapping.VK_SPACE.." to continue ------",0,1 )
				
	else
		resumeButton = AK_GAMEPAD_BUTTON_01 
		AutoLogTestMsg( "------ Press "..kButtonNameMapping.AK_GAMEPAD_BUTTON_01.." to continue  ------",0,1 )	
	end
	
	while(  not AkIsButtonPressedThisFrameInternal( resumeButton ) ) do
		coroutine.yield()
	end
	
	Wait(200)
	return AkIsButtonPressedThisFrameInternal( resumeButton )

end

function AskAttendedMode()  -- Let user decide if test will be attended or unattended

	if ( AkLuaGameEngine.IsOffline() ) then
		g_unattended = true
		return true
	end

	if( AK_PLATFORM_PC or AK_PLATFORM_MAC ) then
	
		attendedButton = VK_SPACE
		unattendedButton =  VK_RETURN
		AutoLogTestMsg( " " )
		AutoLogTestMsg( "------ Press "..kButtonNameMapping.VK_SPACE.." for attended mode or "..kButtonNameMapping.VK_RETURN.." for unattended mode ------",0,1 )
		
	else
		attendedButton = AK_GAMEPAD_BUTTON_01 
		unattendedButton =  AK_GAMEPAD_BUTTON_03
		AutoLogTestMsg( " " )
		AutoLogTestMsg( "------ Press "..kButtonNameMapping.AK_GAMEPAD_BUTTON_01.." for attended mode or "..kButtonNameMapping.AK_GAMEPAD_BUTTON_03.." for unattended mode ------",0,1 )
		
	end

	while(not AkIsButtonPressed( attendedButton ) and not AkIsButtonPressed( unattendedButton )) do
		AkLuaGameEngine.Render()
	end

	if AkIsButtonPressed( attendedButton ) then
	
		g_unattended = false
		return AkIsButtonPressed( attendedButton )
		
	else
	
		g_unattended = true
		return AkIsButtonPressed( unattendedButton )
		
	end
	
end

-- ==========================================================
-- AnalogControl()

--This function will compute a (RTPC) value using it's pre-defined range and the position of the Controller thumbstick.
--It will mostly be used to drive a RTPC using a Thumbstick button.

-- This function works on the Windows (using the Xbox360 controller).
	--NOTE:
	--On (AK_PLATFORM_PC) the Left and Right Triggers are mapped on AK_GAMEPAD_ANALOG_03, 
	--where the Left Trigger Range = [32767,65407]
	--and the Right Trigger Range = [32767, 127].

--This function REQUIRES the following parameters:
--	AK_GAMEPAD_ANALOG_ID: i.e. AK_GAMEPAD_ANALOG_01 to AK_GAMEPAD_ANALOG_09 (the specific ANALOG button you assigned to this function)
--	min_GameParameterValue: i.e. -2400
--	max_GameParameterValue: i.e. 2400
--	incrementSlider: i.e. true or false (True > incremental mode, False > range mode. There's more information below.)
--	incrementMultiplicator:  i.e. 10 (The maximum RTPC jump applied during 1 game frame.)

--		If the incrementSlider flag is "true", the thumbstick will work in incremental mode, 
--		where when we move the thumbstick, we increment the RTPC value and where when it's in it's default position, we do nothing special and leave the current value as is.

--		If the incrementSlider flag is "false", the thumbstick will work in range mode, 
--		where when the thumbstick in it's default position we map the output value to the mid-range RTPC value.

--The function RETURNS the:
--	computed (RTPC) value in your pre-defined range. i.e. 600
	
--Here's a short INTEGRATION EXAMPLE to help you with your script:

--EXAMPLE #1:
--	rtpcValue1 = AnalogControl(AK_GAMEPAD_ANALOG_01, -2400, 2400, true, 100)  <---This will compute RTPC value and return their value in the variable of your choice (rtpcValue1 in this case).	
--	AK.SoundEngine.SetRTPCValue( "Pitch_Game_Param", rtpcValue1, 2 )  <--- Here you set the computed RTPC value in the SoundEngine.
--	print ("Pitch_Game_Param > RTPC value is now: '" .. aValueToSet[AK_GAMEPAD_ANALOG_01] .. "'")  <--- You can print the current RTPC value to help you debug your script.

--EXAMPLE #2:
--	rtpcValue2 = AnalogControl(AK_GAMEPAD_ANALOG_06, 0, 100, false)  <---This will compute RTPC value and return their value in the variable of your choice (rtpcValue2 in this case).	
--	AK.SoundEngine.SetRTPCValue( "Low_Pass_Filter_Game_Param", rtpcValue2, 2 )  <--- Here you set the computed RTPC value in the SoundEngine.
--	print ("Low_Pass_Filter_Game_Param > RTPC value is now: '" .. aValueToSet[AK_GAMEPAD_ANALOG_06] .. "'")  <--- You can print the currentRTPC value to help you debug your script.

-- ==========================================================
function AnalogControl(AK_GAMEPAD_ANALOG_ID, min_GameParameterValue, max_GameParameterValue, incrementSlider, incrementMultiplicator )

	--We initialize the Analog Control range[-1,1] for the Thumbsticks here.
	--These values are used on: AK_PLATFORM_.
	min_AnalogValue = -1
	max_AnalogValue = 1
	range_AnalogValue = (max_AnalogValue - min_AnalogValue) --2
	mid_AnalogValue = ((max_AnalogValue + min_AnalogValue) / 2) --0
	analogControlDirection = 1 --The default direction of the AnalogControl... the positive direction goes from left to right, or from bottom to top.
	
	if( AK_PLATFORM_PC) then
		--We defined the Windows Analog Control range for the Thumbsticks here.
		-- This is for the XBox360 controller only. Note: Each controller has it's own value.
		min_AnalogValue = 0
		max_AnalogValue = 65535
		range_AnalogValue = (max_AnalogValue - min_AnalogValue) --65535
		mid_AnalogValue = ((max_AnalogValue + min_AnalogValue) / 2) --32767

		--The direction of some AnalogControl axis is inverted on Windows(for AK_GAMEPAD_ANALOG_02 and AK_GAMEPAD_ANALOG_05). So, we switch the direction here.
		if (AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_02) or (AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_05) then
			analogControlDirection = -1
		end
	end
	
	--ERROR HANDLING: 
	--=======================================================
	if AK_GAMEPAD_ANALOG_ID == nil then
		LogTestMsg ("Your AK_GAMEPAD_ANALOG_ID was not defined!")
		LogTestMsg ("Please verify your function call.",666)
	end
	
	if min_GameParameterValue == nil then
		min_GameParameterValue = min_AnalogValue
	end
	
	if max_GameParameterValue == nil then
		max_GameParameterValue = max_AnalogValue
	end 
	 
	if incrementSlider == nil then
		incrementSlider = true
	end
	 
	if incrementMultiplicator == nil then
		incrementMultiplicator = 1
	end

	
	--=======================================================
	

	--We compute the Game Parameter range and middle value here.
	range_GameParameterValue = max_GameParameterValue - min_GameParameterValue
	mid_GameParameterValue = ((max_GameParameterValue + min_GameParameterValue) / 2)
	
	
	--We make sure the "aValueToSet" array exist. If not, we create it here.
	if aValueToSet == nil then	
		aValueToSet	= {}
	end
	
	
	--We make sure the "AK_GAMEPAD_ANALOG_ID"  index and value is in the array. If not, we create it here.
	if aValueToSet[AK_GAMEPAD_ANALOG_ID] == nil then

		aValueToSet[AK_GAMEPAD_ANALOG_ID] = mid_GameParameterValue --if there's no value set, set value to the mid_GameParameterValue
		
	end
	
		--We only allow to reset the values if you are in increment mode, because it doesn't make sense in range mode.
		--NOTE: When both the AnalogControl and AnalogControlPos functions are used (at the same time and on the same buttons
		--of the controller to perform different operations), the reset operation is now applied in both functions, since I used "AkIsButtonPressed" in this function.
		--I originally used the AkLuaFramework "AkIsButtonPressedThisFrameInternal" function instead, but only 1 parameter was reset each time. 
		--The one from the function in which the button down operation was trapped and not the other one because the GameFrame
		--had changed after the coroutine.yield() was processed. In this case, the button down wasn't considered anymore because we weren't on the same GameFrame
		--than the one in which the button down operation was performed.
		if incrementSlider == true then
			-- Added this section to reset easily the RTPC to the "mid_GameParameterValue" using the Thumbstick button.
			if (AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_01) or (AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_02) then
				if (AK_PLATFORM_PC) then 
					if  AkIsButtonPressed( AK_GAMEPAD_BUTTON_09 ) then
						-- AK_GAMEPAD_BUTTON_09 = "Left thumb down"
						aValueToSet[AK_GAMEPAD_ANALOG_ID] = mid_GameParameterValue --reset value to the mid_GameParameterValue	
						return aValueToSet[AK_GAMEPAD_ANALOG_ID]
					end
					
				else 
					if  AkIsButtonPressed( AK_GAMEPAD_BUTTON_15 ) then
						-- AK_GAMEPAD_BUTTON_15 = "Left thumb down"
						aValueToSet[AK_GAMEPAD_ANALOG_ID] = mid_GameParameterValue --reset value to the mid_GameParameterValue	
						return aValueToSet[AK_GAMEPAD_ANALOG_ID]
					end
				end
				
			elseif (AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_04) or (AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_05) then
				if (AK_PLATFORM_PC) then 
					if  AkIsButtonPressed( AK_GAMEPAD_BUTTON_10 ) then
						-- AK_GAMEPAD_BUTTON_10 = "Right thumb down"
						aValueToSet[AK_GAMEPAD_ANALOG_ID] = mid_GameParameterValue --reset value to the mid_GameParameterValue
						return aValueToSet[AK_GAMEPAD_ANALOG_ID]
					end
					
				else 
					if  AkIsButtonPressed( AK_GAMEPAD_BUTTON_16 ) then
						-- AK_GAMEPAD_BUTTON_16= "Right thumb down"
						aValueToSet[AK_GAMEPAD_ANALOG_ID] = mid_GameParameterValue --reset value to the mid_GameParameterValue	
						return aValueToSet[AK_GAMEPAD_ANALOG_ID]
					end
				end
			end
		end

		--Get the currentAnalogPosition here.
		currentAnalogPosition = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_ID )
		currentAnalogPositionNormalized = analogControlDirection * ((currentAnalogPosition - mid_AnalogValue)/(range_AnalogValue / 2))
		
		--=====================================================================================
		--NOTE:
		--======
		--On (AK_PLATFORM_PC) the Left and Right Triggers are mapped on AK_GAMEPAD_ANALOG_03, 
		--where the Left Trigger Range = [32767,65407]
		--and the Right Trigger Range = [32767, 127].
		--=====================================================================================

		
		--Here's the Default code path. That is where the job gets done for the Analog Buttons (Triggers are handled in the  "if" section above). 
		if incrementSlider == true then
			if ( AK_PLATFORM_PC or AK_PLATFORM_PS3 ) then
				--Here, we create a "Dead Zone" for the AnalogControls on Windows.
				if (currentAnalogPositionNormalized > -0.1) and (currentAnalogPositionNormalized < 0.1) then
					aValueToSet[AK_GAMEPAD_ANALOG_ID] = aValueToSet[AK_GAMEPAD_ANALOG_ID]
				
				else
					aValueToSet[AK_GAMEPAD_ANALOG_ID] = aValueToSet[AK_GAMEPAD_ANALOG_ID] + (currentAnalogPositionNormalized * incrementMultiplicator)
				
				end
				
			else
				aValueToSet[AK_GAMEPAD_ANALOG_ID] = aValueToSet[AK_GAMEPAD_ANALOG_ID] + (currentAnalogPositionNormalized * incrementMultiplicator)
			end
			
			
			if aValueToSet[AK_GAMEPAD_ANALOG_ID] >= max_GameParameterValue then
				aValueToSet[AK_GAMEPAD_ANALOG_ID] = max_GameParameterValue
				
			elseif aValueToSet[AK_GAMEPAD_ANALOG_ID] <= min_GameParameterValue then
				aValueToSet[AK_GAMEPAD_ANALOG_ID] = min_GameParameterValue
				
			end

		-- Code path for: incrementSlider == false
		else
			aValueToSet[AK_GAMEPAD_ANALOG_ID] =  mid_GameParameterValue + ((currentAnalogPositionNormalized * range_GameParameterValue) / 2)

		end

		return aValueToSet[AK_GAMEPAD_ANALOG_ID]	
	
end

-- ==========================================================
--AnalogControlPos()

--This function will compute the current game frame "X" and "Y" position of a Game Object in your (game) World based on the previous game frame position and then return it.
-- It has it's own position array, so it remembers the previous game frame position and then compute and return the current game frame position.

-- This function works on the Windows (using the Xbox360 controller).

--This function REQUIRES the following parameters:
--  	UseLeftThumbstick: i.e  true (defines which Thumbstick to use to compute the "X" and "Y" position; true = left, false = right)
--	gameObjectID: i.e. 2 (the GameObject assigned to this function)
--	min_XWorldLimit: i.e. -1000
--	max_XWorldLimit: i.e. 1000 
--	min_YWorldLimit: -1000
--	max_YWorldLimit: 1000
--	incrementSlider: i.e. true or false (True > incremental mode, False > range mode. There's more information below.)
--	incrementMultiplicator:  i.e. 10 (The maximum distance travelled in 1 footstep in your World.)
--		If the incrementSlider flag is "true", the thumbstick will work in incremental mode, 
--		where when we move the thumbstick, we increment the position value and where when it's in it's default position, we do nothing special and leave the current value as is.

--		If the incrementSlider flag is "false", the thumbstick will work in range mode, 
--		where when the thumbstick in it's default position we map the output value to the midX_WorldLimit & midY_WorldLimit value.


--The function RETURNS 2 values, the:
--	computed GameObject Position on the "X" axis: i.e. -12.5.
--	computed GameObject Position on the "Y" axis: i.e. 99.25
	
--Here's a short INTEGRATION EXAMPLE to help you with your script:
--	g_soundPos.Position.X, g_soundPos.Position.Y  = AnalogControlPos(true, 2, -1000, 1000, -1000, 1000, true, 10)  <---This will compute the (X, Y) position of your GameObject in your World using the LeftThumbstick values and return their value in the variable of your choice (g_soundPos.Position.X & g_soundPos.Position.Y in this case).	

--	AK.SoundEngine.SetPosition( 2, g_soundPos )  <--- Here you set the computed GameObject position on the (X,Y)  axis in the SoundEngine.

--	print ("PosX = "..g_soundPos.Position.X)  <--- You can print the current GameObject position on the "X" axis to help you debug your script.
--	print ("PosY = "..g_soundPos.Position.Y)  <--- You can print the current GameObject position on the "Y" axis to help you debug your script.

-- ==========================================================

function AnalogControlPos(UseLeftThumbstick, gameObjectID, min_XWorldLimit, max_XWorldLimit, min_YWorldLimit, max_YWorldLimit, incrementSlider, incrementMultiplicator )

	--We initialize the Analog Control range[-1,1] for the Thumbsticks here.
	min_AnalogValue = -1
	max_AnalogValue = 1
	range_AnalogValue = (max_AnalogValue - min_AnalogValue) --2
	mid_AnalogValue = ((max_AnalogValue + min_AnalogValue) / 2) --0
	analogControlDirection = 1 --The default direction of the AnalogControl... the positive direction goes from left to right, or from bottom to top.
	
		
	if (AK_PLATFORM_PC) then
		--We defined the Windows Analog Control range for the Thumbsticks here.
		-- This is for the XBox360 controller only. Note: Each controller has it's own value.
		min_AnalogValue = 0
		max_AnalogValue = 65535
		range_AnalogValue = (max_AnalogValue - min_AnalogValue) --65535
		mid_AnalogValue = ((max_AnalogValue + min_AnalogValue) / 2) --32767
	end
	
	--Here we initialize the Position X and Y variables.
	PositionX = 0	--this is the index of the current PositionX entry in the table
	PositionY = 1	--this is the index of the current PositionY entry in the table


	--ERROR HANDLING: 
	--=======================================================
	
	if 	UseLeftThumbstick == nil then
		LogTestMsg ("The UseLeftThumbstick option was not defined!")
		LogTestMsg ("Please verify your function call.",666)
	end
	
	if gameObjectID == nil then
		LogTestMsg ("The GameObjectID was not defined!")
		LogTestMsg ("Please verify your function call.",666)
	end
	
	if min_XWorldLimit == nil then
		min_XWorldLimit = -100
	end
	
	if max_XWorldLimit == nil then
		max_XWorldLimit = 100
	end 
	
	if min_YWorldLimit == nil then
		min_YWorldLimit = -100
	end
	
	if max_YWorldLimit == nil then
		max_YWorldLimit = 100
	end 
	 
	if incrementMultiplicator == nil then
		incrementMultiplicator = 1
	end
	--=======================================================
	
	
	--We compute the Game Parameter range and middle value here.
	rangeX_WorldLimit = max_XWorldLimit - min_XWorldLimit
	rangeY_WorldLimit = max_YWorldLimit - min_YWorldLimit
	midX_WorldLimit = (max_XWorldLimit + min_XWorldLimit) / 2
	midY_WorldLimit = (max_YWorldLimit + min_YWorldLimit) / 2

	
		--We make sure the "aValueToSet" array exist. If not, we create it here.
	if aGameObjPos == nil then	
		aGameObjPos	= {}
	end
	
	-- We make sure the "UseLeftThumbstick" array exist. If not, we create it here.
	if aGameObjPos[UseLeftThumbstick] == nil then
		aGameObjPos[UseLeftThumbstick] = {}
	end
	
	-- We make sure the "gameObjectID" array exist. If not, we create it here.
	if aGameObjPos[UseLeftThumbstick][gameObjectID] == nil then
		aGameObjPos[UseLeftThumbstick][gameObjectID] = {}
	end

	
	-- If PositionX doesn't exist, create and set it's value to 0.
	if aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] == nil then
		aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = 0
	end
	

	-- If PositionY doesn't exist, create and set it's value to 0.
	if aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] == nil then
		aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = 0
	end

	
	--The  code for this function starts here.
	--===========================================

	--We only allow to reset the values if you are in increment mode, because it doesn't make sense in range mode.
	--NOTE: When both the AnalogControl and AnalogControlPos functions are used (at the same time and on the same buttons
	--of the controller to perform different operations), the reset operation is now applied in both functions, since I used "AkIsButtonPressed" in this function.
	--I originally used the AkLuaFramework "AkIsButtonPressedThisFrameInternal" function instead, but only 1 parameter was reset each time. 
	--The one from the function in which the button down operation was trapped and not the other one because the GameFrame
	--had changed after the coroutine.yield() was processed. In this case, the button down wasn't considered anymore because we weren't on the same GameFrame
	--than the one in which the button down operation was performed.
	if incrementSlider == true then
		-- Added this section to reset easily the Position to (0,0) using the Left Thumbstick button.
		if UseLeftThumbstick == true then
			if (AK_PLATFORM_PC) then 
				if  AkIsButtonPressed( AK_GAMEPAD_BUTTON_09 ) then  -- AK_GAMEPAD_BUTTON_09 = "Left thumb down"	 
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = 0 --resets the Left_Right axis position to 0.
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = 0 --resets the Front_Back axis position to 0.
					return (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX]), (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY]) --Exit current function and return gameObjPosX and gameObjPosY.
				end
				
			else
				if  AkIsButtonPressed( AK_GAMEPAD_BUTTON_15 ) then	 -- AK_GAMEPAD_BUTTON_15 = "Left thumb down"
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = 0 --resets the Left_Right axis position to 0.
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = 0 --resets the Front_Back axis position to 0.
					return (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX]), (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY]) --Exit current function and return gameObjPosX and gameObjPosY.
				end
			end
			
		-- Added this section to reset easily the Position to (0,0) using the Right Thumbstick button.
		else
			if (AK_PLATFORM_PC) then 
				if  AkIsButtonPressed( AK_GAMEPAD_BUTTON_10 ) then -- AK_GAMEPAD_BUTTON_10 = "Right thumb down"
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = 0 --resets the Left_Right axis position to 0.
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = 0 --resets the Front_Back axis position to 0.				
					return (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX]), (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY]) --Exit current function and return gameObjPosX and gameObjPosY.
				end
				
			else  
				if AkIsButtonPressed( AK_GAMEPAD_BUTTON_16 ) then	 -- AK_GAMEPAD_BUTTON_16 = "Right thumb down"
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = 0 --resets the Left_Right axis position to 0.
					aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = 0 --resets the Front_Back axis position to 0.
					return (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX]), (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY]) --Exit current function and return gameObjPosX and gameObjPosY.
				end
			end
		end
	end
	
	
	if (AK_PLATFORM_PC) then
		--Get the currentAnalogPosition from the "Left" Thumbstick here.		
		if UseLeftThumbstick == true then
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_01 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_02 )

		--Get the currentAnalogPosition from the "Right" Thumbstick here.
		else
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_04 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_05 )
		end
		
		--The direction of some AnalogControl axis is inverted on Windows(for AK_GAMEPAD_ANALOG_02 and AK_GAMEPAD_ANALOG_05). So, we switch the direction here using "-(analogControlDirection)".
		currentAnalogPositionYNormalized = -(analogControlDirection) * ((currentAnalogPositionY - mid_AnalogValue)/(range_AnalogValue / 2))

		
	else
		--Get the currentAnalogPosition from the "Left" Thumbstick here.		
		if UseLeftThumbstick == true then
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_01 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_02 )

		--Get the currentAnalogPosition from the "Right" Thumbstick here.
		else
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_03 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_04 )
		
		end
		currentAnalogPositionYNormalized = analogControlDirection * ((currentAnalogPositionY - mid_AnalogValue)/(range_AnalogValue / 2))

	end
	
	currentAnalogPositionXNormalized = analogControlDirection * ((currentAnalogPositionX - mid_AnalogValue)/(range_AnalogValue / 2))

	
	if incrementSlider == true then
		if ( AK_PLATFORM_PC or AK_PLATFORM_PS3) then
			--Here, we create a "Dead Zone" on the X axis  for the AnalogControls on Windows.
			if (currentAnalogPositionXNormalized > -0.2) and (currentAnalogPositionXNormalized < 0.2) then
				aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX]
						
			else
				--Set the new currentAnalogPosition here.
				aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] + (currentAnalogPositionXNormalized * incrementMultiplicator)
			end
			
			--Here, we create a "Dead Zone" on the Y axis for the AnalogControls on Windows.
			if (currentAnalogPositionYNormalized > -0.2) and (currentAnalogPositionYNormalized < 0.2) then
				aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY]
						
			else
				--Set the new currentAnalogPosition here.
				aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] + (currentAnalogPositionYNormalized * incrementMultiplicator)
			end
			
		else
			--Set the new currentAnalogPosition here.
			aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] + (currentAnalogPositionXNormalized * incrementMultiplicator)
			aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] + (currentAnalogPositionYNormalized * incrementMultiplicator)
		end
		
		--Here we make sure we don't bust the Min and Max "X" WorldLimit value.
		if aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] >= max_XWorldLimit  then
			aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = max_XWorldLimit

		elseif aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] <= min_XWorldLimit  then
			aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] = min_XWorldLimit
		
		end
		
		--Here we make sure we don't bust the Min and Max "Y" WorldLimit value.
		if aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] >= max_YWorldLimit  then
			aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = max_YWorldLimit

		elseif aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] <= min_YWorldLimit  then
			aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] = min_YWorldLimit

		end

	-- Code path for: incrementSlider == false
	else
		aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX] =  midX_WorldLimit + ((currentAnalogPositionXNormalized * rangeX_WorldLimit) / 2)
		aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY] =  midY_WorldLimit + ((currentAnalogPositionYNormalized * rangeY_WorldLimit) / 2)
	end

	return (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionX]), (aGameObjPos[UseLeftThumbstick][gameObjectID][PositionY]) --Exit current function and return gameObjPosX and gameObjPosY.
	
end

-- ==========================================================
--AnalogControlPosLight()

--This function will use the Analog Control position to compute and return a "X" and "Y" (game object position) increment value between 0 and 1, 
-- if no increment multiplicator is specified. In this case, it will use the default incrementMultiplicator = 1.

-- This function works on the Windows (using the Xbox360 controller).

--This function REQUIRES the following parameters:
--  	UseLeftThumbstick: i.e  true (defines which Thumbstick to use to compute the "X" and "Y" position; true = left, false = right)
--	incrementMultiplicatorX/incrementMultiplicatorY:  i.e. 10 (The maximum increment travelled in 1 footstep in your World.)

--The function RETURNS 2 values, the:
--	computed Position Increment on the "X" axis,: i.e. -12.5.
--	computed Position Increment on the "Y" axis: i.e. 99.25
	
--Here's a short INTEGRATION EXAMPLE to help you with your script:
--	positionIncrementX, positionIncrementX  = AnalogControlPosLight(true, 10, 20)  <---This will compute the (X, Y) position increment using the LeftThumbstick values and return their value in the variable of your choice (positionIncrementX & positionIncrementY in this case).	
--	aPlayerPos[kPosX] = aPlayerPos[kPosX] + positionIncrementX
--	aPlayerPos[kPosY] = aPlayerPos[kPosY] + positionIncrementY
--	AK.SoundEngine.SetPosition( 2, aPlayerPos )  <--- Here you set the computed GameObject position on the (X,Y)  axis in the SoundEngine.

--	print ("PosX = "..aPlayerPos[kPosX])  <--- You can print the current GameObject position on the "X" axis to help you debug your script.
--	print ("PosY = "..aPlayerPos[kPosY])  <--- You can print the current GameObject position on the "Y" axis to help you debug your script.

-- ==========================================================

function AnalogControlPosLight (UseLeftThumbstick, incrementMultiplicatorX, incrementMultiplicatorY )

	--We initialize the Analog Control range[-1,1] for the Thumbsticks here.
	min_AnalogValue = -1
	max_AnalogValue = 1
	range_AnalogValue = (max_AnalogValue - min_AnalogValue) --2
	mid_AnalogValue = ((max_AnalogValue + min_AnalogValue) / 2) --0
	analogControlDirection = 1 --The default direction of the AnalogControl... the positive direction goes from left to right, or from bottom to top.
	
		
	if (AK_PLATFORM_PC) then
		--We defined the Windows Analog Control range for the Thumbsticks here.
		-- This is for the XBox360 controller only. Note: Each controller has it's own value.
		min_AnalogValue = 0
		max_AnalogValue = 65535
		range_AnalogValue = (max_AnalogValue - min_AnalogValue) --65535
		mid_AnalogValue = ((max_AnalogValue + min_AnalogValue) / 2) --32767
	end

	--ERROR HANDLING: 
	--=======================================================
	
	if 	UseLeftThumbstick == nil then
		LogTestMsg ("The UseLeftThumbstick option was not defined!")
		LogTestMsg ("Please verify your function call.",666)
	end
	 
	if incrementMultiplicatorX == nil then
		incrementMultiplicatorX = 1
	end
	
	if incrementMultiplicatorY == nil then
		incrementMultiplicatorY = 1
	end
	--=======================================================

	
	--The  code for this function starts here.
	--===========================================
	
	if (AK_PLATFORM_PC) then
		--Get the currentAnalogPosition from the "Left" Thumbstick here.		
		if UseLeftThumbstick == true then
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_01 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_02 )

		--Get the currentAnalogPosition from the "Right" Thumbstick here.
		else
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_04 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_05 )
		end
		
		--The direction of some AnalogControl axis is inverted on Windows(for AK_GAMEPAD_ANALOG_02 and AK_GAMEPAD_ANALOG_05). So, we switch the direction here using "-(analogControlDirection)".
		currentAnalogPositionYNormalized = -(analogControlDirection) * ((currentAnalogPositionY - mid_AnalogValue)/(range_AnalogValue / 2))

		
	else
		--Get the currentAnalogPosition from the "Left" Thumbstick here.		
		if UseLeftThumbstick == true then
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_01 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_02 )

		--Get the currentAnalogPosition from the "Right" Thumbstick here.
		else
			currentAnalogPositionX = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_03 )
			currentAnalogPositionY = AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_04 )
		
		end
		currentAnalogPositionYNormalized = analogControlDirection * ((currentAnalogPositionY - mid_AnalogValue)/(range_AnalogValue / 2))

	end
	
	currentAnalogPositionXNormalized = analogControlDirection * ((currentAnalogPositionX - mid_AnalogValue)/(range_AnalogValue / 2))
	--print (currentAnalogPositionXNormalized, currentAnalogPositionYNormalized)
	
		if ( AK_PLATFORM_PC or AK_PLATFORM_PS3 ) then
			--Here, we create a "Dead Zone" on the X axis  for the AnalogControls on Windows.
			if (currentAnalogPositionXNormalized > -0.2) and (currentAnalogPositionXNormalized < 0.2) then
				positionIncrementX = 0
						
			else
				--Set the new currentAnalogPosition here.
				positionIncrementX = (currentAnalogPositionXNormalized * incrementMultiplicatorX)
			end
			
			--Here, we create a "Dead Zone" on the Y axis for the AnalogControls on Windows.
			if (currentAnalogPositionYNormalized > -0.2) and (currentAnalogPositionYNormalized < 0.2) then
				positionIncrementY = 0
						
			else
				--Set the new currentAnalogPosition here.
				positionIncrementY = (currentAnalogPositionYNormalized * incrementMultiplicatorY)

			end
			
		else
			--Set the new currentAnalogPosition here.
			positionIncrementX = (currentAnalogPositionXNormalized * incrementMultiplicatorX)
			positionIncrementY = (currentAnalogPositionYNormalized * incrementMultiplicatorY)

		end
	--print ("CurrentAnalogPos:" .. currentAnalogPositionX,currentAnalogPositionY)
	--print ("posincrementX-Y:" .. positionIncrementX, positionIncrementY)
	return positionIncrementX, positionIncrementY --Exit current function and return gameObjPosX and gameObjPosY.
	
end


-- ==========================================================
-- AkIsTriggerPressedThisFrame(AK_GAMEPAD_ANALOG_ID)

--This function check if the Trigged button is pressed in the current game frame.

-- This function works on the Windows (using the Xbox360 controller).

--This function REQUIRES the following parameter:
--	AK_GAMEPAD_ANALOG_ID (the specific Trigger (ANALOG BUTTON)  you assigned to this function):
	-- AK_GAMEPAD_ANALOG_05 or AK_GAMEPAD_ANALOG_06 on XBOX360. 
	-- AK_GAMEPAD_ANALOG_03 or AK_GAMEPAD_ANALOG_06 on Windows. 

--The function RETURNS :
-- "true" if and only if the Trigged button is pressed in the current game frame.

	
--Here's a short INTEGRATION EXAMPLE to help you with your script:
--		if (AK_PLATFORM_PC) and (AkIsTriggerPressedThisFrame ( AK_GAMEPAD_ANALOG_06 ))
--		then
--			buttonPressed = fireButton
--			return buttonPressed
--		end
-- ==========================================================

-- Tables to remember which buttons were pressed. 
kTriggerCurrentlyDown = { }
	
function AkIsTriggerPressedThisFrame(AK_GAMEPAD_ANALOG_ID)
	if( kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] == true) then -- button already pressed
		return false

	else
		--Here we deal with the Windows Triggers. The values given by the controller Triggers are: 
		-- Both triggers not pressed = 32767 , Left trigger down = 65407, Right trigger down = 127
		if (AK_PLATFORM_PC) then
		
			if (not((AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_03) or (AK_GAMEPAD_ANALOG_ID == AK_GAMEPAD_ANALOG_06))) then
				LogTestMsg("This function is for Controller Triggers only.")
				LogTestMsg ("Please verify your function call.",666)
				return
			end
			
			if (( AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_ID ) ) >= 65390) then
				kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] = true
				return true
				
			elseif (( AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_ID ) ) <= 140) then
				kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] = true
				return true
				
			else
				if kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] == nil then
					kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] = false
				end
				
				kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] = false
				return false
			end
		end	
	end
end	


-- ==========================================================
-- AkTriggerCleanUp()

-- This method is used to avoid recognizing a Trigger button being pressed twice in the same game frame.
-- The function updates the state of the Trigger from 1 game frame to another in order to prevent any repetition if the Trigger was never release.

-- This function works on the Windows (using the Xbox360 controller).

--This function doesn't REQUIRE any parameter.
	
--Here's a short INTEGRATION EXAMPLE to help you with your script:
--		while (not(gameOver)) do
--			if (AK_PLATFORM_PC) and (AkIsTriggerPressedThisFrame ( AK_GAMEPAD_ANALOG_06 ))
--			then
--				buttonPressed = fireButton
--			else
--				buttonPressed = nil
--			end
--
--			(...)
--
-- 			if (buttonPressed == fireButton)  then
--				AK.SoundEngine.PostEvent( "Play_GunsShot", kPlayer )
--				coroutine.yield()
--			end

--			AkTriggerCleanUp()
--		end
-- ==========================================================
function AkTriggerCleanUp()
	for AK_GAMEPAD_ANALOG_ID,bIsKeyDown in pairs( kTriggerCurrentlyDown ) do		
		--Here we deal with the Windows Triggers. The values given by the controller Triggers are: 
		-- Both triggers not pressed = 32767 , Left trigger down = 65407, Right trigger down = 127
		if (AK_PLATFORM_PC) then
			if ((AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_ID ) ) >= 65390) then
				kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] = true
				
			elseif (( AkLuaGameEngine.GetAnalogStickPosition ( AK_GAMEPAD_ANALOG_ID ) ) <= 140) then
				kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] = true
			
			else 
				kTriggerCurrentlyDown[ AK_GAMEPAD_ANALOG_ID ] = false
			end	
		end
	end
end

-- ==========================================================
--AkStartOutputCapture()
--This function uses the default Sound Engine function along with an additional 50 ms Delay afterward
--to make sure the Sound Engine has enough time to start the Capture before the sounds starts playing.
-- See http://srv-techno/jira/browse/WG-10133 for more information
-- ==========================================================
g_currentTestWav = ""

function AkStartOutputCapture( in_filename )
	if ( AK.SoundEngine.IsInitialized() ) then
		g_currentTestWav = in_filename
		AK.SoundEngine.StartOutputCapture( in_filename )
		Wait(50)
	end
end

function AkStopOutputCapture( )
	if ( AK.SoundEngine.IsInitialized() ) then
		Wait(100)	--To have a bit of silence at the end.  It is more natural when listening
		AK.SoundEngine.StopOutputCapture( )		
	end
end

function AkRestartOutputCapture( in_suffix )
	if g_currentTestWav ~= "" and in_suffix ~= "" and AK.SoundEngine.IsInitialized() then
		local pos = string.find(g_currentTestWav, ".wav")
		if pos ~= nil then
			AK.SoundEngine.StopOutputCapture( )
			suffixedTestWav = string.sub(g_currentTestWav, 1, pos-1) .. "_" .. in_suffix .. ".wav"
			AK.SoundEngine.StartOutputCapture( suffixedTestWav )
		end
	end
end


-- ==========================================================
--AkStartProfilerCapture()
--This function uses the default Sound Engine function, but also appends the current date and time 
--to each filename in order to keep a copy of every Game Profiler Capture session.
-- ==========================================================
function AkStartProfilerCapture( in_filename )
	if ( AK.SoundEngine.IsInitialized() ) then		
		AK.SoundEngine.StartProfilerCapture(in_filename)
	end
end

function AkStopProfilerCapture()
	if ( AK.SoundEngine.IsInitialized() ) then
		AK.SoundEngine.StopProfilerCapture()	
	end
end

function IsUnattended()
	return AkLuaGameEngine.IsOffline() or g_unattended;
end

-- This function will initialize the Test Framework 
-- Place any initialization common to all tests here.
function AkInitAutomatedTests()
	print( string.format( "Input frames per second: %s", kFramerate ) )
	if( AK_LUA_RELEASE ) then
		print( "Not using communication" )
	else
		print( "Using communication" )
	end

	if( g_basepath ~= nil ) then		
		print("Base Path for banks is set to " .. g_basepath)
	end
	
	if( g_unattended ) then
		print("Script running unattended")
	end
	
	if( AkLuaGameEngine.IsOffline() ) then
		print("Script running with offline rendering (faster than real-time)")
	end
	
	if( kCaptureOneFilePerCoroutine ) then
		print("Script output is captured in a different file for each test")
	end
	
	--Start the routine that will run all the tests.
	if ( AkLuaGameEngine.IsOffline() ) then
		g_coroutineHandle = coroutine.create( CoHandleTestsAutomated )
	else
		g_coroutineHandle = coroutine.create( CoHandleTests )
	end	

end

function KillCoroutine(message)
	--Find the current coroutine in the test table
	
	--Try to find the name of the calling coroutine
	local found = 2
	while(debug.getinfo(found) ~= nil) do
		found = found + 1
	end
	local info = debug.getinfo(found-1)
	for i=1,#g_TestTable do
		if g_TestTable[i].Func == info.func then
			found = i			
		end
	end
	
	if found ~= 0 then
		print(g_TestTable[found].Name.. message)
	else
		print("Unknown routine "..message)
	end
	coroutine.resume(false)
	--After the resume(false), the coroutine is destroyed.  It won't execute the next lines.			
end

function AkIsButtonPressed( in_nButton )
	if AkLuaGameEngine.IsOffline() and coroutine.running() ~= nil then
		-- Kill the co-routine.  In unattended mode, we don't want to wait for the keyboard.  
		-- If a co-routine has a keyboard input loop, ignore this co-routine.	
		KillCoroutine(" was SKIPPED because it contains keyboard input instructions (AkIsButtonPressed).")				
	end
	return AkLuaGameEngine.IsButtonPressed(in_nButton)
end

function AkIsButtonPressedThisFrameInternal( in_nButton )	
		if AkLuaGameEngine.IsOffline() and coroutine.running() ~= nil then		
			-- Kill the co-routine.  In unattended mode, we don't want to wait for the keyboard.  
			-- If a co-routine has a keyboard input loop, ignore this co-routine.	
			KillCoroutine(" was SKIPPED because it contains keyboard input instructions (AkIsButtonPressedThisFrameInternal).")				
		end
	return AkIsButtonPressedThisFrame(in_nButton)	
end

function AKASSERT(in_condition, in_msg)
	if not in_condition then
		local msg = "ASSERT! " .. in_msg
		print(msg)
	end
end

function AkGetTickCount()
	if ( AkLuaGameEngine.IsOffline() ) then	
		return g_TickCount * AK_AUDIOBUFFERMS
	end
	return os.gettickcount()
end

function AkPathRemoveLastToken(in_path)	
	local reverse = string.reverse(in_path)
	local slash = string.find(reverse, GetDirSlashChar())
	if slash == nil then
		return nil
	end
	
	return string.reverse(string.sub(reverse, slash+1))
end

function FindGeneratedSoundBankPath(in_path)	
	local allFiles = ScanDir(in_path)	
	for i=1,#allFiles do						
		if string.find(allFiles[i], "GeneratedSoundBanks") ~= nil then	
			return in_path .. GetDirSlashChar() .. "GeneratedSoundBanks" .. GetDirSlashChar()			
		end
	end		
	return nil
end

function FindBasePathForProject(in_basePath)
	local searchPath = {}
	if( g_basepath ~= nil ) then
		--Support the -basepath commandline option on the GameSim
		return g_basepath		
	end
	
	--Check if a full path was passed as a parameter.  If it is a full path, add it in the search paths directly.
	if (string.find(in_basePath, ":") ~= nil) then
		table.insert(searchPath, in_basePath)
	end
	
	--Build a path from the lua script we run.  By default we will check for banks in the same directory.
	local path = LUA_SCRIPT	
	if path ~= nil then
		path = AkPathRemoveLastToken(path)			
	end			
	if path ~= nil then		
		table.insert(searchPath, path .. GetDirSlashChar())		
	
		--Try to find a "GeneratedSoundBanks" folder in the parent directories.
		local sbpath = nil
		repeat						
			sbpath = FindGeneratedSoundBankPath(path)						
			path = AkPathRemoveLastToken(path)		
			print (path)
			if path == nil then
				break
			end
		until(path == nil or sbpath ~= nil)	
		
		if sbpath ~= nil then
			table.insert(searchPath, sbpath .. GetPlatformName() .. GetDirSlashChar())
		end
	end
	
	--Add the ordinary roots for each platform too
	if( AK_PLATFORM_SONY ) then
		table.insert(searchPath, "app0")
	elseif ( AK_PLATFORM_XBOX ) then
		table.insert(searchPath, "Data/") 
	elseif (AK_PLATFORM_ANDROID ) then
		table.insert(searchPath, "/sdcard/sdcard-disk0/GameSimulator/")
	elseif (AK_PLATFORM_IOS ) then
		table.insert(searchPath, "./")
		table.insert(searchPath, "./Data/")
	end
	
	--Always include the current directory
	table.insert(searchPath, "./")
	
	local errorMsg = "Could not find any banks in the following directories:\n"
	for i=1,#searchPath do
		--Check if there is a Init.bnk or a file package in this folder
		local initFile = io.open(searchPath[i].."Init.bnk")		
		if (initFile == nil) then
			initFile = io.open(searchPath[i].."1355168291.bnk")		--Numeric version of Init.bnk
		end
		
		if (initFile ~= nil) then	
			io.close(initFile)			
			return searchPath[i]
		else
			local pckFiles = ScanDirWithExtension(searchPath[i], "pck")
			if next(pckFiles) ~= nil then
				-- Found at least one package file. Let's hope our banks are in it.
				print("Found file package(s) in directory "..searchPath[i])
				return searchPath[i]
			end
		end
		errorMsg = errorMsg .. searchPath[i] .. "\n"
	end
	
	print(errorMsg)
	return nil;
end

function ScanDir(dirname)
	print ("Scan " .. dirname)
	local list = AkLuaGameEngine.ListDirectory(dirname)
	if list == nil then
		return {}
	end

	local tabby = {}
	local from  = 1
	local delim_from, delim_to = string.find( list, "\n", from  )
	while delim_from do	
		table.insert( tabby, string.sub( list, from , delim_from-1 ) )
		from  = delim_to + 1
		delim_from, delim_to = string.find(list, "\n", from  )		
	end
	return tabby
end

-- Returns all file names of in_path with extension in_extension
function ScanDirWithExtension(in_path, in_extension)
	local strExtension = "."..in_extension
	local allFiles = ScanDir(in_path)
	local listFiles = {}
	
	for i=1,#allFiles do
		local filename = allFiles[i]
		
		-- find the .pck extension
		if string.find(filename, strExtension) ~= nil then						
			table.insert(listFiles, filename)
		end		
	end
	
	return listFiles
end

function FindAllBanks(in_basePath, in_language)

	if (in_language == nil or in_language=="") then
		in_language = "English(US)"
	end	
	
	--Load Init.bnk anyway
	local banklist = {"Init.bnk"}	
	FindBanksFromDirectory(in_basePath, banklist);
	FindBanksFromDirectory(in_basePath..in_language, banklist);
	return banklist
end

function FindBanksFromDirectory(path, in_banklist)
	print("Loading banks from " .. path)
	local allFiles = ScanDir(path)
			
	for i=1,#allFiles do
		local filename = allFiles[i]
		
		-- find the .bnk extension
		if string.find(filename, ".bnk") ~= nil and filename ~= "Init.bnk" then						
			table.insert(in_banklist, filename)
			print(filename)
		end		
	end		
end

function AkLoadBankCoRoutine(in_banks)
	print("Press space when ready to load banks\n")
	Pause()
	
	--Load the selected banks
	for i=1,#in_banks do
		local filename = in_banks[i]
		print("Loading "..filename)
		AkLoadBank(filename)
	end
end

-- Pass in an array of file package names (with their extension .pck). 
-- Note: The file package is opened from the base path.
-- Note: You may specify the low-level device in which you want the file package to be loaded. Prefix the package name with the name of the device with a semicolon. For example, "RAM:MyPackage.pck"
function AkLoadFilePackagesCoroutine(in_packages)
	print("Press space when ready to load file packages\n")
	Pause()
	
	for i=1,#in_packages do
		local packagename = in_packages[i]
		-- See if device is specified.
		local idxColon = string.find(packagename, ':', 2)
		if idxColon ~= nil then
			local deviceName = string.sub(packagename, 1, string.find(packagename, ':', 2) - 1)
			local package = string.sub(packagename, string.find(packagename, ':', 1)+1)
			assert( g_lowLevelIO[deviceName] ~= nil, "Device " .. deviceName .. " does not exist" );
			AkLoadPackageFromDevice(g_lowLevelIO[deviceName], package)
		else
			AkLoadPackage(packagename)
		end			
	end
end

--This function will do all the setup commonly used in test scripts:
--a) Find the base path
--b) Initialize the SoundEngine with default values.  You can override the default values by setting a function in g_OverrideSESettings.  See AkInitSE
--c) Register the plugins
--d) Load the file packages if applicable. File packages must be specified with their extension (.pck), and may optionally be prepended with the device name from which you wish to load them. For example, "RAM:MyPackage.pck"
--e) Find the banks to load, if none specified in "in_banks"
--f) Load the banks (actually puts a coroutine that will load the banks
--g) Start the game loop.
--h) Runs through all routines in g_testsArray
function AkDefaultScriptMain(in_basePath, in_language, in_banks, in_MetricsIP )	
	AkInitAutomatedTests()
	
	--Init Mem and Comm early for 
	if( not AK_LUA_RELEASE ) then
		AkInitComm()
	end
	
	local basePath = FindBasePathForProject(in_basePath)
	if (basePath == nil) then
		if AkLuaGameEngine.IsOffline() then
			AkTermComm();
			return
		end
		
		print("entering Infinite loop")
		--Don't allow script to continue
		while true do 
		end
	end
	
	AkInitSE()
	if AK.SoundEngine.IsInitialized() == false then
		LogTestMsg("Error: the sound engine is not initialized, terminating SoundEngine")
		AkStop()
		return
	end

	if g_SpatialAudioInitSettings ~= nil then
		AK.SpatialAudio.Init(g_SpatialAudioInitSettings)
	end	
	
	AK.SoundEngine.RegisterAllPlugins()		
		
	-- Set the project's base and language-specific paths for soundbanks:
	SetDefaultBasePathAndLanguageQA( basePath, in_language )
	
	if in_banks == nil then
		--Find all banks in the base path
		in_banks = FindAllBanks(basePath, in_language)
	end	
	
	if in_banks ~= nil then
		-- Split the banks array into soundbanks and file packages.
		local banks = {}
		local packages = {}
		
		for i=1,#in_banks do
			local filename = in_banks[i]
			if string.find(filename, ".pck") ~= nil then
				table.insert(packages, filename)
			else
				table.insert(banks, filename)
			end
		end

		-- Push coroutine to load file packages first, if needed.	
		local bankidx = 1
		if #packages ~= 0 then
			table.insert(g_TestTable, 1, {Func = AkLoadFilePackagesCoroutine, Name = "AkLoadFilePackagesCoroutine", Params = {packages}} )
			bankidx = 2
		end
		
		--If there are banks specified, add a coroutine to load them
		if #banks ~= 0 then			
			table.insert(g_TestTable, bankidx, {Func = AkLoadBankCoRoutine, Name = "AkLoadBankCoRoutine", Params = {banks}} )
		end
	end
	
	if ( in_MetricsIP ~= nil ) then
		LogTestMsg( "Initializing metrics",1 )
		print("Metrics Server IP: " .. in_MetricsIP)
		AkLuaGameEngine.InitMetrics( in_MetricsIP )
	end
	
	AkGameLoop()
	
	if ( in_MetricsIP ~= nil ) then
		LogTestMsg( "Terminating metrics",1 )
		AkLuaGameEngine.TermMetrics()
	end
	
	AkStop()
end

-- Appends the items from "itemsToAdd" to "listWhereToAppend"
-- Usage:
--   myList = ( a, b, c )
--   otherList = ( d, e, f )
--   AkAppendList( myList, otherList )
--     --> Now myList == ( a, b, c, d, e, f ) (and otherList was not modified)
function AkAppendList( listWhereToAppend, itemsToAdd )
    for k,v in ipairs( itemsToAdd ) do
		table.insert( listWhereToAppend, v )
	end
end 

function GetChannelCount()
	for i,ARG in ipairs(arg) do
		local argStart, argEnd = string.find(ARG, "-51")
		if argStart ~= nil then
			return 6
		end
		
		argStart, argEnd = string.find(ARG, "-71")
		if argStart ~= nil then
			return 8
		end
	end
	
	return 2 --Default
end

function PlatformNameNoUnderscore()
	NoUnderscoreStringPlatfomrName = PlatformName:gsub("_", "-")
	return NoUnderscoreStringPlatfomrName
end

-- Routine to start the DirtyCache mode when running performance tests.
function StartDirtyCache()
	g_PerfMode = "DirtyCache"
end

-- Routine to start the HeavyLoad mode when running performance tests.
function StartHeavyLoadRoutine()	
	g_PerfMode = "HeavyLoad"
end

-- Routine to stop the HeavyLoad mode when running performance tests.
function StopHeavyLoadRoutine()
	g_PerfMode = "Best"
end

function StartPerfMonitoring(Flags)
	if g_PerfMode == "HeavyLoad" then
		AkLuaGameEngine.StartHeavyLoad()
	end
	AkLuaGameEngine.StartPerfMon( Flags )
end

function StopPerfMonitoring(TestDescription, NumberInstances)
	if g_PerfMode == "HeavyLoad" then
		AkLuaGameEngine.StopHeavyLoad()
	end	
	AkLuaGameEngine.StopPerfMon()	
	AkLuaGameEngine.DumpMetrics( g_PerfMode, TestDescription,  tostring(NumberInstances) )
	Wait(1000) -- ensure has time to dump
end

function ProcessArgsForMetrics()
	--Process arguments.  We support -pf to specify the platform and -metrics to specify the IP of the metrics server.
	for i,ARG in ipairs(arg) do
		local argStart, argEnd = string.find(ARG, "-pf:")
		if argStart ~= nil then
			PlatformName = string.sub(ARG, argEnd + 1)
		end
		
		argStart, argEnd = string.find(ARG, "-metrics:")
		if argStart ~= nil then
			MetricsIP = string.sub(ARG, argEnd + 1)
		end
	end
	
	-- Platforms
	-- Avoid underscore in PlatformName as this is the tokenizing opertaor for the test name in the Metrics processor
	if( AK_PLATFORM_PC ) then
		if (PlatformName ~= nil) then
			-- RoboQA is a Intel machine
			if (PlatformName == "Win32_vc90") then
				PlatformName = "Intel32VC90"
			elseif (PlatformName == "Win32_vc100") then
				PlatformName = "Intel32VC100"
			elseif (PlatformName == "Win64_vc90") then
				PlatformName = "Intel64VC90"
			elseif (PlatformName == "Win64_vc100") then
				PlatformName = "Intel64VC100"
			end
		else
			print("Use standard naming if you want the platform to be properly recognized by metrics processor")
			print("MANUFACTURER|Architecture|Compiler description string: e.g. Intel32VC90, AMD64VC90 Intel64VC100 ...")
			PlatformName = io.stdin:read()	
		end		
	else
		PlatformName = GetPlatformName()
	end	
	print( "Platform selected: " .. PlatformName )
end

function ComparePlatformName(pf1, pf2)
	if pf1 == nil or pf2 == nil then
		return false
	end
	pf1 = string.lower(pf1)
	pf2 = string.lower(pf2)
	if pf2 == "pc" then
		local tmp = pf1
		pf1 = pf2
		pf2 = tmp
	end
	
	if pf1 == "pc" then
		return (string.find(pf1, "intel") ~= nil or string.find(pf1, "amd") ~= nil)
	end
	
	return string.find(pf1, pf2) ~= nil
end

-- Platform exclusion list has preceedence over platform inclusion list.
function AddBenchTest( PerfFunction, FcnArgs, PlatformExclusionList, PlatformInclusionList )
	local IsPlatformExcluded = false
	if ( PlatformExclusionList ~= nil ) then 
		local iPlatform = 1	
		while (iPlatform <= #PlatformExclusionList) do
			if ComparePlatformName(GetPlatformName(), PlatformExclusionList[iPlatform] ) then
				IsPlatformExcluded = true
				break
			end
			iPlatform = iPlatform + 1
		end
	elseif ( PlatformInclusionList ~= nil ) then 
		IsPlatformExcluded = true
		for _,pf in ipairs(PlatformInclusionList) do						
			if ComparePlatformName(GetPlatformName(), pf) then				
				IsPlatformExcluded = false
			end
		end		
	end
	
	if ( not IsPlatformExcluded ) then
		table.insert(g_testsArray, PerfFunction)
		for _,ar in ipairs(FcnArgs) do
			table.insert(g_testsArray, ar)
		end
	end
end

--- Geometry building functions ---


function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function HashXYZ( x, y, z )
	return x * 0x8da6b34 + y * 0xd8163841 + z *  0xcb1ab31f
end

function GeneratePolygonRoom(GeomSetID, x_start, z_start, radius, widthSegments, heightSegments, materialID, diffractionEnabled)
	
	--disable sections of the room
	local top = true
	local mid = true
	local bot = true
	
	function getVertRadial( name, az, el, radius )
		local x = -radius * math.cos(az) * math.sin(el)
		local y = -radius * math.cos(el)
		local z = radius * math.sin(az) * math.sin(el)
		return getVert(x+x_start,y,z+z_start)
	end

	function getAzEl(x,y,widthSegments,heightSegments)
		local az = x * 2.0 * math.pi / widthSegments
		local next_az = (x+1) * 2.0 * math.pi / widthSegments
		local el = y * math.pi / heightSegments
		local next_el = (y+1) * math.pi / heightSegments
		return az, next_az, el, next_el
	end
	
	if (diffractionEnabled ~= nil) then
		initGeoBuilder(GeomSetID, diffractionEnabled, false)
	else
		initGeoBuilder(GeomSetID, false, false) -- default to no diffraction
	end
		
	-- generate bottom
	if bot then
		for x=0,widthSegments-1 do
			local y=0
			--print("------------------")
			--print(x,y)
		
			local az, next_az, el, next_el = getAzEl(x,y,widthSegments,heightSegments)
		
			tri0 = AkTriangle:new()
			
			tri0.point0 = getVertRadial("p0", az, el, radius)
			tri0.point1 = getVertRadial("p1", az, next_el, radius)
			tri0.point2 = getVertRadial("p2", next_az, next_el, radius)
			tri0.surface = getSurf("Ceiling", materialID)
			
			tris[numTris+1] = tri0
			numTris = numTris + 1
		end
	end
	
	-- generate 'walls'
	if mid then
		for y=1,heightSegments-2 do
			for x=0,widthSegments-1 do
				--print("------------------")
				--print(x,y)
			
				local az, next_az, el, next_el = getAzEl(x,y,widthSegments,heightSegments)
			
				local v0 = getVertRadial("p0", az, el, radius)
				local v1 = getVertRadial("p1", next_az, el, radius)
				local v2 = getVertRadial("p2", az, next_el, radius)
				local v3 = getVertRadial("p3", next_az, next_el, radius)
				
				tri0 = AkTriangle:new()
				tri0.point0 = v0
				tri0.point1 = v1
				tri0.point2 = v2
				tri0.surface = getSurf("Wall", materialID)
				
				tri1 = AkTriangle:new()
				tri1.point0 = v3
				tri1.point1 = v2
				tri1.point2 = v1
				tri1.surface = getSurf("Wall", materialID)
				
				tris[numTris+1] = tri0
				tris[numTris+2] = tri1
				numTris = numTris + 2
			end
		end
	end
	
	-- generate top
	if top then
		for x=0,widthSegments-1 do
			local y = heightSegments-1
			--print("------------------")
			--print(x,y)
		
			local az, next_az, el, next_el = getAzEl(x,y,widthSegments,heightSegments)
		
			tri0 = AkTriangle:new()
			
			tri0.point0 = getVertRadial("p0", az, el, radius)
			tri0.point1 = getVertRadial("p1", next_az, el, radius)
			tri0.point2 = getVertRadial("p2", next_az, next_el, radius)
			tri0.surface = getSurf("Floor", materialID)
			
			tris[numTris+1] = tri0
			numTris = numTris + 1
		end
	end
	
	doneGeoBuilder()
	
end

function initGeoBuilder(GeomSetID, _diffraction, _diffractionBoundaryEdges, _roomID, _enableTriangles)
	geoID = GeomSetID
	tris = {}
	verts = {}
	surfs = {}
	vertMap = {}
	surfMap = {}
	
	numTris = 0
	numVerts = 0
	numSurfs = 0
	
	enableTriangles = true
	if ( _enableTriangles ~= nil ) then
		enableTriangles = _enableTriangles
	end
	
	diffraction = true
	diffractionBoundaryEdges = true
		
	if (_diffraction ~= nil) then
		diffraction = _diffraction
	end
	
	if (_diffractionBoundaryEdges ~= nil) then
		diffractionBoundaryEdges = _diffractionBoundaryEdges
	end
	
	if (_roomID ~= nil) then
		roomID = _roomID
	else
		roomID = -1
	end
end

function doneGeoBuilder()
	AK.SpatialAudio.SetGeometry(geoID, tris, numTris, verts, numVerts, surfs, numSurfs, diffraction, diffractionBoundaryEdges, enableTriangles, roomID)
	
	--force clean up of strings.
	initGeoBuilder(geoID)
	collectgarbage()
end

function getSurf(name, materialID, transmissionLoss)
	if (surfMap[name] == nil) then
		s = AkAcousticSurface:new()
		if materialID ~= nil then
			s.textureID = materialID 
		end
		if transmissionLoss ~= nil then
			s.transmissionLoss = transmissionLoss
		end
		s.strName = name
		surfs[numSurfs+1] = s
		surfMap[name] = numSurfs
		--print( "Surface[".. numSurfs .. "] - \'"..name.."'")
		numSurfs = numSurfs + 1
	end
	return surfMap[name]
end

function getVert( _x, _y, _z )
	local decimalPlaces = 4
	
	local x = round( _x, decimalPlaces)
	local y = round( _y, decimalPlaces)
	local z = round( _z, decimalPlaces)
	local hash = HashXYZ(x,y,z)
	
	if ( vertMap[hash] == nil )	then
		--create new vertex, add it to map

		v = AkVertex:new()
		v.X = x
		v.Y = y
		v.Z = z
		--print(x,y,z)
		verts[numVerts+1] = v
		vertMap[hash] = numVerts
		--print( "Vertex[".. numVerts .. "] - <" .. x .. ", " .. y .. ", " .. z .. "> " )
		numVerts = numVerts + 1
	end
	
	return vertMap[hash]
end

function AddTri(x0, y0, z0, x1, y1, z1, x2, y2, z2, name, materialID, transmissionLoss)
	
	tri = AkTriangle:new()
	tri.point0 = getVert(x0, y0, z0)
	tri.point1 = getVert(x1, y1, z1)
	tri.point2 = getVert(x2, y2, z2)
	tri.surface = getSurf(name, materialID, transmissionLoss)
	
	tris[numTris+1] = tri
	--print( "Triangle[".. numTris .. "] - (" .. tri.point0 .. ", " .. tri.point1 .. ", " .. tri.point2 .. ") " )
	numTris = numTris + 1
end

function AddRect(x0, y0, z0, x1, y1, z1, x2, y2, z2, x3, y3, z3, name, materialID, transmissionLoss)
	AddTri(x0, y0, z0, x1, y1, z1, x2, y2, z2, name .. "0", materialID, transmissionLoss)
	AddTri(x2, y2, z2, x3, y3, z3, x0, y0, z0, name .. "1", materialID, transmissionLoss)
end

function GenerateGeometricRoom(GeomSetID, RoomID, AuxBus, x, y, z, width, height, depth, materialID, withDiffractionEdges)
	GenerateShoebox(GeomSetID, x, y, z, width, height, depth, materialID, withDiffractionEdges, RoomID)
	CreateRoom(RoomID, AuxBus, false, false)
end

function GenerateShoebox(GeomSetID, x, y, z, width, height, depth, materialID, withDiffractionEdges, roomID, transmissionLoss, enableTriangles)

	if (withDiffractionEdges == nil) then
		initGeoBuilder(GeomSetID, withDiffractionEdges, nil, roomID, enableTriangles)
	else
		initGeoBuilder(GeomSetID, withDiffractionEdges, withDiffractionEdges, roomID, enableTriangles)
	end
	
	AddRect(x, y, z,
			x, y, z+depth, 
			x+width, y, z+depth, 
			x+width, y, z, 
			"floor",
			materialID,
			transmissionLoss)
			
	AddRect(x, y+height, z,
			x, y+height, z+depth, 
			x+width, y+height, z+depth, 
			x+width, y+height, z, 
			"ceiling",
			materialID,
			transmissionLoss)
			
	AddRect(x+width, y, z,
			x+width, y, z+depth, 
			x+width, y+height, z+depth, 
			x+width, y+height, z, 
			"right",
			materialID,
			transmissionLoss)
	
	AddRect(x, y, z,
			x, y, z+depth, 
			x, y+height, z+depth, 
			x, y+height, z, 
			"left",
			materialID,
			transmissionLoss)	
	
	AddRect(x, y, z+depth,
			x+width, y, z+depth, 
			x+width, y+height, z+depth, 
			x, y+height, z+depth, 
			"front",
			materialID,
			transmissionLoss)
		
	AddRect(x, y, z,
			x+width, y, z, 
			x+width, y+height, z, 
			x, y+height, z, 
			"back",
			materialID,
			transmissionLoss)
		
	doneGeoBuilder()
	
end

function GenerateQuad(GeomSetID, x0, y0, z0, x1, y1, z1, x2, y2, z2, x3, y3, z3, materialID, _diffraction, _diffractionBoundaryEdges)
	GenerateQuads(GeomSetID, {{x0, y0, z0, x1, y1, z1, x2, y2, z2, x3, y3, z3}}, materialID, _diffraction, _diffractionBoundaryEdges)
end

-- list is list of 12-tuples of [x0, y0, z0, x1, y1, z1, x2, y2, z2, x3, y3, z3]
function GenerateQuads(GeomSetID, list, materialID, _diffraction, _diffractionBoundaryEdges)
	
	initGeoBuilder(GeomSetID, _diffraction, _diffractionBoundaryEdges)

	local count = 0
	for i,item in ipairs(list) do
		AddRect(item[1], item[2], item[3], item[4], item[5], item[6], item[7], item[8], item[9], item[10], item[11], item[12], "Quad" .. count .. "_")
		count = count + 1
	end
		
	doneGeoBuilder()
	
end

-------------------------


function CreatePortal(PortalID, PosX, PosY, PosZ, OriX, OriY, OriZ, enabled, FrontRoom, BackRoom, HalfWidth, HalfHeight, HalfDepth)
	
	local xfrm = AkTransform:new_local()
	xfrm:Set(PosX, PosY, PosZ, OriX, OriY, OriZ, 0.0, 1.0, 0.0)
	
	local extent = AkExtent:new_local()
	extent.halfWidth = 15
	extent.halfHeight = 20
	extent.halfDepth = 10
	
	if (HalfWidth ~= nil and HalfHeight ~= nil and HalfDepth ~= nil) then
		print("CreatePortal: id:" .. PortalID .. " pos: <".. PosX .. ",".. PosY .. ",".. PosZ .. "> Ori: <".. OriX .. ",".. OriY .. ",".. OriZ .. ">" .. " FrontRoom: " .. FrontRoom .. " BackRoom: " .. BackRoom .. " HalfWidth: " .. HalfWidth .. " HalfHeight: " .. HalfHeight .. " HalfDepth: " .. HalfDepth)
		extent.halfWidth = HalfWidth
		extent.halfHeight = HalfHeight
		extent.halfDepth = HalfDepth
	else
		print("CreatePortal: id:" .. PortalID .. " pos: <".. PosX .. ",".. PosY .. ",".. PosZ .. "> Ori: <".. OriX .. ",".. OriY .. ",".. OriZ .. ">" .. " FrontRoom: " .. FrontRoom .. " BackRoom: " .. BackRoom)
	end
	
	local portalParams = AkPortalParams:new_local()
	portalParams.Transform = xfrm
	portalParams.Extent = extent
	
	portalParams.fGain = 1.0
	
	portalParams.bEnabled = enabled
	portalParams.strName = "portal_" .. PortalID
	
	portalParams.FrontRoom = FrontRoom
	portalParams.BackRoom = BackRoom
	
	AK.SpatialAudio.SetPortal(PortalID, portalParams);

end

function CreateRoom(RoomID, AuxBus, KeepRegistered, AuxSendToSelf, ReverbLevel, TransmissionLoss, GeometrySetID)
	
	-- NOTE
	-- When filling out these lua-wrapped c++ structs, it appears to be necessary to create local copies 
	-- of the entire variable and then assign them to the struct member variable.  Dont try to access nested
	-- members like roomParams.Up.X, or roomParams.pConnectedPortals[i] = 2.
	
	print("CreateRoom: id:" .. RoomID)
	local roomParams = AkRoomParams:new_local()
	
	roomParams.Up.X = 0.0
	roomParams.Up.Y = 1.0
	roomParams.Up.Z = 0.0
	
	roomParams.Front.X = 0.0
	roomParams.Front.Y = 0.0
	roomParams.Front.Z = 1.0
	
	roomParams.strName = "room_" .. RoomID
	
	if (AuxBus ~= nil) then
		print("AuxBus: " .. AuxBus)
		roomParams.ReverbAuxBus = AK.SoundEngine.GetIDFromString(AuxBus)
		roomParams.ReverbLevel = 1.0
	end

	if (ReverbLevel ~= nil) then
		roomParams.ReverbLevel = ReverbLevel
	end
	
	if (KeepRegistered ~= nil) then
		roomParams.RoomGameObj_KeepRegistered=KeepRegistered	
		print("Keeping room_" .. RoomID .. " Registered: " .. tostring(KeepRegistered))
	end
	
	if (AuxSendToSelf ~= nil) then
		print("AuxSendToSelf value: " .. AuxSendToSelf .. " Room: room_" .. RoomID)
		roomParams.RoomGameObj_AuxSendLevelToSelf=AuxSendToSelf
	end
	
	if (TransmissionLoss ~= nil) then
		print("TransmissionLoss: " .. TransmissionLoss)
		roomParams.TransmissionLoss = TransmissionLoss
	else
		roomParams.TransmissionLoss = 1
	end
	
	if ( GeometrySetID ~= nil ) then 
		roomParams.GeometryID = GeometrySetID
	end
	
	roomParams.Priority = 100
	
	AK.SpatialAudio.SetRoom(RoomID, roomParams);

end

function CreateImageSourceSettings(x, y, z, texture, name)

	local position = AkVector:new_local()
	position.X = x
	position.Y = y
	position.Z = z
	
	--LogTestMsg( "Create an image source", 1 )
	local vs = AkImageSourceSettings:new_local()
	vs.sourcePosition = position
	vs:SetOneTexture(texture)
	vs:SetName(name)
	
	return vs

end