import os
import sys
import signal
from options import get_options
from helper import failover, is_upgrade
from chorus_setup import chorus_set
from health_check import health_check, system_checking
from configure import configure
from log import logger, log_path
from color import bold, error
from text import text
import traceback
sys.path.append(os.path.abspath(os.path.dirname(__file__)))
options, arg, health_args = get_options(sys.argv)
is_upgrade = is_upgrade(options.chorus_path, options.data_path) and not options.force
handler = {"setup":chorus_set.setup, "health_check":health_check, "configure":configure.config}
def exit_gracefully(signum, frame):
    #print "\nSetup aborted, Cancelled by user"
    print
    failover(options.chorus_path, options.data_path, is_upgrade)
    sys.exit(1)

def main():
    try:
        signal.signal(signal.SIGINT, exit_gracefully)

        if (arg == "setup" and not options.disable_spec) \
           or (arg == "health_check" and (health_args == [] or "checkos" in health_args)):
            system_checking()

        if arg == "health_check":
            handler[arg](" ".join(health_args))
        else:
            handler[arg](options, is_upgrade)
    except Exception as e:
        logger.error(error(str(e) + "\n" + text.get("error_msg", "exception") % log_path))
        logger.debug(traceback.format_exc())
        failover(options.chorus_path, options.data_path, is_upgrade)
        exit(1)
