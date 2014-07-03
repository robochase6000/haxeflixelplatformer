package;

import Bullet;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.util.FlxPoint;

class Grenade extends Bullet
{
	public function new()
	{
		super();
		_lifetime = 1.0;
	}
	
	override public function update():Void
	{
		velocity.y += 8;
		super.update();
	}

	override private function handleCollision():Void
	{
		if (justTouched( FlxObject.FLOOR ))
		{
			velocity.y *= -1;
		}
		else if (justTouched(FlxObject.CEILING))
		{
			velocity.y *= -1;
		}
		else if (justTouched(FlxObject.LEFT))
		{
			velocity.x *= -1;
		}
		else if (justTouched(FlxObject.RIGHT))
		{
			velocity.x *= -1;
		}
	}
}