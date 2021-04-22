# tree: Function to generates a tree view from the current directory
if [ ! -e /usr/local/bin/tree ]; then
	function tree(){
		pwd
		ls -R | grep ":$" |   \
		sed -e 's/:$//' -e 's/[^-][^\/]*\//--/g' -e 's/^/   /' -e 's/-/|/'
	}
fi
