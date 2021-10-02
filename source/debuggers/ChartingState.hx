package debuggers;

import game.Conductor;
#if sys
import polymod.backends.PolymodAssets;
import modding.ModdingSound;
#end

import states.LoadingState;
import game.Song;
import states.PlayState;
import flixel.FlxObject;
import flixel.util.FlxColor;
import flixel.addons.display.FlxGridOverlay;
import flixel.FlxG;
import utilities.CoolUtil;
import lime.utils.Assets;
import ui.HealthIcon;
import flixel.system.FlxSound;
import game.Note;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import game.Song.SwagSong;
import flixel.text.FlxText;
import openfl.net.FileReference;
import states.MusicBeatState;

using StringTools;

class ChartingState extends MusicBeatState
{
    // Constants
    var Grid_Size:Int = 40;
    
    // Coolness
    var FileRef:FileReference;
    var SONG:SwagSong;

    // SONG Variables
    var Cur_Section:Int = 0;
    var Song_Name:String = "Test";
    var Difficulty:String = 'Normal';

    var Cur_Mod:String = "default";

    // UI Shit Lmao
    var Info_Text:FlxText;
    var Song_Line:FlxSprite;
    var Grid_Highlight:FlxSprite;

    var Current_Notes:FlxTypedGroup<Note>;
	var Current_Sustains:FlxTypedGroup<FlxSprite>;

    var Note_Grid:FlxSprite;
    var Note_Grid_Above:FlxSprite;
    var Note_Grid_Below:FlxSprite;
    var Note_Grid_Seperator:FlxSprite;

    /* icons lol */

    var Last_Section_Left_Icon:HealthIcon;
    var Section_Left_Icon:HealthIcon;
    var Next_Section_Left_Icon:HealthIcon;

    /* divider between left and right icons lmao */

    var Last_Section_Right_Icon:HealthIcon;
    var Section_Right_Icon:HealthIcon;
    var Next_Section_Right_Icon:HealthIcon;

    /* stop icons lol */

    // Note Variables
    var Selected_Note:Array<Dynamic>;
    var Cur_Note_Char:Int = 0;

    // Other
    var Vocal_Track:FlxSound;

    var Character_Lists:Map<String, Array<String>> = new Map<String, Array<String>>();

    var Camera_Object:FlxObject = new FlxObject();

    var Inst_Track:FlxSound;

    override function create()
    {
        // FOR WHEN COMING IN FROM THE TOOLS PAGE LOL
		if (Assets.getLibrary("shared") == null)
			Assets.loadLibrary("shared");

        #if sys
		var characterList = CoolUtil.coolTextFilePolymod(Paths.txt('characterList'));
		#else
		var characterList = CoolUtil.coolTextFile(Paths.txt('characterList'));
		#end

        for(Text in characterList)
        {
            var Properties = Text.split(":");

            var name = Properties[0];
            var mod = Properties[1];

            var base_array;

            if(Character_Lists.get(mod) != null)
                base_array = Character_Lists.get(mod);
            else
                base_array = [];

            base_array.push(name);
            Character_Lists.set(mod, base_array);
        }

        FlxG.mouse.visible = true;

        updateGrid();

        Camera_Object.screenCenter(X);
        Camera_Object.y = Grid_Size * 26;

        FlxG.camera.follow(Camera_Object);

        if(PlayState.SONG != null)
            SONG = PlayState.SONG;
        else
            SONG = Song.loadFromJson("tutorial", "tutorial");

        SONG.speed = PlayState.previousScrollSpeedLmao;

        loadSong(SONG.song);
		Conductor.changeBPM(SONG.bpm);
		Conductor.mapBPMChanges(SONG);

        Info_Text = new FlxText(0,4,0,"Time: 0.0 / " + (Inst_Track.length / 1000), 20);
        Info_Text.setFormat(null, 20, FlxColor.WHITE, RIGHT);
        Info_Text.x = FlxG.width - Info_Text.width;
        Info_Text.scrollFactor.set();
        add(Info_Text);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var Previous_Y = Camera_Object.y;

        Camera_Object.y += -1 * (FlxG.mouse.wheel * Grid_Size);

        var Above_Value = Note_Grid_Above.y + Note_Grid_Above.height;
        var Below_Value = Note_Grid_Below.y;

        if(((Camera_Object.y <= Above_Value && !Inst_Track.playing) || (Camera_Object.y < Above_Value)) && Previous_Y > Camera_Object.y)
            Camera_Object.y = Below_Value;

        if(Camera_Object.y > Below_Value && Previous_Y < Camera_Object.y)
            Camera_Object.y = Above_Value;

		if (FlxG.keys.justPressed.ENTER)
        {
            FlxG.mouse.visible = false;
            PlayState.SONG = SONG;
            FlxG.sound.music.stop();
            Vocal_Track.stop();
            LoadingState.loadAndSwitchState(new PlayState());
        }

        if (FlxG.keys.justPressed.SPACE)
        {
            if(Inst_Track.playing)
            {
                Inst_Track.pause();

                if(SONG.needsVoices)
                    Vocal_Track.pause();
            }
            else
            {
                if(SONG.needsVoices)
                    Vocal_Track.time = Inst_Track.time;

                Inst_Track.play();

                if(SONG.needsVoices)
                    Vocal_Track.play();
            }
        }

        Conductor.songPosition = Inst_Track.time;

        updateCurStep();

        Info_Text.text = (
            "Time: " + (Inst_Track.time / 1000) + " / " + (Inst_Track.length / 1000) +
            "\n" + "Cur Beat: " + curBeat +
            "\n" + "Cur Step: " + curStep +
            "\n"
        );

        Info_Text.x = FlxG.width - Info_Text.width;
    }

    function updateGrid()
    {
        Note_Grid_Above = FlxGridOverlay.create(Grid_Size, Grid_Size, Grid_Size * 8, Grid_Size * 16);

        Note_Grid_Above.screenCenter();
        Note_Grid_Above.color = FlxColor.fromRGB(180, 180, 180);

        add(Note_Grid_Above);

        Note_Grid = FlxGridOverlay.create(Grid_Size, Grid_Size, Grid_Size * 8, Grid_Size * 16);

        Note_Grid.screenCenter();
        Note_Grid.y = Note_Grid_Above.y + Note_Grid_Above.height;

        add(Note_Grid);

        Note_Grid_Below = FlxGridOverlay.create(Grid_Size, Grid_Size, Grid_Size * 8, Grid_Size * 16);

        Note_Grid_Below.screenCenter();
        Note_Grid_Below.y = Note_Grid.y + Note_Grid.height;
        Note_Grid_Below.color = FlxColor.fromRGB(180, 180, 180);

        add(Note_Grid_Below);

        /* THIS SECTION */
        Section_Left_Icon = new HealthIcon('bf');
		Section_Left_Icon.scrollFactor.set(1, 1);
		Section_Left_Icon.setGraphicSize(Grid_Size);
		Section_Left_Icon.updateHitbox();
        Section_Left_Icon.x = Note_Grid.x - Section_Left_Icon.width;
        Section_Left_Icon.y = Note_Grid.y;
		add(Section_Left_Icon);

        Section_Right_Icon = new HealthIcon('dad');
        Section_Right_Icon.scrollFactor.set(1, 1);
        Section_Right_Icon.setGraphicSize(Grid_Size);
        Section_Right_Icon.updateHitbox();
        Section_Right_Icon.x = Note_Grid.x + Note_Grid.width;
        Section_Right_Icon.y = Note_Grid.y;
		add(Section_Right_Icon);

        /* NEXT SECTION */
        Next_Section_Left_Icon = new HealthIcon('dad');
		Next_Section_Left_Icon.scrollFactor.set(1, 1);
		Next_Section_Left_Icon.setGraphicSize(Grid_Size);
		Next_Section_Left_Icon.updateHitbox();
        Next_Section_Left_Icon.x = Note_Grid_Below.x - Next_Section_Left_Icon.width;
        Next_Section_Left_Icon.y = Note_Grid_Below.y;
		add(Next_Section_Left_Icon);

        Next_Section_Right_Icon = new HealthIcon('bf');
        Next_Section_Right_Icon.scrollFactor.set(1, 1);
        Next_Section_Right_Icon.setGraphicSize(Grid_Size);
        Next_Section_Right_Icon.updateHitbox();
        Next_Section_Right_Icon.x = Note_Grid_Below.x + Note_Grid_Below.width;
        Next_Section_Right_Icon.y = Note_Grid_Below.y;
		add(Next_Section_Right_Icon);

        /* COOL SHIT */
        Note_Grid_Seperator = new FlxSprite(Note_Grid_Above.x + Note_Grid_Above.width / 2, Note_Grid_Above.y);
        Note_Grid_Seperator.makeGraphic(2, Std.int(Note_Grid_Above.height + Note_Grid.height + Note_Grid_Below.height), FlxColor.BLACK);
        add(Note_Grid_Seperator);

        Song_Line = new FlxSprite();
        Song_Line.makeGraphic(Std.int(Note_Grid.width), 2);
        Song_Line.screenCenter();
        Song_Line.scrollFactor.set();
        add(Song_Line);
    }

    function loadSong(daSong:String):Void
    {
        if (FlxG.sound.music != null)
            FlxG.sound.music.stop();

        #if sys
        if(Assets.exists(Paths.inst(daSong)))
            FlxG.sound.music = new FlxSound().loadEmbedded(Paths.inst(daSong));
        else
            FlxG.sound.music = new ModdingSound().loadByteArray(PolymodAssets.getBytes(Paths.instSYS(daSong)));

        FlxG.sound.music.persist = true;

        #else
        FlxG.sound.music = new FlxSound().loadEmbedded(Paths.inst(daSong));
        FlxG.sound.music.persist = true;
        #end
        
        if (SONG.needsVoices)
        {
            #if sys
            if(Assets.exists(Paths.voices(daSong)))
                Vocal_Track = new FlxSound().loadEmbedded(Paths.voices(daSong));
            else
                Vocal_Track = new ModdingSound().loadByteArray(PolymodAssets.getBytes(Paths.voicesSYS(daSong)));
            #else
            Vocal_Track = new FlxSound().loadEmbedded(Paths.voices(daSong));
            #end
        }
        else
            Vocal_Track = new FlxSound();

        FlxG.sound.list.add(Vocal_Track);

        FlxG.sound.music.pause();
        Vocal_Track.pause();

        FlxG.sound.music.onComplete = function()
        {
            if(SONG.needsVoices && Vocal_Track.playing)
            {
                Vocal_Track.pause();
                Vocal_Track.time = 0;
            }

            FlxG.sound.music.pause();
            FlxG.sound.music.time = 0;
            //changeSection();
        };

        Inst_Track = FlxG.sound.music;
    }
}