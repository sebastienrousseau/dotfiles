# logout: Function to logout from OS X via the Terminal
function logout() {
	osascript -e 'tell application "System Events" to log out'
	builtin logout
}
