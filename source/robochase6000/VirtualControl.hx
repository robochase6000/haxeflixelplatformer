
package robochase6000;

import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxPoint;

/**
 * A simple button class traceat calls a function when clicked by the mouse.
 */
class VirtualControl extends FlxButton
{
	public var action:String = "";

	/**
	 * Creates a new FlxButton object with a gray background
	 * and a callback function on the UI thread.
	 * 
	 * @param	X				The X position of the button.
	 * @param	Y				The Y position of the button.
	 * @param	Text			The text that you want to appear on the button.
	 * @param	OnClick			The function to call whenever the button is clicked.
	 */
	public function new(actionType:String, X:Float = 0, Y:Float = 0, ?Text:String, ?OnClick:Void->Void)
	{
		super(X, Y, Text, OnClick);
		action = actionType;
		
	}
}