
import luxe.GameConfig;
import luxe.Input;
import phoenix.geometry.Geometry;
import luxe.Vector;
import luxe.Color;
import luxe.Sprite;
import luxe.Rectangle;


import luxe.options.ColorOptions;

import phoenix.Batcher;
import phoenix.Shader;
import phoenix.Texture;
import phoenix.RenderTexture;

// import luxe.utils.GeometryUtils;



typedef Cell = {
    var bl:Int;
    var tr:Int;
}
typedef Geos = {
    var bl:Geometry;
    var tr:Geometry;
}

class Main extends luxe.Game {

    public static inline var COLOR_GB_3_OFF:Int = 0x9BBC0F;
    public static inline var COLOR_GB_3_LIGHT:Int = 0x8BAC0F;
    public static inline var COLOR_GB_3_MEDIUM:Int = 0x306230;
    public static inline var COLOR_GB_3_DARK:Int = 0x0F380F;

    public var colours:Array<Int>;

    public var model:Array<Array<Cell>>;
    public var modelTo:Array<Array<Cell>>;
    public var geometries:Array<Array<Geos>>;

    public var gridSize:Int;
    public var gridHeight:Int;
    public var gridWidth:Int;
    public var pattern:Array<Array<Array<Int>>>;
    public var patternWidth:Int;
    public var patternHeight:Int;

    public var pattern_model:Dynamic;

    public var currentTime:Float;
    public var animationTime:Float;
    public var shaderTime:Float;
    public var clear:Color;


    public var post_shader:Shader;
    public var background_shader:Shader;
    public var post_batcher:Batcher;
    public var post_texture:RenderTexture;
    public var display_sprite:Sprite;
    public var background_sprite:Sprite;

    public var background_texture:Texture;


    override function config(config:GameConfig) {

        config.window.title = 'luxe game';
        // config.window.width = 960;
        // config.window.height = 630;
        config.window.fullscreen = true;

        config.preload.textures.push({ id:'assets/01.jpg' });
        config.preload.textures.push({ id:'assets/07.jpg' });
        config.preload.jsons.push({ id:'assets/patterns.json' });
        config.preload.shaders.push({ id:'post_shader', frag_id:'assets/post.glsl', vert_id:'default' });


        config.preload.shaders.push({ id:'background_shader', frag_id:'assets/background.glsl', vert_id:'default' });

        return config;

    } //config

    override function ready() {

        clear = new Color().rgb(0x000000);
        clear.a = 0;

        //initilise our shaders and batchers
        post_shader = Luxe.resources.shader('post_shader');
        post_shader.set_float("time",0);
        post_shader.set_vector2("resolution",new Vector(Luxe.screen.w,Luxe.screen.h));

        background_shader = Luxe.resources.shader('background_shader');
        background_shader.set_float("time",0);
        background_shader.set_vector2("resolution",new Vector(Luxe.screen.w,Luxe.screen.h));

        var background_texture = Luxe.resources.texture('assets/07.jpg');


        //this is the texture we will use for the post processing
        var texture_overlay = Luxe.resources.texture('assets/01.jpg');
        texture_overlay.slot = 1;
        post_shader.set_texture("tex1", texture_overlay);
        shaderTime = 0;


        background_shader.set_float("time",120.2);
        post_shader.set_float("time",0);
        // post_shader.set_vector2("pixel_size",pixel_size);


        //create a post_batcher
        post_batcher = Luxe.renderer.create_batcher({
             name : 'post_batcher',
             layer : 1,
             no_add : false,
         });

        //set the post batchers view to our current window viewport
        post_batcher.view.viewport = new Rectangle(0,0,Luxe.screen.width,Luxe.screen.height);

        //hook in our "before" and "after" to allow the render texture to capture the programs output
        post_batcher.on(prerender, before);
        post_batcher.on(postrender, after);


         //create a render target of a fixed size
         post_texture = new RenderTexture({ id:'rtt', width:Luxe.screen.w, height:Luxe.screen.h });


         //this is our background
         background_sprite = new Sprite({
             size : new Vector(Luxe.screen.width,Luxe.screen.height),
             pos : Luxe.screen.mid,
             color: new Color().rgb(0x400F80),
             shader: background_shader,
             texture: background_texture
         });


         //this is our final display sprite, after output has been capture (what we apply our post shader to)
         display_sprite = new Sprite({
             texture : post_texture,
             size : new Vector(Luxe.screen.width,Luxe.screen.height),
             pos : Luxe.screen.mid,
             shader: post_shader,
             // visible:false
         });


        //get our pattern models from our JSON assets
        var pattern_data = Luxe.resources.json('assets/patterns.json');
        pattern_model = pattern_data.asset.json;


        //initilise our objects
        gridSize = 40;
        currentTime = 0;
        animationTime = 5; //Seconds?

        //grid width and height based on our sceen size and grid size.
        gridHeight = Math.ceil(Luxe.screen.height/gridSize);
        gridWidth = Math.ceil(Luxe.screen.width/gridSize) + gridHeight;

        //initilise out main models.
        model = new Array<Array<Cell>>();
        modelTo = new Array<Array<Cell>>();
        geometries = new Array<Array<Geos>>();


        for(i in 0...gridHeight){
            model[i] = new Array<Cell>();
            modelTo[i] = new Array<Cell>();
            geometries[i] = new Array<Geos>();
        }


        //initilise our pallete
        colours = new Array<Int>();

        // colours.push(COLOR_GB_3_OFF);
        // colours.push(COLOR_GB_3_DARK);
        // colours.push(COLOR_GB_3_MEDIUM);
        // colours.push(COLOR_GB_3_LIGHT);

        //our blue / pink / purple pallette
        colours.push(0xffffff);
        colours.push(0x6457A6);
        colours.push(0x1AA4DD);
        colours.push(0x9DACFF);
        colours.push(0xE6BCEF);

        //lets generate our grid (both models from and to)
        itterateModel(model);
        // itterateModel(modelTo);

        //position the gid on the center of the screen (as our isometric grid is a rhombas)
        var cameraOffset:Int = -gridHeight*gridSize;

        //set up our geometries.
        for(i in 0...gridHeight){
            for(j in 0...gridWidth){

            //draw our bottom left tri for this cell
            var bl:Geometry = Luxe.draw.poly({
                                solid : true,
        
                                color: new Color().rgb(colours[model[i][j].bl]).toColorHSL(),
                                points : [
                                    new Vector(j*gridSize + (i*0.5*gridSize) + cameraOffset,(i+1)*gridSize),
                                    new Vector((j+0.5)*gridSize + (i*0.5*gridSize) + cameraOffset,(i)*gridSize),
                                    new Vector((j+1)*gridSize + (i*0.5*gridSize) + cameraOffset,(i+1)*gridSize),
                                ],
                                visible: (model[i][j].bl == 0)? false : true,
                                batcher:post_batcher

                            });
                
            

            //draw our top right tri for this cell
            var tr:Geometry = Luxe.draw.poly({
                                solid : true,
                                color: new Color().rgb(colours[model[i][j].tr]).toColorHSL(),
                                points : [
                                    new Vector((j+0.5)*gridSize + (i*0.5*gridSize) + cameraOffset,(i)*gridSize),
                                    new Vector((j+1.5)*gridSize + (i*0.5*gridSize) + cameraOffset,(i)*gridSize),
                                    new Vector((j+1)*gridSize + (i*0.5*gridSize) + cameraOffset,(i+1)*gridSize),
                                ],
                                visible: (model[i][j].tr == 0)? false : true,
                                batcher:post_batcher
                            });

            //save a reference to the tris to our geo models.
            geometries[i][j] = {bl:bl, tr:tr};
                
            
            }

        }


    } //ready


    //generate a random colour (with full alpha level)
    function randomColour() {
        var r:Float = Math.random();
        var g:Float = Math.random();
        var b:Float = Math.random();
        return new Color(r,g,b,1).toColorHSL();
    }

    //detect if a tri is on a column (or multiple of that column)
    function isOnColMod(y,x,isBL, colNumber):Bool{
        if((x % colNumber == 1 && isBL) || (x % colNumber == 0 && !isBL)){
            return true;
        } else {
            return false;
        }

    }

    //detect is a cell is on a row (or multiple of that row)
    function isOnRowMod(y,x,isBL,rowNumber):Bool{
        if((y % rowNumber == 0)){
            return true;
        } else {
            return false;
        }
    }

    //generates a random number between -x/2 -> x/2
    function varienceRandom(totalRange):Int{
        return Math.round((Math.random()-0.5)*totalRange);
    }

    //generate a colour for a tri 
    function generateColourFor(y,x,isBottomLeft){


        // our base power of 1 means the sampling of colours is uniform randomly
        var pow:Float = 1; //standard range

        // pow *= 2; //tend it more towards to darkside
        // pow /= 2; // tend it more towards jedi

        //select a patter
        pattern = pattern_model.cubeOne;
        patternHeight = pattern.length;
        patternWidth = pattern[0].length;

        var cellPatternVal;

        //get the pattern of the tri from our model (with repeating pattern)
         cellPatternVal = (isBottomLeft)? pattern[y%patternHeight][x%patternWidth][0] : pattern[y%patternHeight][x%patternWidth][1] ; 

        //get the pattern of the tri from our model (but center it) this is pretty hacky should re-write.
        /*var minY = Math.ceil(gridHeight/2 - patternHeight/2);
        var maxY = Math.ceil(gridHeight/2 + patternHeight/2);

        var minX = Math.ceil(gridWidth/2 + gridHeight/4 - patternWidth/2 - patternHeight/4);
        var maxX = Math.ceil(gridWidth/2 + gridHeight/4 + patternWidth/2 - patternHeight/4);

        if(y < maxY && y >= minY && x >= minX && x < maxX){
            //we are in our center pattern quadrant.
            cellPatternVal = (isBottomLeft)? pattern[y-minY][x-minX][0] : pattern[y-minY][x-minX][1] ; 
       

        } else {
            cellPatternVal = 0;

        }*/

        return cellPatternVal;




        //generate a colour from that pattern model
        var c:Color =  new Color().rgb(colours[cellPatternVal]); 

        //if the tri value from our model is 0 we want to generate a random colour.
        /*if(cellPatternVal == 0){
            // // pow += (y/(gridHeight/2));
            // if(y == 0){
            //     power /= 16;
            // } else if(y <= gridHeight/2){
            //     pow /= (y/gridHeight)*16; // top half of screen
            // } else {
            //     pow *=  ((y/gridHeight)-0.5)*16; // bottom half of screen.
            // }
            var rnd = Math.floor(Math.pow(Math.random(),pow)*colours.length);
            c = new Color().rgb(colours[rnd]);  // new random colour with power wheighting.
        }*/

       
        if(cellPatternVal == 0){
                // return null;
            } else {
                // return c.toColorHSL();

            }
        // return randomColourChange(c, 32).toColorHSL(); //apply some randoness to the colour.
        // return randomColour();
    }

    //varies a colour += on each channel.
    function randomColourChange(colour:Color, variance:Int){
        // trace(colour.r);
        colour.r += varienceRandom(variance)/256;
        colour.g += varienceRandom(variance)/256;
        colour.b += varienceRandom(variance)/256;

        return colour;
    }

    //our before render
    function before(_) {

            //Set the rendering target to the texture
                Luxe.renderer.target = post_texture;
                //clear the texture to an obvious color
                Luxe.renderer.clear(clear);

    } //before

    //our after render.
    function after(_) {

            //reset the target back to no target (i.e the screen)
            Luxe.renderer.target = null;

    } //after


    // our ween function that tweens tri's colour values.
    function startTweens() {
        for(i in 0...gridHeight){
            for(j in 0...gridWidth){
                var opt:ColorOptions = {h:new Color().rgb(colours[modelTo[i][j].bl]).toColorHSL().h, s:new Color().rgb(colours[modelTo[i][j].bl]).toColorHSL().s, l:new Color().rgb(colours[modelTo[i][j].bl]).toColorHSL().l};
                geometries[i][j].bl.color.tween(animationTime,opt);


                var optTwo:ColorOptions = {h:new Color().rgb(colours[modelTo[i][j].tr]).toColorHSL().h, s:new Color().rgb(colours[modelTo[i][j].tr]).toColorHSL().s, l:new Color().rgb(colours[modelTo[i][j].tr]).toColorHSL().l};
                geometries[i][j].tr.color.tween(animationTime,optTwo);
            }
        }


    }



    //itterates over and populates a model.
    function itterateModel(modelToUse:Array<Array<Cell>>) {
        //lets prepopulate the array
        for(i in 0...gridHeight){
        //    model[i] = new Array<Cell>();
            for(j in 0...gridWidth){
                modelToUse[i][j] = {bl:generateColourFor(i,j,true), tr:generateColourFor(i,j,false)};
            }
        }

    }

    //key listener.key
    override function onkeyup(event:KeyEvent) {

        if(event.keycode == Key.escape) {
            Luxe.shutdown();
        }

    } //onkeyup

    override function onmouseup(e:MouseEvent) {
       var gridY = Math.floor(e.y / gridSize);
       var gridX = Math.floor(e.x / gridSize)+ (gridHeight- Math.ceil(gridY/2));

       clickQuad(gridX,gridY,e.x,e.y);
    }

    function clickQuad(x,y,originalX,originalY){
        //detect if bl or tr


        if(Luxe.utils.geometry.point_in_geometry(new Vector(originalX,originalY), geometries[y][x].bl)){
            //trace("IS OVER A BL");
            //cycle colour

            model[y][x].bl = (model[y][x].bl+1)%colours.length;

            //update geo visible
            geometries[y][x].bl.visible = (model[y][x].bl == 0)? false : true;

            //update the color
            geometries[y][x].bl.color = new Color().rgb(colours[model[y][x].bl]).toColorHSL();// colours[model[y][x].bl];


        } else {
            //trace("IS OVER A TR");
            model[y][x].tr = (model[y][x].tr+1)%colours.length;

            //visible?
            geometries[y][x].tr.visible = (model[y][x].tr == 0)? false : true;
            geometries[y][x].tr.color = new Color().rgb(colours[model[y][x].tr]).toColorHSL();// colours[model[y][x].bl];

        }

    }

    //update function
    override function update(delta:Float) {


        shaderTime += delta; //increase current tome
        post_shader.set_float("time",shaderTime);
        // background_shader.set_float("time",shaderTime);

        currentTime += delta; //increase current tome

        //do we need to triger a re-generating of a model?
        // if(currentTime > animationTime){
        //     trace("itteration");
        //     model = modelTo;
        //     itterateModel(modelTo);
        //     currentTime = 0;
        //     startTweens();
        // } else {

        // }

    } //update

} //Main
