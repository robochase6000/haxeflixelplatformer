package robochase6000.levels;

import flixel.util.FlxPoint;

class Level
{
	// generates a 2d collision map with walls on the outside (1's)
	public static function cleanMap(width:Int, height:Int):Array<Array<Int>>
	{
		var output:Array<Array<Int>> = [];

		for (i in 0...height)
		{
			output.push([]);
			for (j in 0...width)
			{
				var tile:Int = 0;
				if (i == 0 || j == 0 || i == height-1 || j == width-1) tile = 1;
				output[i].push(tile);
			}
		}

		return output;
	}

	public function new()
	{
		
	}

	public function getCollisionMap():Array<Array<Int>>
	{
		var layout:Array<Array<Int>> = Level.cleanMap(30, 30);
		return layout;
	}

	public function spawnPoint():FlxPoint
	{
		return new FlxPoint(20.0, 225.0);
	}
}