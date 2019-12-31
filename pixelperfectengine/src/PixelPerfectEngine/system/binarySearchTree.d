module PixelPerfectEngine.system.binarySearchTree;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.transformFunctions module
 */

import core.memory;
import core.stdc.string;

/**
 * Implements a mostly @nogc-able container format, with relatively fast access times.
 * Mostly based upon the AVT tree algorithm with small modifications, with the intent to replace D's default associative arrays for GC-pureFree operations,
 * and better speed (theoretical worst-case access times: aArray's = n, this' = log2(n)).
 * Tree traversal through D's Range capabilities.
 * TODO:
 * <ul>
 * <li>Implement tree traversal.</li>
 * <li>Improve tree optimization speeds.</li>
 * <li>Fix potential memory leakage issues.</li>
 * </ul>
 */
public struct BinarySearchTree(K, E){
	/**
	 * Implements a single tree node.
	 */
	public struct Node{
		K key;				///Indentifier key, also used for automatic sorting
		E elem;				///Stores the element referred by this node
		Node* left;			///lesser elements
		Node* right;		///greater elements
		/**
		 * Creates a new instance of a BST node.
		 */
		this(K key, E elem, Node* left = null, Node* right = null) @nogc pure nothrow {
			this.key = key;
			this.elem = elem;
			this.left = left;
			this.right = right;
		}
		/**
		 * Used for by-depth tree traversal.
		 */
		@nogc int opApply(int delegate(Node) @nogc dg) {
			if(left)
				if(left.opApply(dg))
					return 1;
			if(dg(this))
				return 1;
			if(right)
				if(right.opApply(dg))
					return 1;
			return 0;
		}
		/**
		 * Compares two Nodes to each other.
		 */
		int opCmp(ref Node rhs) @nogc @safe pure nothrow {
			return key - rhs.key;
		}
		/**
		 * Returns the total height.
		 */
		size_t height() @nogc pure nothrow {
			if(left is null && right is null){
				return 1;
			}else{
				size_t l = 1, r = 1;
				if(left !is null){
					l += left.height;
				}
				if(right !is null){
					r += right.height;
				}
				if(l >= r){
					return l;
				}else{
					return r;
				}
			}
		}
		/**
		 * Returns the balance of the node. Minus if LHS is heavier, plus if RHS is heavier.
		 */
		@nogc @property sizediff_t bal(){
			if(left is null && right is null){
				return 0;
			}else{
				size_t l, r;
				if(left !is null){
					l = left.height;
				}
				if(right !is null){
					r = right.height;
				}
				return r - l;
			}
		}
		/**
		 * Deallocates the memory allocated for the tree.
		 */
		@nogc void dealloc(){
			if(left){
				left.dealloc;
				pureFree(left);
			}
			if(right){
				right.dealloc;
				pureFree(right);
			}
		}
		/**
		 * String representation for debugging.
		 */
		public string toString(){
			import std.conv;
			string result = "[" ~ to!string(key) ~ ":" ~ to!string(elem) ~ ";" ~ to!string(bal) ~ ";";
			if(left is null){
				result ~= "lhs: null ";
			}else{
				result ~= " lhs: " ~ left.toString;
			}
			if(right is null){
				result ~= "rhs: null ";
			}else{
				result ~= " rhs: " ~ right.toString;
			}
			return result ~ "]";
		}
	}
	private Node* root;		///Points to the root element
	private size_t nOfElements;			///Current number of elements
	/**
	 * Used for foreach iteration.
	 */
	public @nogc int opApply(int delegate(Node) @nogc dg){
		return root.opApply(dg);
	}
	/**
	 * Gets an element without allocation. Returns E.init if key not found.
	 */
	public E opIndex(K key) @nogc pure nothrow {
		bool found;
		Node* crnt = root;
		E result;
		do{
			if(crnt is null){
				found = true;
			}else if(crnt.key == key){
				found = true;
				result = crnt.elem;
			}else if(crnt.key > key){
				crnt = crnt.left;
			}else{
				crnt = crnt.right;
			}
		}while(!found);
		return result;
	}
	/**
	 * Gets the pointer of an element.
	 */
	public E* getPtr(K key) @nogc pure nothrow {
		bool found;
		Node* crnt = root;
		E* result;
		do{
			if(crnt is null){
				found = true;
			}else if(crnt.key == key){
				found = true;
				result = &crnt.elem;
			}else if(crnt.key > key){
				crnt = crnt.left;
			}else{
				crnt = crnt.right;
			}
		}while(!found);
		return result;
	}
	/**
	 * Inserts a new element with some automatic optimization.
	 * TODO: Make the optimization better.
	 */
	public E opIndexAssign(E value, K i)  @nogc pure nothrow {
		if(root is null){
			root = cast(Node*)pureMalloc(Node.sizeof);
			*root = Node(i,value);
			nOfElements++;
			return value;
		}
		if(insertAt(&root, i, value)){
			rebalanceTree(&root);
			nOfElements++;
		}
		return value;
	}
	/**
	 * Rebalances a tree.
	 */
	public void rebalanceTree() @nogc pure nothrow {
		rebalanceTree(&root);
	}
	protected void rebalanceTree(Node** node) @nogc pure nothrow {
		if((*node).height > 1){
			if((*node).bal > 1 || (*node).bal < -1){
				optimize(node);
			}
			if((*node).left !is null){
				rebalanceTree(&(*node).left);
			}
			if((*node).right !is null){
				rebalanceTree(&(*node).right);
			}
		}
	}
	/**
	 * Returns the number of elements in the tree.
	 */
	public @property size_t length() @nogc pure nothrow {
		return nOfElements;
	}
	/**
	 * Inserts an item at the given point. Returns true if the height of the tree have been raised.
	 */
	protected bool insertAt(Node** node, K key, E val) @nogc pure nothrow {
		if(key == (*node).key){
			(*node).elem = val;
			return false;
		}else if(key < (*node).key){
			if((*node).left is null){
				(*node).left = cast(Node*)pureMalloc(Node.sizeof);
				*(*node).left = Node(key,val);
				if((*node).right is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).left), key, val);
			}
		}else{
			if((*node).right is null){
				(*node).right = cast(Node*)pureMalloc(Node.sizeof);
				*(*node).right = Node(key,val);
				if((*node).left is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).right), key, val);
			}
		}
	}
	/**
	 * Removes an element by key.
	 */
	public void remove(K key) @nogc pure nothrow {
		bool handside;
		Node* crnt = root;
		Node* prev;
		while(crnt !is null){
			if(crnt.key == key){
				if(crnt.left is null && crnt.right is null){
					pureFree(crnt);
					if(prev !is null){
						if(handside)
							prev.right = null;
						else
							prev.left = null;
					}else{
						root = null;
					}
					crnt = null;
					nOfElements--;
				}else if(crnt.left is null){
					if(prev is null){
						root = crnt.right;
					}else{
						if(handside)
							prev.right = crnt.right;
						else
							prev.left = crnt.right;
					}
					pureFree(crnt);
					crnt = null;
					nOfElements--;
				}else if(crnt.right is null){
					if(prev is null){
						root = crnt.left;
					}else{
						if(handside)
							prev.right = crnt.left;
						else
							prev.left = crnt.left;
					}
					pureFree(crnt);
					crnt = null;
					nOfElements--;
				}else{
					Node* temp;
					if(handside){
						temp = findMin(prev.right);
					}else{
						temp = findMax(prev.right);
					}
					K tempKey = temp.key;
					E tempVal = temp.elem;
					Node* tempLHS = temp.left;
					Node* tempRHS = temp.right;
					remove(tempKey);
					crnt.key = tempKey;
					crnt.elem = tempVal;
					crnt.left = tempLHS;
					crnt.right = tempRHS;
					return;
				}
			}else if(crnt.key > key){
				prev = crnt;
				handside = false;
				crnt = crnt.left;
			}else{
				prev = crnt;
				handside = true;
				crnt = crnt.right;
			}
		}
	}
	/**
	 * Rotates the subtree to the left by one.
	 */
	protected void rotateLeft(Node** node) @nogc pure nothrow {
		Node* temp = *node;	//save current node
		*node = temp.right;				//assign the first RHS to the root
		temp.right = (*node).left;		//assign the new root's LHS to the saved node's RHS
		(*node).left = temp;			//assign the saved node to the new root's LHS
	}
	/**
	 * Rotates the subtree to the right by one.
	 */
	protected void rotateRight(Node** node) @nogc pure nothrow {
		Node* temp = *node;	//save current node
		*node = temp.left;				//assign the first LHS to the root
		temp.left = (*node).right;		//assign the new root's RHS to the saved node's LHS
		(*node).right = temp;			//assign the saved node to the new root's RHS
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected void rotateRightLeft(Node** node) @nogc pure nothrow {
		Node* temp = (*node).right.left;	//save root.RHS.LHS
		(*node).right.left = temp.right;			//assign temp.RHS to root.RHS.LHS
		temp.right = (*node).right;					//assign root.RHS to temp.RHS
		(*node).right = temp;						//assign temp to root.RHS
		//temp.right.bal = 0;							//reset balance of temp.RHS
		rotateLeft(node);							//rotate the root to the left
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected void rotateLeftRight(Node** node) @nogc pure nothrow {
		Node* temp = (*node).left.right;	//save root.LHS.RHS
		(*node).left.right = temp.left;				//assign temp.LHS to root.LHS.RHS
		temp.left = (*node).left;					//assign root.LHS to temp.LHS
		(*node).left = temp;						//assign temp to root.LHS
		//temp.left.bal = 0;							//reset balance of temp.LHS
		rotateRight(node);							//rotate the root to the right
	}
	/**
	 * Optimizes a BinarySearchTree by distributing nodes evenly.
	 */
	protected void optimize(Node** node) @nogc pure nothrow {
		if((*node).bal >= 2){
			if((*node).right.bal >= 1){
				rotateLeft(node);
			}else if((*node).right.bal <= -1){
				rotateRightLeft(node);
			}
		}else if((*node).bal <= -2){
			if((*node).left.bal >= 1){
				rotateLeftRight(node);
			}else if((*node).left.bal <= -1){
				rotateRight(node);
			}
		}

	}

	public Node*[] collectNodes(Node* source) pure nothrow {
		Node*[] result;
		if(source !is null){
			result ~= source;
			if(source.left !is null)
				result ~= collectNodes(source.left);
			if(source.right !is null)
				result ~= collectNodes(source.right);
		}
		return result;
	}
	/**
	 * Finds the smallest value from the root.
	 */
	public Node* findMin() @nogc pure nothrow {
		bool found;
		Node* result = root;
		do{
			if(result.left is null)
				found = true;
			else
				result = result.left;
		}while(!found);
		return result;
	}
	/**
	 * Finds the smallest value from the given root.
	 */
	public Node* findMin(Node* from) @nogc pure nothrow {
		bool found;
		Node* result = from;
		do{
			if(result.left is null)
				found = true;
			else
				result = result.left;
		}while(!found);
		return result;
	}
	/**
	 * Finds the largest value from the root.
	 */
	public Node* findMax() @nogc pure nothrow {
		bool found;
		Node* result = root;
		do{
			if(result.right is null)
				found = true;
			else
				result = result.right;
		}while(!found);
		return result;
	}
	/**
	 * Finds the largest value from the given root.
	 */
	public Node* findMax(Node* from) @nogc pure nothrow {
		bool found;
		Node* result = from;
		do{
			if(result.right is null)
				found = true;
			else
				result = result.right;
		}while(!found);
		return result;
	}

	public string toString(){
		import std.conv;
		string result = "Key: " ~ K.stringof ~ " : Elem: " ~ E.stringof;
		if(root !is null)
			result ~= root.toString();
		return result;
	}
}

/**
 * Implements a binary search tree without a key, meaning elements can be looked up in a different fashion, eg. through opEquals method overriding
 */
public struct BinarySearchTree2(Elem){
	/**
	 * Nodes for each branches.
	 */
	public struct Node{
		Elem elem;
		Node* left;
		Node* right;
		/**
		 * Creates a new BST node.
		 */
		this(Elem elem, Node* left = null, Node* right = null) @nogc pure nothrow {
			this.elem = elem;
			this.left = left;
			this.right = right;
		}
		/**
		 * Compares two BST nodes.
		 */
		int opCmp(T)(ref T rhs) @nogc pure nothrow {
			return this.elem.opCmp(rhs.elem);
		}
		/**
		 * Returns the total height.
		 */
		@property size_t height() @nogc pure nothrow {
			if(left is null && right is null){
				return 1;
			}else{
				size_t l = 1, r = 1;
				if(left !is null){
					l += left.height;
				}
				if(right !is null){
					r += right.height;
				}
				if(l >= r){
					return l;
				}else{
					return r;
				}
			}
		}
		/**
		 * Returns the balance of the node. Minus if LHS is heavier, plus if RHS is heavier.
		 */
		@property sizediff_t bal() @nogc pure nothrow {
			if(left is null && right is null){
				return 0;
			}else{
				size_t l, r;
				if(left !is null){
					l = left.height;
				}
				if(right !is null){
					r = right.height;
				}
				return r - l;
			}
		}
		/**
		 * String representation for debugging.
		 */
		public string toString(){
			import std.conv;
			string result = "[" ~ to!string(elem) ~ ";" ~ to!string(bal) ~ ";";
			if(left is null){
				result ~= "lhs: null ";
			}else{
				result ~= " lhs: " ~ left.toString;
			}
			if(right is null){
				result ~= "rhs: null ";
			}else{
				result ~= " rhs: " ~ right.toString;
			}
			return result ~ "]";
		}
	}
	private Node* root;

	private size_t nOfElements;			///Current number of elements


	/**
	 * Gets an element without allocation. Returns E.init if key not found.
	 */
	public Elem lookup(K)(K key) @nogc pure nothrow {
		bool found;
		Node* crnt = root;
		Elem result;
		do{
			if(crnt is null){
				found = true;
			}else if(crnt.elem == key){
				found = true;
				result = crnt.elem;
			}else if(crnt.elem > key){
				crnt = crnt.left;
			}else{
				crnt = crnt.right;
			}
		}while(!found);
		return result;
	}
	/**
	 * Inserts a new element with some automatic optimization.
	 * TODO: Make the optimization better.
	 */
	public Elem add(Elem elem) @nogc pure nothrow {
		if(root is null){
			root = cast(Node*)pureMalloc(Node.sizeof);
			*root = Node(elem);
			nOfElements++;
			return elem;
		}
		if(insertAt(&root, elem)){
			rebalanceTree(&root);
			nOfElements++;
		}
		return elem;
	}
	/**
	 * Rebalances a tree.
	 */
	public void rebalanceTree() @nogc pure nothrow {
		rebalanceTree(&root);
	}
	protected void rebalanceTree(Node** node) @nogc pure nothrow {
		if((*node).height > 1){
			if((*node).bal > 1 || (*node).bal < -1){
				optimize(node);
			}
			if((*node).left !is null){
				rebalanceTree(&(*node).left);
			}
			if((*node).right !is null){
				rebalanceTree(&(*node).right);
			}
		}
	}
	/**
	 * Returns the number of elements in the tree.
	 */
	public @property size_t length() @nogc pure nothrow {
		return nOfElements;
	}
	/**
	 * Inserts an item at the given point. Returns true if the height of the tree have been raised.
	 */
	protected bool insertAt(Node** node, Elem elem) @nogc pure nothrow {
		if(elem == (*node).elem){
			(*node).elem = elem;
			return false;
		}else if(elem < (*node).elem){
			if((*node).left is null){
				(*node).left = cast(Node*)pureMalloc(Node.sizeof);
				*(*node).left = Node(elem);
				if((*node).right is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).left), elem);
			}
		}else{
			if((*node).right is null){
				(*node).right = cast(Node*)pureMalloc(Node.sizeof);
				*(*node).right = Node(elem);
				if((*node).left is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).right), elem);
			}
		}
	}
	/**
	 * Removes an element by key.
	 */
	public void remove(Elem elem) @nogc pure nothrow {
		bool handside;
		Node* crnt = root;
		Node* prev;
		while(crnt !is null){
			if(crnt.elem == elem){
				if(crnt.left is null && crnt.right is null){
					pureFree(crnt);
					if(prev !is null){
						if(handside)
							prev.right = null;
						else
							prev.left = null;
					}else{
						root = null;
					}
					crnt = null;
					nOfElements--;
				}else if(crnt.left is null){
					if(prev is null){
						root = crnt.right;
					}else{
						if(handside)
							prev.right = crnt.right;
						else
							prev.left = crnt.right;
					}
					pureFree(crnt);
					crnt = null;
					nOfElements--;
				}else if(crnt.right is null){
					if(prev is null){
						root = crnt.left;
					}else{
						if(handside)
							prev.right = crnt.left;
						else
							prev.left = crnt.left;
					}
					pureFree(crnt);
					crnt = null;
					nOfElements--;
				}else{
					Node* temp;
					if(handside){
						temp = findMin(prev.right);
					}else{
						temp = findMax(prev.right);
					}
					//K tempKey = temp.key;
					Elem tempVal = temp.elem;
					Node* tempLHS = temp.left;
					Node* tempRHS = temp.right;
					remove(tempVal);
					//crnt.key = tempKey;
					crnt.elem = tempVal;
					crnt.left = tempLHS;
					crnt.right = tempRHS;
					return;
				}
			}else if(crnt.elem > elem){
				prev = crnt;
				handside = false;
				crnt = crnt.left;
			}else{
				prev = crnt;
				handside = true;
				crnt = crnt.right;
			}
		}
	}
	/**
	 * Rotates the subtree to the left by one.
	 */
	protected void rotateLeft(Node** node) @nogc pure nothrow {
		Node* temp = *node;	//save current node
		*node = temp.right;				//assign the first RHS to the root
		temp.right = (*node).left;		//assign the new root's LHS to the saved node's RHS
		(*node).left = temp;			//assign the saved node to the new root's LHS
	}
	/**
	 * Rotates the subtree to the right by one.
	 */
	protected void rotateRight(Node** node) @nogc pure nothrow {
		Node* temp = *node;	//save current node
		*node = temp.left;				//assign the first LHS to the root
		temp.left = (*node).right;		//assign the new root's RHS to the saved node's LHS
		(*node).right = temp;			//assign the saved node to the new root's RHS
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected void rotateRightLeft(Node** node) @nogc pure nothrow {
		Node* temp = (*node).right.left;	//save root.RHS.LHS
		(*node).right.left = temp.right;			//assign temp.RHS to root.RHS.LHS
		temp.right = (*node).right;					//assign root.RHS to temp.RHS
		(*node).right = temp;						//assign temp to root.RHS
		//temp.right.bal = 0;							//reset balance of temp.RHS
		rotateLeft(node);							//rotate the root to the left
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected void rotateLeftRight(Node** node) @nogc pure nothrow {
		Node* temp = (*node).left.right;	//save root.LHS.RHS
		(*node).left.right = temp.left;				//assign temp.LHS to root.LHS.RHS
		temp.left = (*node).left;					//assign root.LHS to temp.LHS
		(*node).left = temp;						//assign temp to root.LHS
		//temp.left.bal = 0;							//reset balance of temp.LHS
		rotateRight(node);							//rotate the root to the right
	}
	/**
	 * Optimizes a BinarySearchTree by distributing nodes evenly.
	 */
	protected void optimize(Node** node) @nogc pure nothrow {
		if((*node).bal >= 2){
			if((*node).right.bal >= 1){
				rotateLeft(node);
			}else if((*node).right.bal <= -1){
				rotateRightLeft(node);
			}
		}else if((*node).bal <= -2){
			if((*node).left.bal >= 1){
				rotateLeftRight(node);
			}else if((*node).left.bal <= -1){
				rotateRight(node);
			}
		}

	}
	/**
	 * Finds the smallest value from the root.
	 */
	public Node* findMin() @nogc pure nothrow {
		bool found;
		Node* result = root;
		do{
			if(result.left is null)
				found = true;
			else
				result = result.left;
		}while(!found);
		return result;
	}
	/**
	 * Finds the smallest value from the given root.
	 */
	public Node* findMin(Node* from) @nogc pure nothrow {
		bool found;
		Node* result = from;
		do{
			if(result.left is null)
				found = true;
			else
				result = result.left;
		}while(!found);
		return result;
	}
	/**
	 * Finds the largest value from the root.
	 */
	public Node* findMax() @nogc pure nothrow {
		bool found;
		Node* result = root;
		do{
			if(result.right is null)
				found = true;
			else
				result = result.right;
		}while(!found);
		return result;
	}
	/**
	 * Finds the largest value from the given root.
	 */
	public Node* findMax(Node* from) @nogc pure nothrow {
		bool found;
		Node* result = from;
		do{
			if(result.right is null)
				found = true;
			else
				result = result.right;
		}while(!found);
		return result;
	}

	public string toString(){
		import std.conv;
		string result = " : Elem: " ~ Elem.stringof;
		if(root !is null)
			result ~= root.toString();
		return result;
	}
}

unittest{
	import std.stdio;
	import std.random;

	BinarySearchTree!(int,int) test0, test1;
	//test 0: fill tree with consequential values
	for(int i ; i < 32 ; i++){
		test0[i] = i;
	}
	writeln(test0);
	//test 1: fill tree with random values
	for(int i ; i < 32 ; i++){
		test0[rand()] = i;
	}
	writeln(test1);
}
