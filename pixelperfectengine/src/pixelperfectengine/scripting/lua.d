module pixelperfectengine.scripting.lua;

import bindbc.lua;

import core.vararg;

import std.string : toStringz, fromStringz;
import std.variant;
import std.typetuple;
import std.traits;
import std.exception : enforce;

import pixelperfectengine.system.exc;
public import pixelperfectengine.scripting.lualib : registerLibForScripting;
public import pixelperfectengine.scripting.globals;

import collections.linkedmap;

/** 
 * Initializes the Lua scripting engine.
 * Returns: true if successful.
 */
public bool initLua() {
	LuaSupport ver = loadLua();
	return ver == LuaSupport.lua54;
}
///A default allocator for Lua.
extern(C)
package void* luaAllocator(void* ud, void* ptr, size_t osize, size_t nsize) @system nothrow {
	import core.memory;
	if (nsize == 0) {
		GC.free(ptr);
		return null;
	} else {
		return GC.realloc(ptr, nsize);
	}
}
/** 
 * Calls a Lua function with the given name and arguments.
 * Params:
 *   state = The Lua state, where the function is located.
 *   ... = The arguments to be passed to the function.
 * Template params:
 *   T = The return type.
 *   funcName = The name of the function.
 * Returns: An expected return type, which can be set to a tagged algebraic type to avoid potential mismatches.
 * Throws: A LuaException if the return type isn't matched, the execution ran into an error, or the function isn't 
 * found.
 */
public T callLuaFunc(T, string funcName)(lua_State* state, ...) @system {
	lua_getglobal(state, funcName);
	if (!lua_isfunction(state, 0 /* LUA_TOP */))
		throw new LuaException(8,"Function not found");
	foreach (arg; _arguments) {
		if (arg == typeid(byte)) {
			lua_pushinteger(state, va_arg!byte(_argptr));
		} else if (arg == typeid(short)) {
			lua_pushinteger(state, va_arg!short(_argptr));
		} else if (arg == typeid(int)) {
			lua_pushinteger(state, va_arg!int(_argptr));
		} else if (arg == typeid(long)) {
			lua_pushinteger(state, va_arg!long(_argptr));
		} else if (arg == typeid(ushort)) {
			lua_pushinteger(state, va_arg!ushort(_argptr));
		} else if (arg == typeid(uint)) {
			lua_pushinteger(state, va_arg!uint(_argptr));
		} else if (arg == typeid(ubyte)) {
			lua_pushinteger(state, va_arg!ubyte(_argptr));
		} else if (arg == typeid(bool)) {
			lua_pushboolean(state, va_arg!bool(_argptr));
		} else if (arg == typeid(double)) {
			lua_pushnumber(state, va_arg!double(_argptr));
		} else if (arg == typeid(string)) {
			lua_pushstring(state, toStringz(va_arg!string(_argptr)));
		} else if (arg == typeid(LuaVar)) {
			va_arg!LuaVar(_argptr).pushToLuaState(state);
		} else assert(0, "Argument not supported!");
	}
	int errorCode = lua_pcall(state, cast(int)_arguments.length, is(T == void) ? 0 : 1, 0);
	static if (!is(T == void)) {
		LuaVar result = LuaVar(state, -1);
		lua_pop(state, 1);
		static if (is(T == LuaVar)) {
			return result;
		} else {
			return result.get!T;
		}
	}
}
/** 
 * Registers a D function to be called from Lua.
 * Code is modified from MrcSnm's example found in the HipremeEngine.
 * Params:
 *   state = The Lua state to handle the data from the Lua side of things.
 * Template params:
 *   Func = The function to be registered.
 */
extern(C) public int registerDFunction(alias Func)(lua_State* state) nothrow
		if(isSomeFunction!(Func)) {
	import std.traits:Parameters, ReturnType;
	
	Parameters!Func params;
	int stackCounter = 0;
	try {
		foreach_reverse(ref param; params) {
			stackCounter--;
			param = luaGetFromIndex!(typeof(param))(state, stackCounter);
		}
	} catch (Exception e) {
		luaL_error(state, "Argument type mismatch with D functions!");
	}
	
	try {
		static if(is(ReturnType!Func == void)) {
			Func(params);
			return 0;
		} else static if(is(ReturnType!Func == struct)) {
			auto retVal = Func(params);
			static foreach (key ; (ReturnType!Func).tupleof) {
				LuaVar(__traits(child, retVal, key)).pushToLuaState(state);
			}
			return cast(int)retVal.tupleof.length;
		} else {
			LuaVar(Func(params)).pushToLuaState(state);
			return 1;
		}
	} catch (Exception e) {
		//luaPushVar(L, null);
		lastLuaToDException = e;
		try {
			luaL_error(state, ("A D function threw: "~e.toString~"!\0").ptr);
		} catch(Exception e) { 
			luaL_error(state, "D threw when stringifying exception!");
		}
		return 1;
	}
}
/** 
 * Registers a D delegate to be called from Lua.
 * Code is modified from MrcSnm's example found in the HipremeEngine.
 * Params:
 *   state = The Lua state to handle the data from the Lua side of things.
 * Template params:
 *   Func = The function to be registered.
 * Note: When calling a D delegate from Lua, the first parameter is always a light user data
 * containing the class instance that the delegate should be executed on.
 */
extern (C) public int registerDDelegate(alias Func)(lua_State* state) nothrow
		if(isSomeFunction!(Func)) {
	import std.traits:Parameters, ReturnType;
	alias ClassType = __traits(parent, Func);
	Parameters!Func params;
	int stackCounter = 0;
	stackCounter--;
	ClassType c;
	try {
		c = luaGetFromIndex!ClassType(state, stackCounter);
		foreach_reverse(ref param; params) {
			stackCounter--;
			param = luaGetFromIndex!(typeof(param))(state, stackCounter);
		}
	} catch (Exception e) {
		luaL_error(state, "Argument type mismatch with D functions!");
	}
	
	try {
		static if(is(ReturnType!Func == void)) {
			__traits(child, c, Func)(params);//c.Func(params);
			return 0;
		} else static if(is(ReturnType!Func == struct)) {
			ReturnType!Func retVal = __traits(child, c, Func)(params);//auto retVal = c.Func(params);
			static foreach (key ; (ReturnType!Func).tupleof) {
				LuaVar(__traits(child, retVal, key)).pushToLuaState(state);
			}
			return cast(int)retVal.tupleof.length;
		} else {
			LuaVar(__traits(child, c, Func)(params)).pushToLuaState(state);//LuaVar(c.Func(params)).pushToLuaState(state);
			return 1;
		}
	} catch (Exception e) {
		//luaPushVar(L, null);
		lastLuaToDException = e;
		try {
			luaL_error(state, ("A D function threw: "~e.toString~"!\0").ptr);
		} catch(Exception e) { 
			luaL_error(state, "D threw when stringifying exception!");
		}
		return 1;
	}
}
///Contains the pointer to the exception thrown by a D function called from the Lua side.
public static Exception lastLuaToDException;
///Fetches a value from a lua_State variable.
package T luaGetFromIndex(T)(lua_State* L, int ind) {
	static if(isIntegral!T || isSomeChar!T) {
		if (!lua_isinteger(L, ind)) 
			throw new LuaException(7,"Type mismatch!");
		lua_Integer i = lua_tointeger(L, ind);
		return cast(T)i;
	} else static if(isFloatingPoint!T) {
		if (!lua_isnumber(L, ind))
			throw new LuaException(7,"Type mismatch!");
		lua_Number n = lua_tonumber(L, ind);
		return cast(T)n;
	} else static if(is(T == class) || is(T == interface)) {
		if (!lua_islightuserdata(L, ind))
			throw new LuaException(7,"Type mismatch!");
		void* data = lua_touserdata(L, ind);
		return cast(T)data;
	} else static if(is(T == string)) {
		import std.string : fromStringz;
		if (!lua_isstring(L, ind))
			throw new LuaException(7,"Type mismatch!");
		return cast(string)(fromStringz(lua_tostring(L, ind)));
	} else static if(is(T == void*)) {
		if (!lua_islightuserdata(L, ind))
			throw new LuaException(7,"Type mismatch!");
		void* data = lua_touserdata(L, ind);
		return data;
	} else static if(is(T == LuaVar)) {
		return LuaVar(L, ind);
	} else static assert(0, "Type not supported!");
	
}
/**
 * Contains type identifiers related to Lua.
 */
public enum LuaVarType {
	Null,
	Boolean,
	Number,
	Integer,
	String,
	Function,
	Userdata,
	Thread,
	Table
}
/** 
 * Implements a Lua variable with all the underlying stuff required for it.
 */
public struct LuaVar {
	///Contains the type of the given Lua variable.
	private LuaVarType		_type;
	private union {
		void*				dataPtr;
		long				dataInt;
		double				dataNum;
	}
	///Creates a Lua variable of type `void`.
	public static LuaVar voidType() @safe pure nothrow {
		LuaVar result;
		result._type = LuaVarType.Null;
		return result;
	}
	/**
	 * Initializes the value with the type of `val`
	 */
	public this(T)(T val) @safe pure nothrow {
		static if (is(T == void*) || is(T == LuaTable*)) {
			dataPtr = val;
		} else static if (isIntegral!T || isBoolean!T) {
			dataInt = val;
		} else static if (isFloatingPoint!T) {
			dataNum = val;
		} else static if (is(T == string)) {
			void __workaround() @system pure nothrow {
				dataPtr = cast(void*)toStringz(val);
			}
			void _workaround() @trusted pure nothrow {
				__workaround();
			}
			_workaround();
		} else static if (is(T == const(char)*)) {
			dataPtr = cast(void*)val;
		}
		setType!(T);
	}
	/**
	 * Fetches the given index (idx) from the lua_State (state), and initializes a LuaVar based on its type.
	 */
	public this(lua_State* state, int idx) nothrow {
		int type = lua_type(state, idx);
		switch (type) {
			case LUA_TLIGHTUSERDATA:
				dataPtr = lua_touserdata(state, idx);
				_type = LuaVarType.Userdata;
				break;
			case LUA_TBOOLEAN:
				dataInt = lua_toboolean(state, idx);
				_type = LuaVarType.Boolean;
				break;
			case LUA_TNUMBER:
				if (lua_isinteger(state, idx)) {
					dataInt = lua_tointeger(state, idx);
					_type = LuaVarType.Integer;
				} else {
					dataNum = lua_tonumber(state, idx);
					_type = LuaVarType.Number;
				}
				break;
			case LUA_TSTRING:
				dataPtr = cast(void*)lua_tostring(state, idx);
				_type = LuaVarType.String;
				break;
			default:
				break;
		}
	}
	///Sets the type of this variable internally.
	private void setType(T)() @nogc @safe pure nothrow {
		static if (isIntegral!T || isSomeChar!T) {
			_type = LuaVarType.Integer;
		} else static if (isBoolean!T) {
			_type = LuaVarType.Boolean;
		} else static if (isFloatingPoint!T) {
			_type = LuaVarType.Number;
		} else static if (is(T == string) || is(T == const(char)*)) {
			_type = LuaVarType.String;
		} else static if (is(T == void*) || is(T == class) || is(T == interface)) {
			_type = LuaVarType.Userdata;
		} else static if (is(T == LuaTable)) {
			_type = LuaVarType.Table;
		} else {
			_type = LuaVarType.Null;
		}
	}
	///Returns the type held by this stucture.
	public LuaVarType type() const @nogc @safe pure nothrow {
		return _type;
	}
	///Internal dereference.
	private T deRef(T)() const @nogc @system pure nothrow {
		static if (is(T == void*) || is(T == LuaTable*)) {
			return cast(T)dataPtr;
		} else static if (isIntegral!T || isBoolean!T) {
			return cast(T)dataInt;
		} else static if (isFloatingPoint!T) {
			return cast(T)dataNum;
		} else static if (is(T == string)) {
			return fromStringz(cast(const(char*))dataPtr);
		} else static if (is(T == const(char*))) {
			return cast(const(char*))dataPtr;
		} else static assert(0, "Unsupported type!");
	}
	/**
	 * Pushes the struct's value to the given lua_State.
	 */
	package void pushToLuaState(lua_State* state) @system nothrow {
		final switch (_type) with (LuaVarType) {
			case Null:
				lua_pushnil(state);
				break;
			case Boolean:
				lua_pushboolean(state, deRef!bool());
				break;
			case Number:
				lua_pushnumber(state, deRef!double());
				break;
			case Integer:
				lua_pushinteger(state, deRef!long());
				break;
			case String:
				lua_pushstring(state, cast(const(char*))dataPtr);
				break;
			case Function:
				break;
			case Userdata:
				lua_pushlightuserdata(state, dataPtr);
				break;
			case Thread:
				break;
			case Table:
				break;
		}
	}
	/**
	 * Returns the given type of `T`.
	 * Throws: LuaException in case of type mismatch.
	 */
	public T get(T)() const @trusted pure {
		static if (isIntegral!T) {
			if (_type == LuaVarType.Integer)
				return cast(T)deRef!long;
		} else static if (isFloatingPoint!T) {
			if (_type == LuaVarType.Integer)
				return cast(T)deRef!double;
		} else static if (is(T == string)) {
			if (_type == LuaVarType.String)
				return deRef!string;
		} else static if (is(T == const(char*))){
			if (_type == LuaVarType.String)
				return deRef!(const(char*));
		} else static if (is(T == void*)) {
			if (_type == LuaVarType.Userdata)
				return deRef!(void*);
		} else static if (is(T == bool)) {
			if (_type == LuaVarType.Boolean)
				return deRef!bool;
		} else static if (is(typeof(T) == LuaTable*)) {
			if (_type == LuaVarType.Table)
				return deRef!(LuaTable*);
		} else static assert(0, "Type not supported!");
		throw new LuaException(7, "Wrong type!");
	}
	/**
	 * used to implement an interface with tables in Lua.
	 */
	public bool opEquals(const LuaVar other) const @nogc @trusted pure nothrow {
		if (_type != other._type) return false;
		switch (_type) {
			case LuaVarType.Number:
				return deRef!double() == other.deRef!double();
			case LuaVarType.Integer:
				return deRef!long() == other.deRef!long();
			case LuaVarType.String:
				return deRef!string() == other.deRef!string();
			case LuaVarType.Boolean:
				return deRef!bool() == other.deRef!bool();
			case LuaVarType.Userdata:
				return deRef!(void*)() == other.deRef!(void*)();
			default:
				return false;
		}
	}
	/**
	 * Assigns the value to this struct and sets the type if needed.
	 */
	public auto opAssign(T)(T val) @safe pure nothrow {
		static if (is(T == void*) || is(T == LuaTable*)) {
			dataPtr = val;
		} else static if (isIntegral!T || isBoolean!T) {
			dataInt = val;
		} else static if (isFloatingPoint!T) {
			dataNum = val;
		} else static if (is(T == string)) {
			dataStr = val;
		}
		setType!T;
		return this;
	}
	/**
	 * Casts the type to `T` if possible.
	 * Throws: LuaException, if implicit type casting is impossible.
	 */
	T opCast(T)() const @safe pure {
		import std.math : nearbyint;
		static if (isIntegral!T) {
			if (_type == LuaVarType.Integer) {
				return cast(T)dataInt;
			} else if (_type == LuaVarType.Number) {
				return cast(T)nearbyint(dataNum);
			}
		} else static if (isFloatingPoint!T) {
			if (_type == LuaVarType.Integer) {
				return cast(T)dataInt;
			} else if (_type == LuaVarType.Number) {
				return cast(T)dataNum;
			}
		}
		return get!T();
	}
}

alias LuaTable = LinkedMap!(LuaVar, LuaVar);
/**
 * Implements an interface to the lua_State* variable with automatic garbage management and some basic functionality.
 */
public class LuaScript {
	protected lua_State*		state;
	protected string			source;
	protected bool				isLoaded;
	/**
	 * Initializes a Lua script from the provided source code.
	 * Params:
	 *   source = The source code of the script file.
	 *   name = The name of the file.
	 * Throws: LuaException, if either a syntax or memory error was encountered.
	 */
	this(string source, const(char*) name) {
		this.source = source;
		state = lua_newstate(&luaAllocator, null);
		const int errorCode = lua_load(state, &reader, cast(void*)this, name, null);
		switch (errorCode) {
			default:
				break;
			case LUA_ERRSYNTAX:
				throw new LuaException(LUA_ERRSYNTAX, "Syntax error in file!");
			case LUA_ERRMEM:
				throw new LuaException(LUA_ERRMEM, "Memory error!");
		}
		registerLibForScripting(state);
	}
	///Automatically deallocates the lua_State variable.
	~this() {
		lua_close(state);
	}
	///Returns the lua_State variable for any manual use.
	public lua_State* getState() @nogc nothrow pure {
		return state;
	}
	/**
	 * Executes the main function of the scipt.
	 * Returns: A LuaVar variable with the appropriate return value if there was any.
	 * Throws: A LuaException if the execution ran into an error, or the function isn't found.
	 */
	public LuaVar runMain() {
		return callLuaFunc!(LuaVar, "main")(state);
	}
	extern(C)
	private static const(char*) reader(lua_State* st, void* data, size_t* size) nothrow {
		LuaScript ls = cast(LuaScript)data;
		if (ls.isLoaded) {
			*size = 0;
			return null;
		} else {
			ls.isLoaded = true;
			*size = ls.source.length;
			return ls.source.ptr;
		}
	}
}
/**
 * Thrown on errors encountered during Lua script execution.
 */
public class LuaException : PPEException {
	public int errorCode;
	///
	@nogc @safe pure nothrow this(int errorCode, string msg, string file = __FILE__, size_t line = __LINE__, 
			Throwable nextInChain = null)
	{
		this.errorCode = errorCode;
		super(msg, file, line, nextInChain);
	}
	///
	@nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line, nextInChain);
	}
}