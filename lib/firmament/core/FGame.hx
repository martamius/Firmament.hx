package firmament.core;

/**
 * Class: FGame
 * Manages the game, including all worlds, cameras, simulation, rendering, etc.
 */



import firmament.core.FCamera;
import firmament.core.FEntity;
import firmament.core.FEntityPoolManager;
import firmament.core.FInput;
import firmament.filter.entity.FEntityFilter;
import firmament.filter.entity.FEntityFilterFactory;
import firmament.process.base.FProcess;
import firmament.process.base.FProcessManager;
import firmament.process.engine.FCameraRenderProcess;
import firmament.process.engine.FWorldStepProcess;
import firmament.process.timer.FTimerManager;
import firmament.util.FConfigHelper;
import firmament.util.loader.FSceneLoader;
import firmament.util.loader.serializer.FSerializerFactory;
import firmament.world.FWorld;
import firmament.world.FWorldFactory;
import haxe.Timer;
import nme.Assets;
import nme.display.Bitmap;
import nme.display.Sprite;
import nme.events.Event;
import nme.events.EventDispatcher;
import nme.events.TimerEvent;
import nme.Lib;
import nme.text.TextField;
import nme.utils.Timer;

/**
 * Class: FGame
 */
class FGame extends EventDispatcher
{
	var cameras:Hash<FCamera>;
	var worldHash:Hash<FWorld>; 
	public var enableSimulation:Bool;
	var _gameProcessManager:FProcessManager;
	var _renderProcessManager:FProcessManager;

	var _mainInput:FInput;

	var _poolManager:FEntityPoolManager;

	var _gameTimerManager:FTimerManager;

	//Constant: COLLISION_PRE_SOLVE_EVENT
	public static inline var COLLISION_PRE_SOLVE_EVENT = 'preSolveCollision';

	//Constant: COLLISION_POST_SOLVE_EVENT
	public static inline var COLLISION_POST_SOLVE_EVENT = 'postSolveCollision';
	
	//Constant: COLLISION_BEGIN_CONTACT_EVENT
	public static inline var COLLISION_BEGIN_CONTACT_EVENT = 'beginContactCollision';

	//Constant: COLLISION_END_CONTACT_EVENT
	public static inline var COLLISION_END_CONTACT_EVENT = 'endContactCollision';
	



	//CONSTANT: BEFORE_STEP
	public static inline var BEFORE_STEP = 'beforeStep';
	
	//CONSTANT: AFTER_STEP
	public static inline var AFTER_STEP = 'afterStep';

	//CONSTANT: BEFORE_RENDER
	public static inline var BEFORE_RENDER = 'beforeRender';
	
	//CONSTANT: AFTER_RENDER
	public static inline var AFTER_RENDER = 'afterRender';

	//CONCSTANT: DELETE_ENTITY
	public static inline var DELETE_ENTITY = 'deleteEntity';

	private static var _instances:Hash<FGame>;

	/**
	 * Constructor: new
	 */
	private function new() 
	{
		super();
		
		this.enableSimulation = true;
		worldHash = new Hash<FWorld>();
		cameras = new Hash<FCamera>();
		var stage = Lib.current.stage;
		this._gameProcessManager = new FProcessManager();
		_renderProcessManager = new FProcessManager();
		stage.addEventListener(Event.ENTER_FRAME, this_onEnterFrame);
		
		_mainInput = new FInput(stage);
		_poolManager = new FEntityPoolManager();
		_gameTimerManager = new FTimerManager();
		this._gameProcessManager.addProcess(_gameTimerManager);
		/*var timer = new Timer(33);
		timer.addEventListener(TimerEvent.TIMER, this_step);
		timer.start();
		*/
	}



	public function loadGameConfig(fileName:String){
		var serializer = FSerializerFactory.getSerializerForFile(fileName);
		if (serializer == null) {
			throw ("Appropriate serializer for fileName "+fileName+" could not befound.");
		}
		var string = Assets.getText(fileName);
		var config = serializer.unserialize(string);
	}



	/*
		returns an instance of FGame.
		As of 2.1, has optional parameter 'key'
		@param String - The name of the instance to get. Default name is 'main'
	*/
	public static function getInstance(?name:String='main'):FGame{
		if(_instances == null){
			_instances = new Hash();
		}
		var instance = _instances.get(name);
		if(instance == null){
			instance = new FGame();
			_instances.set(name,instance);
		}
		return instance;
	}
	
	/**
	 * Function: getWorld
	 *
	 * Returns: an FWorld object of the type provided
	 */
	public function getWorld(type:String):FWorld{
		if(worldHash.exists(type)){
			return worldHash.get(type);
		}
		var w = FWorldFactory.createWorld(type);
		worldHash.set(type, w);

		//set up process for it
		var p = new FWorldStepProcess(w,this);
		this._gameProcessManager.addProcess(p);

		return w;
	}

	public function getWorlds():Hash<FWorld>{
		return this.worldHash;
	}

	public function getAllEntities():Array<FEntity>{
		var a = new Array<FEntity>();
		for(world in getWorlds()){
			a=a.concat(world.getAllEntities());
		}
		return a;
	}

	public function getEntitiesAtPoint(p:FVector):Array<FEntity>{
		var a = new Array<FEntity>();
		for(world in worldHash){
			a=a.concat(world.getEntitiesAtPoint(p));
		}
		return a;
	}

	public function getEntitiesInBox(topLeftX:Float,topLeftY:Float,bottomRightX:Float,bottomRightY:Float):Array<FEntity> {
		var a = new Array<FEntity>();
		for(world in worldHash){
			a=a.concat(world.getEntitiesInBox(topLeftX,topLeftY,bottomRightX,bottomRightY));
		}
		return a;
	}
	/*
		Function: queryEntities

		Returns: Array<FEntity> objects

		Example query:
			{
				selector: 'box'
				topLeft: {x:-1,-1}
				bottomRight:{1,1}
				filters:{
					type:{
						typeId: "enemy"
					}
				}

			}

	*/
	public function queryEntities(query:Dynamic){
		var entities:Array<FEntity>;
		var config = new FConfigHelper(query);
		var selector:String = config.getNotNull("selector",String);
		if (selector == "box"){
			var topLeft = config.getVector("topLeft",null);
			var bottomRight = config.getVector("bottomRight",null);
			if(topLeft == null || bottomRight ==null){
				throw "parameters topLeft or bottomRight are null.";
			}
			entities = getEntitiesInBox(topLeft.x,topLeft.y,bottomRight.x,bottomRight.y);
		}else if(selector =="point"){
			var point = config.getVector("point",null);
			if(point == null){throw "parameter 'point' is missing or null";}
			entities = getEntitiesAtPoint(point);
		}else{
			//default to select all
			entities = getAllEntities();
		}

		//run filters
		if(Reflect.isObject(query.filters)){
			for(filterName in Reflect.fields(query.filters)){
				var filter:FEntityFilter = FEntityFilterFactory.createfilter(filterName);
				entities = filter.filterEntityArray(entities,Reflect.field(query.filters,filterName));
			}
		}


		return entities;
	}

	/**
	 * Function: getProcessManager
	 */
	public function getProcessManager():FProcessManager {
		return this._gameProcessManager;
	}

	/**
	 * Function: getRenderProcessManager
	 */
	public function getRenderProcessManager():FProcessManager {
		return this._renderProcessManager;
	}


	/**
	 * Function: addProcess
	 *
	 * Parameters: 
	 *  name - String identifier for object, for retrieval
	 *  p - Process object
	 */
	public function addProcess(?type:String,p:FProcess):Void {
		this._gameProcessManager.addProcess(p);
	}

	/**
	 * Function: addCamera
	 * 
	 * Adds a new <FCamera> object to the game. Cameras must be added to the game in order for them to work.
	 * 
	 * Parameters:
	 *	name - String the name to call the camera. Used for getting the right camera.
	 *	c - <FCamera> The camera to add
	 */
	public function addCamera(name:String,c:FCamera):Void {
		this.cameras.set(name,c);
		this._renderProcessManager.addProcess(new FCameraRenderProcess(c,this));
	}


	/**
	 *	Function: getCamera
	 *	Parameters:
	 *		name - String the name of the camera to retrieve
	 *	Returns: <FCamera>
	*/
	public function getCamera(name:String):FCamera{
		return this.cameras.get(name);
	}
	

	/*
		Function: getMainInput
		returns the main <FInput> object connected to the stage.

	*/
	public function getMainInput(){
		return _mainInput;
	}
	
	
	private function doStep():Void {
		if(!_gameProcessManager.isPaused()){ //don't fire step events if we are paused.
			this.dispatchEvent(new Event(FGame.BEFORE_STEP));
			this._gameProcessManager.step();
			this.dispatchEvent(new Event(FGame.AFTER_STEP));
		}
		this._renderProcessManager.step();
		//trace('Simulation: '+_gameProcessManager.getLastStepTime()+ ' Render: '+_renderProcessManager.getLastStepTime());
	}



	private function this_onEnterFrame (event:Event):Void {
		//trace('this is called.');
		
		//var start = haxe.Timer.stamp();
		this.doStep();
		//trace("step time: "+(haxe.Timer.stamp() - start));
		
	} 

	public function getPoolManager(){
		return _poolManager;
	}

	/*
		Function: clearWorlds
		Destroys all worlds and entities

	*/
	public function clearWorlds(){
		for (world in worldHash){
			world.destruct();
		}
		worldHash = new Hash();
	}

	/*
		Function: clearAll
		destroys or clears references to all entities, worlds, cameras, and processes.
	*/
	public function clearAll(){
		clearWorlds();
		_gameProcessManager = new FProcessManager();
		_renderProcessManager = new FProcessManager();
		cameras = new Hash();
		this._gameProcessManager.addProcess(_gameTimerManager);
	}

	/**
	 * Returns the FTimerManager object for game timers
	 *
	 */
	public function getGameTimerManager(){
		return _gameTimerManager;
	}

	/**
	 * Adds a game timer.
	 * @param seconds - number of seconds until timer times out
	 *
	 */
	public function addGameTimer(seconds:Float, cb:Void->Dynamic, ?scope:Dynamic=null){
		return _gameTimerManager.addTimer(seconds, cb, scope);
	}


}
