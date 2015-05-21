import os
import platform
import re
import pkgutil
import inspect
import health_lib
from log import logger
from color import bold, warning
from chorus_executor import ChorusExecutor
from text import text

def _load_configure_func():
    dic = {}
    idx = 1
    #for importer, modname, ispkg in pkgutil.iter_modules(health_lib.__path__):
    #module = __import__("health_lib." + modname, fromlist="health_lib")
    from health_lib import hard_requirement
    for function in inspect.getmembers(hard_requirement, inspect.isfunction):
        if not inspect.getmodule(function[1]) == hard_requirement:
            continue
        dic[idx] = function
        idx += 1
    return dic

def system_checking(install_mode=False, chorus_path=None):
    logger.info(bold(text.get("step_msg", "health_check")))
    for func in _load_configure_func().values():
        if func[0] == "b_check_running_user":
            func[1](install_mode=install_mode)
        elif func[0] == "d_check_disk_space":
            if install_mode:
                func[1](chorus_path)
        else:
            func[1]()

def health_check(args=''):

    executor = ChorusExecutor()
    if args == '' or args == None:
        args = "checkos"
    if "help" not in args:
        logger.info(bold("Running \"atk %s\" Command:" % args))
    command = "source ~/.bashrc && %s %s" % (os.path.join(os.path.dirname(os.path.abspath(__file__)), "health_lib/atk"), args)
    ret, stdout, stderr = executor.run(command + " 2>&1")
    if "Warning" in stdout:
        logger.warning(stdout)
        logger.warning(warning("You have warning during health_check which might cause\n"\
                       + "problem when you use alpine chorus, we recommand you\n"\
                       + "resolve these problem before using alpine chorus."))
    return ret, stdout, stderr

if __name__ == "__main__":
    hard_require()
