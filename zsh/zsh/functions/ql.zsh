# ql: Function to open any file in MacOS Quicklook Preview
function ql() { qlmanage -p "$*" >&/dev/null; }
