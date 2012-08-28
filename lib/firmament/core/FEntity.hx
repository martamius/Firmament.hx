package firmament.core;
import firmament.core.FRenderable;
import nme.display.BitmapData;
import nme.display.Tilesheet;
import nme.geom.Rectangle;
import firmament.core.FTilesheetRenderer;
import nme.geom.Point;
import firmament.core.FEntityComponent;

import nme.Assets;
 
 /**
  * Class: FEntity 
  * Base class for all entities in Firmament
  * 
  * 
  */
class FEntity 
{
	var config:Dynamic;
	var components:Hash<FEntityComponent>;
	/**
	 * Constructor: new
	 * 
	 * Config Paramers:
		 * imageScale - [Float] The initial scale value for the sprite.
		 * sprite  - [BitmapData] The image to use as a sprite for this entity
	 */
	public function new(world:FWorld,config:Dynamic) 
	{
		super();
		this.world = world;
		this.config = config;
		world.addEntity(this);
		
		
		if (Std.is(config.imageScale, Int)) {
				this.imageScale = config.imageScale;
		}
		
		
		if (Std.is(config.sprite, BitmapData)) {
			this.setCurrentImage(config.sprite);
			this.renderer = new FTilesheetRenderer();
		}else if (Std.is(config.sprite, String)){
			var s=Assets.getBitmapData(config.sprite);
			if(s==null){
				throw("Could not load sprite data "+ config.sprite);
			}
			config.sprite = s;
			this.setCurrentImage(s);
			this.renderer = new FTilesheetRenderer();
		}else {
			this.renderer = new FWireframeRenderer();
		}
	}
	
	
	/**
	 * Function: getComponent
	 * @return
	 */
	public function getComponent(type:String):FEntityComponent {
		return this.components.get(type);
	}
	
	public function setComponent(component:FEntityComponent) {
		
	}
	
	/**
	 * Function: getCurrentImage
	 * Returns a BitmapData object of the current image
	 */
	override public function getCurrentImage():BitmapData {
		return this.currentImage;
	}
	/**
	 * Function: setCurrentImage
	 * Sets the current image.
	 */
	public function setCurrentImage(i:BitmapData){
			this.currentImage=i;
			tilesheet = new Tilesheet(i);
			tilesheet.addTileRect(new Rectangle (0, 0, i.width, i.height),new Point(i.width/2,i.height/2));
	}
	
	public function getConfig():Dynamic {
		return this.config;
	}
	
	/**
	 * Function: getTilesheet
	 * returns the current tilesheet for the current image
	 */
	override public function getTilesheet():Tilesheet{
		return this.tilesheet;
	}
	
	
	
}