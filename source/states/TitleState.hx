package states;

import backend.WeekData;

import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import haxe.Json;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import shaders.ColorSwap;

import states.StoryMenuState;
import states.OutdatedState;
import states.MainMenuState;

import crowplexus.iris.Iris;
import psychlua.HScript;

#if GAMEJOLT_ALLOWED
import hxgamejolt.GameJolt;
#end

typedef MainConf = {
	var Transition:Bool;
	var TransitionType:String;
}

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Float;
	
	@:optional var animation:String;
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	@:optional var idle:Bool;
}

typedef TitleConfig = {
	var StartType:String;
	var Where:String;
}

typedef FreeplayConf = {
	var isCentered:Bool;
	var isIconsEnabled:Bool;
}

typedef ConfigMain = {
	var Freeplay:FreeplayConf;
}

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	#if GAMEJOLT_ALLOWED
	var gameJoltGameID = "949510";
	var privateKey = "a312bb89e09805ebc0fac1069bcc40c4";
	#end

	#if TITLE_SCREEN_EASTER_EGG
	final easterEggKeys:Array<String> = [
		'SHADOW', 'RIVEREN', 'BBPANZU', 'PESSY'
	];
	final allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	var mustUpdate:Bool = false;

	public static var updateVersion:String = '';

	var playerName:String;
	var playerKey:String;
	var autoLogin:Bool = false;






	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null) {
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if(script != null)
			{
				script.executeFunction(funcToCall,args);
			}
		#end
	}

	public function initHScript(file:String)
	{
		var newScript:HScript = null;
		try
		{
			newScript = new HScript(null, file);
			newScript.executeFunction('onCreate');
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
		}
		catch(e:Dynamic)
		{
			addTextToDebug('ERROR ON LOADING ($file) - $e', FlxColor.RED);
			var newScript:HScript = cast (Iris.instances.get(file), HScript);
			if(newScript != null)
				newScript.destroy();
		}
	}

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	public function addTextToDebug(text:String, color:FlxColor) {
	}
	#end

	#if GAMEJOLT_ALLOWED
	function isGameJolt() {
		trace(ClientPrefs.data.gameJoltUsername);
		trace(ClientPrefs.data.gameJoltToken);
		GameJolt.init(gameJoltGameID, privateKey);

		if (ClientPrefs.data.gameJoltUsername == "") {
			autoLogin = false;
		} else if (ClientPrefs.data.gameJoltToken == "") {
			autoLogin = false;
		} else {
			autoLogin = true;
		}

		if (autoLogin == true) {
			playerName = ClientPrefs.data.gameJoltUsername;
			playerKey = ClientPrefs.data.gameJoltToken;
			
			GameJolt.authUser(playerName, playerKey, {
			onSucceed: function(json:Dynamic):Void
			{
					trace("Your Game JOLT Account has been successfully linked.");
			},
			onFail: function(message:String):Void
			{
				ClientPrefs.data.gameJoltUsername = "";
				ClientPrefs.data.gameJoltToken = "";
				ClientPrefs.saveSettings();
					trace("Game Jolt Account not found.");
			}
			});

			GameJolt.fetchUser(playerName, [], {
			onSucceed: function(json:Dynamic):Void
			{
				FlxG.save.data.userJson = json;
					trace("Your Game JOLT Account data has been transferred successfully.");
			},
			onFail: function(message:String):Void
			{
				ClientPrefs.data.gameJoltUsername = "";
				ClientPrefs.data.gameJoltToken = "";
				ClientPrefs.saveSettings();
					trace("Game Jolt Account not found.");
			}
			});
		} else {
			trace(ClientPrefs.data);
			if (ClientPrefs.data.skipGameJoltScreen == false) {
				MusicBeatState.switchState(new GameJoltState());
			}
		}

	}
	#end

	override public function create():Void
	{
		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();

		Main.isFirst = true;

		if(!initialized)
		{
			ClientPrefs.loadPrefs();
			Language.reloadPhrases();
		}

		ClientPrefs.saveSettings();

		curWacky = FlxG.random.getObject(getIntroTextShit());
		
		#if GAMEJOLT_ALLOWED
			isGameJolt();
		#end
 
		#if CHECK_FOR_UPDATES
		if(ClientPrefs.data.checkForUpdates && !closedState) {
			trace('checking for update');
			var http = new haxe.Http("https://raw.githubusercontent.com/SadeceNicat/Hybrid-Engine/Sad/gitVersion.txt");

			http.onData = function (data:String)
			{
				updateVersion = data.split('\n')[0].trim();
				var curVersion:String = MainMenuState.psychEngineVersion.trim();
				trace('version online: ' + updateVersion + ', your version: ' + curVersion);
				if(updateVersion != curVersion) {
					trace('versions arent matching!');
					mustUpdate = true;
				}
			}

			http.onError = function (error) {
				trace('error: $error');
			}

			http.request();
		}
		#end

		if(!initialized)
		{
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
				//trace('LOADED FULLSCREEN SETTING!!');
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		FlxG.mouse.visible = false;

		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if(FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
		{
			startIntro();
		}
		#end
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		persistentUpdate = true;
		if (!initialized && FlxG.sound.music == null)
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
			
		loadMainConfig();
		loadConf();
		loadMainConf();
		loadJsonData();

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/states/HaxeStates/MainMenu/'))
			for (file in FileSystem.readDirectory(folder))
			{
				FlxG.save.data.menuSong = false;
				if (FlxG.save.data.isFirst == true) {
					FlxG.save.data.isFirst = false;
					Main.skipModsScreen = false;
				}
			}

		if (Main.skipModsScreen == false) {
			MusicBeatState.switchState(new ModsMenuState());
		}

		if (FlxG.save.data.menuSong == true && Main.skipModsScreen == true && isNormal == false) {
			trace("Freeplay");
			MusicBeatState.switchState(new FreeplayState());
		}
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		#if TITLE_SCREEN_EASTER_EGG easterEggData(); #end
		Conductor.bpm = musicBPM;


		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/states/HaxeStates/TitleState/'))
			for (file in FileSystem.readDirectory(folder))
			{

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}



		logoBl = new FlxSprite(logoPosition.x, logoPosition.y);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.data.antialiasing;

		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		gfDance = new FlxSprite(gfPosition.x, gfPosition.y);
		gfDance.antialiasing = ClientPrefs.data.antialiasing;
		
		if(ClientPrefs.data.shaders)
		{
			swagShader = new ColorSwap();
			gfDance.shader = swagShader.shader;
			logoBl.shader = swagShader.shader;
		}
		
		gfDance.frames = Paths.getSparrowAtlas(characterImage);
		if(!useIdle)
		{
			gfDance.animation.addByIndices('danceLeft', animationName, danceLeftFrames, "", 24, false);
			gfDance.animation.addByIndices('danceRight', animationName, danceRightFrames, "", 24, false);
			gfDance.animation.play('danceRight');
		}
		else
		{
			gfDance.animation.addByPrefix('idle', animationName, 24, false);
			gfDance.animation.play('idle');
		}


		var animFrames:Array<FlxFrame> = [];
		titleText = new FlxSprite(enterPosition.x, enterPosition.y);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (newTitle = animFrames.length > 0)
		{
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		titleText.animation.play('idle');
		titleText.updateHitbox();

		var logo:FlxSprite = new FlxSprite().loadGraphic(Paths.image('logo'));
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.screenCenter();

		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.antialiasing;

		add(gfDance);
		callOnHScript("onLoad",["gfDance",gfDance]);
		add(logoBl); //FNF Logo
		callOnHScript("onLoad",["logoBl",logoBl]);
		add(titleText); //"Press Enter to Begin" text
		callOnHScript("onLoad",["titleText",titleText]);
		add(credGroup);
		callOnHScript("onLoad",["credGroup",credGroup]);
		add(ngSpr);
		callOnHScript("onLoad",["ngSpr",ngSpr]);

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);

		callOnHScript("onCreatePost",[]);
	}

	// JSON data
	var characterImage:String = 'gfDanceTitle';
	var animationName:String = 'gfDance';

	var gfPosition:FlxPoint = FlxPoint.get(512, 40);
	var logoPosition:FlxPoint = FlxPoint.get(-150, -100);
	var enterPosition:FlxPoint = FlxPoint.get(100, 576);
	
	var useIdle:Bool = false;
	var musicBPM:Float = 102;
	var danceLeftFrames:Array<Int> = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29];
	var danceRightFrames:Array<Int> = [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
	var isIntro:Bool = false;
	var isNormal:Bool = false;

	function loadJsonData()
	{
		if(Paths.fileExists('images/gfDanceTitle.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('images/gfDanceTitle.json');
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:TitleData = tjson.TJSON.parse(titleRaw);
					gfPosition.set(titleJSON.gfx, titleJSON.gfy);
					logoPosition.set(titleJSON.titlex, titleJSON.titley);
					enterPosition.set(titleJSON.startx, titleJSON.starty);
					musicBPM = titleJSON.bpm;
					
					if(titleJSON.animation != null && titleJSON.animation.length > 0) animationName = titleJSON.animation;
					if(titleJSON.dance_left != null && titleJSON.dance_left.length > 0) danceLeftFrames = titleJSON.dance_left;
					if(titleJSON.dance_right != null && titleJSON.dance_right.length > 0) danceRightFrames = titleJSON.dance_right;
					useIdle = (titleJSON.idle == true);
	
					if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.trim().length > 0)
					{
						var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(titleJSON.backgroundSprite));
						bg.antialiasing = ClientPrefs.data.antialiasing;
						add(bg);
						callOnHScript("onLoad",["bg",bg]);
					}
				}
				catch(e:haxe.Exception)
				{
					trace('[WARN] Title JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else trace('[WARN] No Title JSON detected, using default values.');
		}
		//else trace('[WARN] No Title JSON detected, using default values.');
	}

	function loadConf()
	{
		if(Paths.fileExists('config/title.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('config/title.json');
			trace(titleRaw);
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:TitleConfig = tjson.TJSON.parse(titleRaw);
					
					if (titleJSON.StartType == "Normal") {
						FlxG.save.data.menuSong = false;
						trace(titleRaw);
						trace("Normal");
						isNormal = true;
						Main.skipModsScreen = true;
					} else if (titleJSON.StartType == "Song") {
						trace("Song");
						trace(titleJSON);
						// FlxG.save.data.menuSong = true;
						// trace(Main.isFirst);
						// if (Main.isFirst == true) {
						// 	Main.skipModsScreen = false;
						// 	Main.isFirst = false;
						// }
						FlxG.save.data.menuSong = true;
						if (FlxG.save.data.isFirst == true) {
							FlxG.save.data.isFirst = false;
							Main.skipModsScreen = false;
						}

					} else {
						Main.skipModsScreen = true;
						FlxG.save.data.menuSong = false;
						trace(titleRaw);
						trace("Normal Else");
						isNormal = true;
					}

				}
				catch(e:haxe.Exception)
				{
					trace('[WARN] Title JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else trace('[WARN] No Title JSON detected, using default values.');
		} else {
			trace("json not exist");
		}
	}

	function loadMainConf()
	{
		if(Paths.fileExists('config/config.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('config/config.json');
			trace(titleRaw);	
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:ConfigMain = tjson.TJSON.parse(titleRaw);

					trace(titleJSON);
					FlxG.save.data.freeplayCenter = titleJSON.Freeplay.isCentered;
					FlxG.save.data.freeplayIcon = titleJSON.Freeplay.isIconsEnabled;
					
				}
				catch(e:haxe.Exception)
				{
					trace('[WARN] Title JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else trace('[WARN] No Title JSON detected, using default values.');
		} else {
			trace("json not exist");
		}
	}

	function loadMainConfig()
	{
		if(Paths.fileExists('config/menu.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('config/main.json');
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var jsonData:MainConf = tjson.TJSON.parse(titleRaw);

					FlxG.save.data.TransitionType = "Default";

					if (jsonData.Transition == true) {
						FlxG.save.data.isTransition = true;
						if (jsonData.TransitionType == "Sticker") {
							FlxG.save.data.TransitionType = "Sticker";
							trace("Sticker");
						}
					} else {
						FlxG.save.data.isTransition = false;
					}
					trace(FlxG.save.data.isTransition);

				}
				catch(e:haxe.Exception)
				{
					trace('[WARN] JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else trace('[WARN] No JSON detected, using default values.');
		}
	}

	function easterEggData()
	{
		if (FlxG.save.data.psychDevsEasterEgg == null) FlxG.save.data.psychDevsEasterEgg = ''; //Crash prevention
		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		switch(easterEgg.toUpperCase())
		{
			case 'SHADOW':
				characterImage = 'ShadowBump';
				animationName = 'Shadow Title Bump';
				gfPosition.x += 210;
				gfPosition.y += 40;
				useIdle = true;
			case 'RIVEREN':
				characterImage = 'ZRiverBump';
				animationName = 'River Title Bump';
				gfPosition.x += 180;
				gfPosition.y += 40;
				useIdle = true;
			case 'BBPANZU':
				characterImage = 'BBBump';
				animationName = 'BB Title Bump';
				danceLeftFrames = [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27];
				danceRightFrames = [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
				gfPosition.x += 45;
				gfPosition.y += 100;
			case 'PESSY':
				characterImage = 'PessyBump';
				animationName = 'Pessy Title Bump';
				gfPosition.x += 165;
				gfPosition.y += 60;
				danceLeftFrames = [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
				danceRightFrames = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28];
		}
	}

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		callOnHScript("onUpdate",[elapsed]);
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}
		
		if (newTitle) {
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		// EASTER EGG

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;
				
				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			
			if(pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;
				
				if(titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;
				// FlxG.sound.music.stop();
				callOnHScript("onConfirm",[]);

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					if (mustUpdate)
						MusicBeatState.switchState(new OutdatedState());
					else
						MusicBeatState.switchState(new MainMenuState());

					closedState = true;
				});
				// FlxG.sound.play(Paths.music('titleShoot'), 0.7);
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			callOnHScript("onCreateCoolText",[money,textArray,offset]);
			if(credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
			callOnHScript("onAddMoreText",[coolText,text,offset]);
		}
	}

	function deleteCoolText()
	{
		callOnHScript("onDeleteCoolText",[]);
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		callOnHScript("onBeatHit",[sickBeats]);

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		if(gfDance != null)
		{
			danceLeft = !danceLeft;
			if(!useIdle)
			{
				if (danceLeft)
					gfDance.animation.play('danceRight');
				else
					gfDance.animation.play('danceLeft');
			}
			else if(curBeat % 2 == 0) gfDance.animation.play('idle', true);
		}

		if(!closedState)
		{
			sickBeats++;
			callOnHScript("onBeatTexts",[sickBeats]);
			switch (sickBeats)
			{
				case 1:
					//FlxG.sound.music.stop();
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					createCoolText(['Hybrid Engine by'], 40);
				case 4:
					addMoreText('SadeceNicat', 40);
					addMoreText('MolShuggleBeef', 40);
				case 5:
					deleteCoolText();
				case 6:
					createCoolText(['Not associated', 'with'], -40);
				case 8:
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				case 9:
					deleteCoolText();
					ngSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('Friday');
				case 15:
					addMoreText('Night');
				case 16:
					addMoreText('Funkin'); // credTextShit.text += '\nFunkin';

				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		callOnHScript("onSkipIntro",[]);
		if (!skippedIntro)
		{
			#if TITLE_SCREEN_EASTER_EGG
			if (playJingle) //Ignore deez
			{
				playJingle = false;
				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:FlxSound = null;

				transitioning = true;
				if(easteregg == 'SHADOW')
				{
					new FlxTimer().start(3.2, function(tmr:FlxTimer)
					{
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 0.6);
						transitioning = false;
					});
				}
				else
				{
					remove(ngSpr);
					remove(credGroup);
					FlxG.camera.flash(FlxColor.WHITE, 3);
					sound.onComplete = function() {
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						transitioning = false;
						if(easteregg == 'PESSY')
							Achievements.unlock('pessy_easter_egg');
					};
				}
			}
			else #end //Default! Edit this one!!
			{
				remove(ngSpr);
				callOnHScript("onRemove",["ngSpr",ngSpr]);
				remove(credGroup);
				callOnHScript("onRemove",["credGroup",credGroup]);
				FlxG.camera.flash(FlxColor.WHITE, 4);

				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();
			}
			skippedIntro = true;
		}
	}
}
