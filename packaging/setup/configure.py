import os
import re
import pkgutil
import inspect
import config_lib
from installer_io import InstallerIO
from log import logger
from text import text

class Configure:
    def __init__(self):
        pass

    def _version_detect(self):
        self.chorus_version = None
        current = os.path.join(self.options.chorus_path, "current")
        if os.path.lexists(current):
            self.chorus_version = os.path.basename(os.path.realpath(current))

        self.alpine_version = None
        alpine_current = os.path.join(self.options.chorus_path, "alpine-current")
        if os.path.lexists(alpine_current):
            self.alpine_version = os.path.basename(os.path.realpath(alpine_current))

    def _load_configure_func(self):
        dic = {}
        idx = 1
        for importer, modname, ispkg in pkgutil.iter_modules(config_lib.__path__):
            module = __import__("config_lib." + modname, fromlist="config_lib")
            for function in inspect.getmembers(module, inspect.isfunction):
                if not inspect.getmodule(function[1]) == module:
                    continue
                dic[idx] = function
                idx += 1
        return dic

    def get_chorus_state(self):
        if self.chorus_version is None:
            service_state = "Not installed"
        elif self._chorus_pid_exist("jetty.pid") and self._chorus_pid_exist("nginx.pid")\
                and self._chorus_pid_exist("scheduler.production.pid") and self._chorus_pid_exist("solr-production.pid")\
                and self._chorus_pid_exist("worker.production.pid"):
            service_state = "running"
        elif self._chorus_pid_exist("jetty.pid") or self._chorus_pid_exist("nginx.pid")\
                or self._chorus_pid_exist("scheduler.production.pid") or self._chorus_pid_exist("solr-production.pid")\
                or self._chorus_pid_exist("worker.production.pid"):
            service_state = "partially running"
        else:
            service_state = "stopped"
        return service_state

    def get_alpine_state(self):
        if self.alpine_version is None:
           service_state = "Not installed"
        elif self._alpine_pid_exist("alpine.pid"):
           service_state = "running"
        else:
           service_state = "stopped"
        return service_state

    def _chorus_pid_exist(self, pid_name):
        return os.path.exists(os.path.join(self.options.chorus_path, "shared/tmp/pids/" + pid_name))

    def _alpine_pid_exist(self, pid_name):
        return os.path.exists(os.path.join(self.options.chorus_path, "alpine-current/" + pid_name))

    def config(self, options, is_upgrade):
        self.options = options
        self.io = InstallerIO(options.silent)
        self._version_detect()
        print "*" * 60
        header = ""
        if self.chorus_version is None:
            print text.get("status_msg", "no_chorus")
        else:
            print text.get("status_msg", "chorus_status") % (self.chorus_version, self.get_chorus_state())
        if self.alpine_version is None:
            print text.get("status_msg", "no_alpine")
        else:
            print text.get("status_msg", "alpine_status") % (self.alpine_version, self.get_alpine_state())
        print "CHORUS_HOME:\t%s" % os.getenv("CHORUS_HOME", "not set in ~/.bashrc")
        print "*" * 60
        if self.chorus_version is None:
            return

        self.method = self._load_configure_func()
        while True:
            lens = len(self.method) + 1
            menu = "\n".join(str(e) + ". " + self.method[e][0] for e in self.method.keys()) + "\n%d. exit" % lens
            selection = self.io.require_menu(text.get("interview_question", "configuration_menu") % menu, range(1, lens + 1), default=lens)
            if selection == lens:
                break
            self.method[selection][1](options)
            if self.io.require_confirmation(text.get("interview_question", "back_to_menu"), default="no"):
                continue
            else:
                break
        print "*" * 60
        print text.get("status_msg", "configure_post_step")
        print "*" * 60

configure = Configure()
