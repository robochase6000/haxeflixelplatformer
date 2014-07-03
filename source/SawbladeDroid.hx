package;

import flixel.effects.particles.FlxEmitter;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxTypedGroup;
import flixel.util.FlxAngle;
import flixel.util.FlxMath;
import flixel.util.FlxPoint;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxVelocity;

class SawbladeDroid extends Enemy
{
	
	public function new()
	{
		super();
		angle = 0;
		angularAcceleration = 0;
	}

	override private function SetAngle():Void
	{
		
	}

	public function collidedWithEnemy(obj:Enemy):Void
	{
		
	}

	override public function canShoot():Bool
	{
		if (velocity.x == 0.0)
		{
			trace("can shoot");
		}
		return false;
	}
}