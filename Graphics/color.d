module graphics.color;

/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, color module
 */


/*
 *Represents a color on the palette.
 */
public class Color{
    private ubyte red, green, blue;

    this(ubyte r, ubyte g, ubyte b){
        red=r;
        green=g;
        blue=b;
    }
    public void setColor(ubyte r, ubyte g, ubyte b){
        red=r;
        green=g;
        blue=b;
    }
    public ubyte getR(){
        return red;
    }
    public ubyte getG(){
        return green;
    }
    public ubyte getB(){
        return blue;
    }
}
