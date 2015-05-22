PURPLE = '\033[95m'
CYAN = '\033[96m'
DARKCYAN = '\033[36m'
BLUE = '\033[94m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
BOLD = '\033[1m'
UNDERLINE = '\033[4m'
END = '\033[0m'

def bold(msg):
    return BOLD + BLUE + msg + END

def warning(msg):
    return YELLOW + msg + END
def fail():
    return "[" + RED + "Fail" + END + "]"

def done():
    return "[" + GREEN + "Done" + END + "]"

def error(msg):
    return RED + msg + END
