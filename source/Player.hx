package;

import flixel.effects.particles.FlxEmitter;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxTypedGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.XboxButtonID;
import flixel.ui.FlxButton;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;
#if (android && OUYA)
import flixel.input.gamepad.OUYAButtonID;
#end

import robochase6000.VirtualController;

class Player extends FlxSprite
{
	//#if android
	public static var virtualPad:VirtualController;
	//#end
	
	private static var SHOTS_PER_SECOND:Float = 3.5;
	private static var SHOOT_RATE:Float = 1 / SHOTS_PER_SECOND;
	
	public var isReadyToJump:Bool = true;
	public var flickering:Bool = false;
	
	private var _shootCounter:Float = 0;
	public var jumpPower:Int = 150;
	private var _freemode:Bool = false;
	private var _aim:Int;
	private var _restart:Float = 0;
	private var _gibs:FlxEmitter;
	private var _bullets:FlxTypedGroup<Bullet>;

	public var freeMoveVelocityX = 3;
	public var freeMoveVelocityY = 3;
	
	// Internal private: accessor to first active gamepad
	#if !FLX_NO_GAMEPAD
	private var gamepad(get, never):FlxGamepad;
	private function get_gamepad():FlxGamepad 
	{
		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
		if (gamepad == null)
		{
			// Make sure we don't get a crash on neko when no gamepad is active
			gamepad = FlxG.gamepads.getByID(0);
		}
		return gamepad;
	}
	#end
	
	/**
	 * This is the player object class.  Most of the comments I would put in here
	 * would be near duplicates of the Enemy class, so if you're confused at all
	 * I'd recommend checking that out for some ideas!
	 */
	public function new<T:Bullet>(X:Int, Y:Int, Bullets:FlxTypedGroup<Bullet>, Gibs:FlxEmitter)
	{
		super(X, Y);
		
		loadGraphic(Reg.SPACEMAN, true, 8);
		
		setFacingFlip(FlxObject.LEFT, true, false);
		setFacingFlip(FlxObject.RIGHT, false, false);
		
		// Bounding box tweaks
		width = 6;
		height = 7;
		offset.set(1, 1);
		
		// Basic player physics
		var runSpeed:Int = 60;
		drag.x = runSpeed * 8;
		acceleration.y = 420;
		maxVelocity.set(runSpeed, jumpPower);
		
		// Animations
		animation.add("idle", [0]);
		animation.add("run", [1, 2, 3, 0], 12);
		animation.add("jump", [4]);
		animation.add("idle_up", [5]);
		animation.add("run_up", [6, 7, 8, 5], 12);
		animation.add("jump_up", [9]);
		animation.add("jump_down", [10]);
		
		// Bullet stuff
		_bullets = Bullets;
		_gibs = Gibs;
		
		//#if android
		virtualPad = new VirtualController(LEFT_RIGHT, A_B);
		virtualPad.alpha = 0.05;
		//#end
	}
	
	override public function destroy():Void
	{
		super.destroy();
		
		//#if android
		//virtualPad = FlxG.safeDestroy(virtualPad);
		virtualPad.destroy();
		//#end
		
		_bullets = null;
		_gibs = null;
	}
	
	override public function update():Void
	{
		if(_shootCounter > 0)
			_shootCounter -= FlxG.elapsed;
		
		// Game restart timer
		if (!alive)
		{
			_restart += FlxG.elapsed;
			
			if (_restart > 2)
			{
				FlxG.resetState();
			}
			
			return;
		}
		
		// Make a little noise if you just touched the floor
		if (justTouched(FlxObject.FLOOR) && (velocity.y > 50))
		{
			FlxG.sound.play("Land");
		}
		
		acceleration.x = 0;
		
		// INPUT
		
		if(virtualPad.buttonLeft.status == FlxButton.PRESSED)
		{
			moveLeft();
		}
		else if(virtualPad.buttonRight.status == FlxButton.PRESSED)
		{
			moveRight();
		}

		/*
		if(virtualPad.buttonUp.status == FlxButton.PRESSED)
		{
			moveUp();
		}
		else if(virtualPad.buttonDown.status == FlxButton.PRESSED)
		{
			moveDown();
		}
		*/

		if(virtualPad.buttonA.status == FlxButton.PRESSED)
		{
			jump();
		}
		else if(virtualPad.buttonB.status == FlxButton.PRESSED)
		{
			shoot();
		}

		if (FlxG.keys.justPressed.Z)
		{
			_freemode = !_freemode;
		}

		if (FlxG.keys.pressed.LEFT 
#if !FLX_NO_GAMEPAD
			 || (#if flash gamepad.pressed(XboxButtonID.DPAD_LEFT) #else gamepad.dpadLeft #end ||
	#if OUYA
				 gamepad.getXAxis(OUYAButtonID.LEFT_ANALOGUE_X) < 0) || buttonPressed(virtualPad.buttonLeft)) 
	#else
				 gamepad.getXAxis(XboxButtonID.LEFT_ANALOGUE_X) < 0))
	#end
#else) #end
		{
			moveLeft();
		}
		else if (FlxG.keys.pressed.RIGHT
#if !FLX_NO_GAMEPAD
			 || (#if flash gamepad.pressed(XboxButtonID.DPAD_RIGHT) #else gamepad.dpadRight #end ||
	#if OUYA
				 gamepad.getXAxis(OUYAButtonID.LEFT_ANALOGUE_X) > 0) || buttonPressed(virtualPad.buttonRight))
	#else
				 gamepad.getXAxis(XboxButtonID.LEFT_ANALOGUE_X) > 0))
	#end
#else) #end
		{
			moveRight();
		}
		
		_aim = facing;
		
		// AIMING
		if (FlxG.keys.pressed.UP
#if !FLX_NO_GAMEPAD
			 || (#if flash gamepad.pressed(XboxButtonID.DPAD_UP) #else gamepad.dpadUp #end ||
	#if OUYA
				 gamepad.getYAxis(OUYAButtonID.LEFT_ANALOGUE_Y) < 0) || buttonPressed(virtualPad.buttonUp))
	#else
				 gamepad.getYAxis(XboxButtonID.LEFT_ANALOGUE_Y) < 0))
	#end
#else) #end
		{
			moveUp();
		}
		else if (FlxG.keys.pressed.DOWN
#if !FLX_NO_GAMEPAD
			 || (#if flash gamepad.pressed(XboxButtonID.DPAD_DOWN) #else gamepad.dpadDown #end ||
	#if OUYA
				 gamepad.getYAxis(OUYAButtonID.LEFT_ANALOGUE_Y) > 0) || buttonPressed(virtualPad.buttonDown))
	#else
				 gamepad.getYAxis(XboxButtonID.LEFT_ANALOGUE_Y) > 0))
	#end
#else) #end
		{
			moveDown();
		}
		
		// JUMPING
		if (FlxG.keys.justPressed.X 
#if !FLX_NO_GAMEPAD
	#if OUYA
			|| gamepad.justPressed(OUYAButtonID.O) || buttonPressed(virtualPad.buttonA))
	#else
			|| gamepad.justPressed(XboxButtonID.A))
	#end
#else) #end
		{
			jump();
		}
		
		// ANIMATION
		if (velocity.y != 0)
		{
			if (_aim == FlxObject.UP) 
			{
				animation.play("jump_up");
			}
			else if (_aim == FlxObject.DOWN) 
			{
				animation.play("jump_down");
			}
			else 
			{
				animation.play("jump");
			}
		}
		else if (velocity.x == 0)
		{
			if (_aim == FlxObject.UP) 
			{
				animation.play("idle_up");
			}
			else 
			{
				animation.play("idle");
			}
		}
		else
		{
			if (_aim == FlxObject.UP) 
			{
				animation.play("run_up");
			}
			else 
			{
				animation.play("run");
			}
		}
		
		// SHOOTING
		if (FlxG.keys.pressed.C
#if !FLX_NO_GAMEPAD
	#if OUYA
			|| gamepad.pressed(OUYAButtonID.U) || buttonPressed(virtualPad.buttonB)) 
	#else
			|| gamepad.pressed(XboxButtonID.X))
	#end
#else) #end
		{
			shoot();
		}

		if (_freemode)
		{
			velocity.y = 0;
		}
		
        super.update();
	}
	
	override public function hurt(Damage:Float):Void
	{
		Damage = 0;
		
		if (flickering)
		{
			return;
		}
		
		FlxG.sound.play("Hurt");
		
		flicker(1.3);
		
		if (Reg.score > 1000) 
		{
			Reg.score -= 1000;
		}
		
		if (velocity.x > 0)
		{
			velocity.x = -maxVelocity.x;
		}
		else
		{
			velocity.x = maxVelocity.x;
		}
		
		super.hurt(Damage);
	}
	
	private function flicker(Duration:Float):Void
	{
		FlxSpriteUtil.flicker(this, Duration, 0.02, true, true, function(_) {
			flickering = false;
		});
		flickering = true;
	}
	
	override public function kill():Void
	{
		return;// yeah bitch 
		if (!alive)
		{
			return;
		}
		
		solid = false;
		FlxG.sound.play("Asplode");
		FlxG.sound.play("MenuHit2");
		
		super.kill();
		
		exists = true;
		visible = false;
		velocity.set();
		acceleration.set();
		FlxG.camera.shake(0.005, 0.35);
		FlxG.camera.flash(0xffd8eba2, 0.35);
		
		if (_gibs != null)
		{
			_gibs.at(this);
			_gibs.start(true, 5, 0, 50);
		}
	}
	
	function moveLeft():Void
	{
		facing = FlxObject.LEFT;
		acceleration.x -= drag.x;

		if (_freemode)
		{
			x -= freeMoveVelocityX;
		}
	}
	
	function moveRight():Void
	{
		facing = FlxObject.RIGHT;
		acceleration.x += drag.x;

		if (_freemode)
		{
			x += freeMoveVelocityX;
		}
	}
	
	function moveUp():Void
	{
		_aim = FlxObject.UP;
		if (_freemode)
		{
			y -= freeMoveVelocityY;
		}
	}
	
	function moveDown():Void
	{
		_aim = FlxObject.DOWN;
		if (_freemode)
		{
			y += freeMoveVelocityY;
		}
	}
	
	function jump():Void
	{
		if (!_freemode)
		{
			if (isReadyToJump && (velocity.y == 0))
			{
				velocity.y = -jumpPower;
				FlxG.sound.play("Jump");
			}
		}
	}
	
	function shoot():Void
	{
		if (_shootCounter > 0)
		{
			return;
		}
		_shootCounter = SHOOT_RATE;
		
		if (flickering)
		{
			FlxG.sound.play("Jam");
		}
		else
		{
			getMidpoint(_point);
			_bullets.recycle(Grenade).shoot(_point, _aim);
			
			if (_aim == FlxObject.DOWN)
			{
				velocity.y -= 36;
			}
		}
	}
	
	inline function buttonPressed(button:FlxButton):Bool
	{
		return button.status == FlxButton.PRESSED;
	}
}