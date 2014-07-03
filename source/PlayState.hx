package;

import flash.display.BitmapData;

import flixel.effects.particles.FlxEmitter;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tile.FlxTilemap;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxPoint;
import flixel.util.FlxRandom;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;

import robochase6000.Level;
import robochase6000.VirtualControl;

#if (cpp || neko)
import flixel.input.gamepad.FlxGamepad;
#end

@:bitmap("assets/images/virtualControls/dpadLeft.png")
private class DpadLeftGraphic extends BitmapData {}
@:bitmap("assets/images/virtualControls/dpadRight.png")
private class DpadRightGraphic extends BitmapData {}

@:bitmap("assets/images/virtualControls/a.png")
private class AGraphic extends BitmapData {}
@:bitmap("assets/images/virtualControls/b.png")
private class BGraphic extends BitmapData {}

@:bitmap("assets/images/virtualControls/l.png")
private class LGraphic extends BitmapData {}
@:bitmap("assets/images/virtualControls/r.png")
private class RGraphic extends BitmapData {}

/**
 * A FlxState which can be used for the actual gameplay.
 */
class PlayState extends FlxState
{
	public static inline var TILE_SIZE:Int = 8;
	public static inline var TILE_WIDTH:Int = 8;
	public static inline var TILE_HEIGHT:Int = 8;
	public static inline var MAP_WIDTH_IN_TILES:Int = 10;
	public static inline var MAP_HEIGHT_IN_TILES:Int = 10;
	
	private var _map:Array<Int>;
	private var _tileMap:FlxTilemap;
	
	// Major game object storage
	private var _decorations:FlxGroup;
	private var _bullets:FlxTypedGroup<Bullet>;
	private var _player:Player;
	private var _enemies:FlxTypedGroup<Enemy>;
	private var _spawners:FlxTypedGroup<Spawner>;
	private var _enemyBullets:FlxTypedGroup<EnemyBullet>;
	private var _littleGibs:FlxEmitter;
	private var _bigGibs:FlxEmitter;
	private var _hud:FlxGroup;
	private var _gunjam:FlxGroup;
	
	// Meta groups, to help speed up collisions-+
	
	private var _objects:FlxGroup;
	private var _hazards:FlxGroup;
	
	// HUD/User Interface stuff
	private var _score:FlxText;
	private var _score2:FlxText;
	private var _scoreTimer:Float;
	private var _jamTimer:Float;
	
	// Just to prevent weirdness during level transition
	private var _fading:Bool;

	public var dpadLeftButton:VirtualControl;
	public var dpadRightButton:VirtualControl;
	public var aButton:VirtualControl;
	public var bButton:VirtualControl;
	public var lButton:VirtualControl;
	public var rButton:VirtualControl;

	/**
	 * Box to show the user where they're placing stuff
	 */ 
	private var _highlightBox:FlxSprite;


	
	/**
	 * Function that is called up when to state is created to set it up. 
	 */
	override public function create():Void
	{
		#if (web || desktop)
		FlxG.mouse.visible = true;
		#else
		FlxG.mouse.visible = false;
		#end
		
		// Here we are creating a pool of 100 little metal bits that can be exploded.
		// We will recycle the crap out of these!
		_littleGibs = new FlxEmitter();
		_littleGibs.setXSpeed( -150, 150);
		_littleGibs.setYSpeed( -200, 0);
		_littleGibs.setRotation( -720, -720);
		_littleGibs.gravity = 350;
		_littleGibs.bounce = 0.5;
		_littleGibs.makeParticles(Reg.GIBS, 100, 10, true, 0.5);
		
		// Next we create a smaller pool of larger metal bits for exploding.
		_bigGibs = new FlxEmitter();
		_bigGibs.setXSpeed( -200, 200);
		_bigGibs.setYSpeed( -300, 0);
		_bigGibs.setRotation( -720, -720);
		_bigGibs.gravity = 350;
		_bigGibs.bounce = 0.35;
		_bigGibs.makeParticles(Reg.SPAWNER_GIBS, 50, 20, true, 0.5);
		
		// Then we'll set up the rest of our object groups or pools
		_decorations = new FlxGroup();
		_enemies = new FlxTypedGroup<Enemy>();
		
		#if flash
		_enemies.maxSize = 50;
		#else
		_enemies.maxSize = 25;
		#end
		_spawners = new FlxTypedGroup<Spawner>();
		_hud = new FlxGroup();
		_enemyBullets = new FlxTypedGroup<EnemyBullet>();
		#if flash
		_enemyBullets.maxSize = 100;
		#else
		_enemyBullets.maxSize = 50;
		#end
		
		_bullets = new FlxTypedGroup<Bullet>();
		_bullets.maxSize = 20;
		
		// Now that we have references to the bullets and metal bits,
		// we can create the player object.
		_player = new Player(30, 345, _bullets, _littleGibs);
		
		// This refers to a custom function down at the bottom of the file
		// that creates all our level geometry with a total size of 640x480.
		// This in turn calls buildRoom() a bunch of times, which in turn
		// is responsible for adding the spawners and spawn-cameras.
		generateLevel(new Level());
		
		// Add bots and spawners after we add blocks to the state,
		// so that they're drawn on top of the level, and so that
		// the bots are drawn on top of both the blocks + the spawners.
		add(_spawners);
		add(_littleGibs);
		add(_bigGibs);
		add(_decorations);
		add(_enemies);

		// Then we add the player and set up the scrolling camera,
		// which will automatically set the boundaries of the world.
		add(_player);
		
		FlxG.camera.setBounds(0, 0, 960*2, 640*2, true);
		FlxG.camera.follow(_player, FlxCamera.STYLE_PLATFORMER);
		
		// We add the bullets to the scene here,
		// so they're drawn on top of pretty much everything
		add(_enemyBullets);
		add(_bullets);
		add(_hud);

		#if (web || desktop)
			_highlightBox = new FlxSprite(0, 0);
			_highlightBox.makeGraphic(TILE_WIDTH, TILE_HEIGHT, FlxColor.TRANSPARENT);
			FlxSpriteUtil.drawRect(_highlightBox, 0, 0, TILE_WIDTH - 1, TILE_HEIGHT - 1, FlxColor.TRANSPARENT, { thickness: 1, color: FlxColor.RED });
			add(_highlightBox);
		#end
		
		// Finally we are going to sort things into a couple of helper groups.
		// We don't add these groups to the state, we just use them for collisions later!
		_hazards = new FlxGroup();
		_hazards.add(_enemyBullets);
		_hazards.add(_spawners);
		_hazards.add(_enemies);
		_objects = new FlxGroup();
		_objects.add(_enemyBullets);
		_objects.add(_bullets);
		_objects.add(_enemies);
		_objects.add(_player);
		_objects.add(_littleGibs);
		_objects.add(_bigGibs);
		
		// From here on out we are making objects for the HUD,
		// that is, the player score, number of spawners left, etc.
		// First, we'll create a text field for the current score
		_score = new FlxText(FlxG.width / 4, 0, Math.floor(FlxG.width / 2));
		_score.setFormat(null, 16, 0xd8eba2, "center", FlxText.BORDER_OUTLINE_FAST, 0x131c1b);
		_hud.add(_score);
		
		if (Reg.scores.length < 2)
		{
			Reg.scores.push(0);
			Reg.scores.push(0);
		}
		
		// Then for the player's highest and last scores
		if (Reg.score > Reg.scores[0])
		{
			Reg.scores[0] = Reg.score;
		}
		
		if (Reg.scores[0] != 0)
		{
			_score2 = new FlxText(FlxG.width / 2, 0, Math.floor(FlxG.width / 2));
			_score2.setFormat(null, 8, 0xd8eba2, "right", _score.borderStyle, _score.borderColor);
			_hud.add(_score2);
			_score2.text = "HIGHEST: " + Reg.scores[0] + "\nLAST: " + Reg.score;
		}
		
		Reg.score = 0;
		_scoreTimer = 0;
		
		// Then we create the "gun jammed" notification
		_gunjam = new FlxGroup();
		_gunjam.add(new FlxSprite(0, FlxG.height - 22).makeGraphic(FlxG.width, 24, 0xff131c1b));
		_gunjam.add(new FlxText(0, FlxG.height - 22, FlxG.width, "GUN IS JAMMED").setFormat(null, 16, 0xd8eba2, "center"));
		_gunjam.visible = false;
		_hud.add(_gunjam);

		//===============================================================================
		// add virtual controls
		//===============================================================================
		var buttonWidth:Float = 64.0;
		var buttonHeight:Float = 97.0;
		
		dpadLeftButton = new VirtualControl("left", 0, FlxG.height-buttonHeight, "", null);
		dpadLeftButton.loadGraphic(DpadLeftGraphic);

		dpadRightButton = new VirtualControl("right", dpadLeftButton.x + buttonWidth, dpadLeftButton.y, "", null);
		dpadRightButton.loadGraphic(DpadLeftGraphic);

		aButton = new VirtualControl("shoot", FlxG.width-buttonWidth, dpadLeftButton.y, "", null);
		aButton.loadGraphic(AGraphic);

		bButton = new VirtualControl("jump", aButton.x - buttonWidth, dpadLeftButton.y, "", null);
		bButton.loadGraphic(BGraphic);

		lButton = new VirtualControl("skill1", 0, 0, "", null);
		lButton.loadGraphic(LGraphic);

		rButton = new VirtualControl("skill2", FlxG.width-102, 0, "", null);
		rButton.loadGraphic(RGraphic);

		// _hud.add(dpadLeftButton);		
		// _hud.add(dpadRightButton);		
		// _hud.add(aButton);		
		// _hud.add(bButton);		
		// _hud.add(lButton);		
		// _hud.add(rButton);		

		//===============================================================================
		// After we add all the objects to the HUD, we can go through
		// and set any property we want on all the objects we added
		// with this sweet function.  In this case, we want to set
		// the scroll factors to zero, to make sure the HUD doesn't
		// wiggle around while we play.
		//===============================================================================
		_hud.setAll("scrollFactor", FlxPoint.get(0, 0));

		// special camera just for the hud.
		var hudCamera:FlxCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height, 0);
		//_hud.setAll("cameras", [hudCamera]);
		//FlxG.cameras.add(hudCamera);
				
		FlxG.cameras.flash(0xff131c1b);
		_fading = false;
		
		FlxG.sound.playMusic("Mode");
		FlxG.sound.list.maxSize = 20;
		
		// Debugger Watch examples
		FlxG.watch.add(_player, "x");
		FlxG.watch.add(_player, "y");
		FlxG.watch.add(_player, "jumpPower");
		FlxG.watch.add(_player, "maxVelocity");
		//FlxG.watch.add(FlxG.camera, "zoom");
		FlxG.watch.add(_enemies, "length", "numEnemies");
		FlxG.watch.add(_enemyBullets, "length", "numEnemyBullets");
		FlxG.watch.add(FlxG.sound.list, "length", "numSounds");
		
		//#if android
		add(Player.virtualPad);
		//#end
		
		super.create();
	}
	
	/**
	 * Function that is called when this state is destroyed - you might want to 
	 * consider setting all objects this state uses to null to help garbage collection.
	 */
	override public function destroy():Void
	{
		super.destroy();
		
		_decorations = null;
		_bullets = null;
		_player = null;
		_enemies = null;
		_spawners = null;
		_enemyBullets = null;
		_littleGibs = null;
		_bigGibs = null;
		_hud = null;
		_gunjam = null;
		
		// Meta groups, to help speed up collisions
		_objects = null;
		_hazards = null;
		
		// HUD/User Interface stuff
		_score = null;
		_score2 = null;
		
		_map = null;
		_tileMap = null;
		
		super.destroy();
	}

	private var _mouseTileX:Int = -1;
	private var _mouseTileY:Int = -1;

	/**
	 * Function that is called once every frame.
	 */
	override public function update():Void
	{
		// Save off the current score and update the game state
		var oldScore:Int = Reg.score;
		
		super.update();
		
		// Collisions with environment
		FlxG.collide(_tileMap, _objects);
		FlxG.collide(_enemies, _enemies, enemiesCollided);
		FlxG.overlap(_hazards, _player, overlapped);
		FlxG.overlap(_bullets, _hazards, overlapped);

		#if (web || desktop)
			// position highlight box
			var mouseTileX:Int = Std.int(FlxG.mouse.x / TILE_WIDTH);
			var mouseTileY:Int = Std.int(FlxG.mouse.y / TILE_HEIGHT);
			_highlightBox.x = mouseTileX * TILE_WIDTH;
			_highlightBox.y = mouseTileY * TILE_HEIGHT;
			
			// draw tiles
			if (FlxG.mouse.pressed && (mouseTileX != _mouseTileX || mouseTileY != _mouseTileY))
			{
				_mouseTileX = mouseTileX;
				_mouseTileY = mouseTileY;

				// FlxTilemaps can be manually edited at runtime as well.
				// Setting a tile to 0 removes it, and setting it to anything else will place a tile.
				// If auto map is on, the map will automatically update all surrounding tiles.
				var tile:Int = FlxG.keys.pressed.SHIFT ? 0 : 1;
				_tileMap.setTile(_mouseTileX, _mouseTileY, tile);

				// apply symmetry for easy editing
				_tileMap.setTile(99-_mouseTileX, _mouseTileY, tile);

				printMap(_tileMap);
			}
		#end
			
		// Check to see if the player scored any points this frame
		var scoreChanged:Bool = oldScore != Reg.score;
		
		// Jammed message
		if (FlxG.keys.justPressed.C && _player.flickering)
		{
			_jamTimer = 1;
			_gunjam.visible = true;
		}
		
		if (_jamTimer > 0)
		{
			if (!_player.flickering)
			{
				_jamTimer = 0;
			}
			
			_jamTimer -= FlxG.elapsed;
			
			if (_jamTimer < 0)
			{
				_gunjam.visible = false;
			}
		}
		
		if (!_fading)
		{
			// Score + countdown stuffs
			if (scoreChanged)
			{
				_scoreTimer = 2;
			}
			
			_scoreTimer -= FlxG.elapsed;
			
			if (_scoreTimer < 0)
			{
				if (Reg.score > 0)
				{
					if (Reg.score > 100)
					{
						Reg.score -= 100;
					}
					else
					{
						Reg.score = 0;
						_player.kill();
					}
					
					_scoreTimer = 1;
					scoreChanged = true;
					
					// Play loud beeps if your score is low
					var volume:Float = 0.35;
					
					if (Reg.score < 600)
					{
						volume = 1.0;
					}
					
					FlxG.sound.play("Countdown", volume);
				}
			}
			
			// Fade out to victory screen stuffs
			if (false && _spawners.countLiving() <= 0)
			{
				_fading = true;
				FlxG.cameras.fade(0xffd8eba2, 3, false, onVictory);
			}
		}
		
		// Actually update score text if it changed
		if (scoreChanged)
		{
			if (!_player.alive) 
			{
				Reg.score = 0;
			}
			
			_score.text = Std.string(Reg.score);
		}
		
		// Escape to the main menu
		if (FlxG.keys.pressed.ESCAPE)
		{
			FlxG.switchState(new MenuState());
		}
	}

	private function enemiesCollided(Sprite1:FlxObject, Sprite2:FlxObject):Void
	{
		if (Std.is(Sprite1, Enemy) && Std.is(Sprite2, Enemy))
		{
			//Sprite1.collidedWithEnemy(Sprite2);
			//Sprite2.collidedWithEnemy(Sprite1);
		}
	}
	
	/**
	 * This is an overlap callback function, triggered by the calls to FlxU.overlap().
	 */
	private function overlapped(Sprite1:FlxObject, Sprite2:FlxObject):Void
	{
		if (Std.is(Sprite1, EnemyBullet) || Std.is(Sprite1, Bullet))
		{
			if (Std.is(Sprite2, FlxTilemap ))
			{
				cast(Sprite1,Bullet).hitWall();
			}
			else
			{
				Sprite1.kill();
			}
		}
		
		Sprite2.hurt(1);
	}
	
	/**
	 * A FlxG.fade callback, like in MenuState.
	 */
	private function onVictory():Void
	{
		// Reset the sounds for going inbetween the menu etc
		FlxG.sound.destroy(true);
		FlxG.switchState(new VictoryState());
	}

	private function printMap(map:FlxTilemap):Void
	{
		#if (web || desktop)
			var output:String = "\n";
			output += "var layout:Array<Array<Int>> = [\n";
			for(y in 0...map.heightInTiles)
			{
				output += "\t[";
				for(x in 0...map.widthInTiles)
				{
					var tile:Int = map.getTile(x,y);
					output += tile;
					if (x < map.widthInTiles-1) output += ",";
				}
				output += "]";
				if (y < map.heightInTiles-1) output += ",\n";
			}
			output += "\n];";

			trace(output);
		#end
	}
	
	/**
	 * These next two functions look crazy, but all they're doing is 
	 * generating the level structure and placing the enemy spawners.
	 */
	private function generateLevel(level:Level):Void
	{
		var layout:Array<Array<Int>> = level.getCollisionMap();
		var mapWidth:Int = layout[0].length;
		var mapHeight:Int = layout.length;

		var r:Int = 160;
		
		_map = new Array<Int>();
		var numTilesTotal:Int = mapWidth * mapHeight;
		
		for (i in 0...numTilesTotal)
		{
			_map[i] = 0;
		}

		var enemy:Enemy = Type.createInstance(SawbladeDroid, null);
		enemy.init(30, 30, null, _littleGibs, _player);
		enemy.angle = 90;
		_enemies.add(enemy);

		enemy = Type.createInstance(SawbladeDroid, null);
		enemy.init(200, 30, null, _littleGibs, _player);
		enemy.angle = 270;
		_enemies.add(enemy);

		FlxG.watch.add(enemy, "angle");
		FlxG.watch.add(_player, "freeMoveVelocityY");

		//var sp:Spawner = new Spawner(50, 50, _bigGibs, _enemies, _enemyBullets, _littleGibs, _player);
		//_spawners.add(sp);
		
		// First, we create the walls, ceiling and floors:
		//fillTileMapRectWithRandomTiles(0, 0, 640, 16, 1, 6, _map, MAP_WIDTH_IN_TILES);
		//fillTileMapRectWithRandomTiles(0, 16, 16, 640 - 16, 1, 6, _map, MAP_WIDTH_IN_TILES);
		//fillTileMapRectWithRandomTiles(640 - 16, 16, 16, 640 - 16, 1, 6, _map, MAP_WIDTH_IN_TILES);
		//fillTileMapRectWithRandomTiles(16, 640 - 24, 640 - 32, 8, 16, 17, _map, MAP_WIDTH_IN_TILES);
		//fillTileMapRectWithRandomTiles(16, 640 - 16, 640 - 32, 16, 32, 47, _map, MAP_WIDTH_IN_TILES);

		for(y in 0...mapHeight)
		{
			var count:Int = layout[y].length;
			for(x in 0...mapWidth)
			{
				setTile(x,y,layout[0].length,layout[y][x]);
			}
		}
		//setTile(17, 640-33, MAP_WIDTH_IN_TILES, 1);
		
		// Then we split the game world up into a 4x4 grid,
		// and generate some blocks in each area. Some grid spaces
		// also get a spawner!
		//buildRoom(r * 0, r * 0, true);
		//buildRoom(r * 1, r * 0);
		//buildRoom(r * 2, r * 0);
		//buildRoom(r * 3, r * 0, true);
		//buildRoom(r * 0, r * 1, true);
		//buildRoom(r * 1, r * 1);
		//buildRoom(r * 2, r * 1);
		//buildRoom(r * 3, r * 1, true);
		//buildRoom(r * 0, r * 2);
		//buildRoom(r * 1, r * 2);
		//buildRoom(r * 2, r * 2);
		//buildRoom(r * 3, r * 2);
		//buildRoom(r * 0, r * 3, true);
		//buildRoom(r * 1, r * 3);
		//buildRoom(r * 2, r * 3);
		//buildRoom(r * 3, r * 3, true);
		//
		_tileMap = new FlxTilemap();
		_tileMap.tileScaleHack = 1.05;
		//_tileMap.scale = new FlxPoint(2.0,2.0);
		_tileMap.loadMap(FlxStringUtil.arrayToCSV(_map, mapWidth), Reg.IMG_TILES, 8, 8, FlxTilemap.OFF);
		add(_tileMap);
	}
	
	/**
	 * Just plops down a spawner and some blocks - haphazard and crappy atm but functional!
	 */
	private function buildRoom(RX:Int, RY:Int, ?Spawners:Bool = false):Void
	{
		// First place the spawn point (if necessary)
		var rw:Int = 20;
		var sx:Int = 0;
		var sy:Int = 0;
		
		if (Spawners)
		{
			sx = FlxRandom.intRanged(2, rw - 6);
			sy = FlxRandom.intRanged(2, rw - 6);
		}
		
		// Then place a bunch of blocks
		var numBlocks:Int = FlxRandom.intRanged(3, 6);
		var maxW:Int = 10;
		var minW:Int = 2;
		var maxH:Int = 8;
		var minH:Int = 1;
		var bx:Int;
		var by:Int;
		var bw:Int;
		var bh:Int;
		var check:Bool;
		
		if (!Spawners) 
		{
			numBlocks++;
		}
		
		for (i in 0...numBlocks)
		{
			do
			{
				// Keep generating different specs if they overlap the spawner
				bw = FlxRandom.intRanged(minW, maxW);
				bh = FlxRandom.intRanged(minH, maxH);
				bx = FlxRandom.intRanged( -1, rw - bw);
				by = FlxRandom.intRanged( -1, rw - bh);
				
				if (Spawners)
				{
					check = ((sx>bx+bw) || (sx+3<bx) || (sy>by+bh) || (sy+3<by));
				}
				else
				{
					check = true;
				}
			} while (!check);
			
			fillTileMapRectWithRandomTiles(RX + bx * 8, RY + by * 8, bw * 8, bh * 8, 1, 6, _map, MAP_WIDTH_IN_TILES);
			
			// If the block has room, add some non-colliding "dirt" graphics for variety
			if ((bw >= 4) && (bh >= 5))
			{
				fillTileMapRectWithRandomTiles(RX + bx * 8 + 8, RY + by * 8, bw * 8 - 16, 8, 16, 17, _map, MAP_WIDTH_IN_TILES);
				fillTileMapRectWithRandomTiles(RX + bx * 8 + 8, RY + by * 8 + 8, bw * 8 - 16, bh * 8 - 24, 32, 47, _map, MAP_WIDTH_IN_TILES);
			}
		}
		
		if (Spawners)
		{
			// Finally actually add the spawner
			var sp:Spawner = new Spawner(RX + sx * 8, RY + sy * 8, _bigGibs, _enemies, _enemyBullets, _littleGibs, _player);
			_spawners.add(sp);
			
			// Then create a dedicated camera to watch the spawner
			var miniFrame:FlxSprite = new FlxSprite(3 + (_spawners.length - 1) * 16, 3, Reg.MINI_FRAME);
			miniFrame.y += 65.0;
			//_hud.add(miniFrame);
			
			var ratio:Float = FlxCamera.defaultZoom / 2;
			//var camera:FlxCamera = new FlxCamera(Math.floor(ratio * (10 + (_spawners.length - 1) * 32)), Math.floor(ratio * 10), 24, 24, ratio);
			var camera:FlxCamera = new FlxCamera(Math.floor(ratio * (10 + (_spawners.length - 1) * 32)), Math.floor(ratio * 10), 64, 64, ratio);
			camera.y += 65.0;
			camera.follow(sp, FlxCamera.STYLE_NO_DEAD_ZONE);
			//FlxG.cameras.add(camera);
		}
	}
	
	private function fillTileMapRectWithRandomTiles(X:Int, Y:Int, Width:Int, Height:Int, StartTile:Int, EndTile:Int, MapArray:Array<Int>, MapWidth:Int):Array<Int>
	{
		var numColsToPush:Int = Math.floor(Width / TILE_SIZE);
		var numRowsToPush:Int = Math.floor(Height / TILE_SIZE);
		var xStartIndex:Int = Math.floor(X / TILE_SIZE);
		var yStartIndex:Int = Math.floor(Y / TILE_SIZE);
		var startColToPush:Int = Math.floor(X / TILE_SIZE);
		var startRowToPush:Int = Math.floor(Y / TILE_SIZE);
		var randomTile:Int;
		var currentTileIndex:Int;
		
		for (i in 0...numRowsToPush)
		{
			for (j in 0...numColsToPush)
			{
				randomTile = FlxRandom.intRanged(StartTile, EndTile);
				
				currentTileIndex = (xStartIndex + j) + (yStartIndex + i) * MapWidth;
				_map[currentTileIndex] = randomTile;
			}
		}
		
		return _map;
	}

	private function setTile(X:Int, Y:Int, MapWidth:Int, Tile:Int):Array<Int>
	{
		var currentTileIndex:Int = X + Y * MapWidth;
		_map[currentTileIndex] = Tile;
		return _map;
	}
}
