import sys
import re

class InstallerIO:
    """
        chorus installer io class
    """
    def __init__(self, silent=False):
        self.silent = silent

    def prompt(self, msg, default=None):
        while True:
            sys.stdout.write(msg + " [default=\'%s\']:" % str(default))
            if not self.silent:
                inputs = raw_input()
            else:
                print
                return default
            if default is None and inputs == '':
                continue
            elif inputs == '':
                return default
            else:
                return inputs

    def prompt_int(self, msg, default=None):
        while True:
            sys.stdout.write(msg + " [default=\'%s\']:" % str(default))
            if not self.silent:
                inputs = raw_input()
            else:
                return default
            if inputs == "" or inputs is None:
                return default

            if not inputs.isdigit():
                print "please input a number"
                continue
            else:
                return int(inputs)

    def require_confirmation(self, msg, default="yes"):
        valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
        if default is None:
            prompt = " [y/n]"
        elif default == "yes":
            prompt = " [Y/n]"
        elif default == "no":
            prompt = " [y/N]"
        else:
            raise ValueError("invalid default answer: '%s'" % default)
        while True:
            sys.stdout.write(msg + " " + prompt + ":")
            if not self.silent:
                choice = raw_input()
            else:
                print default
                return valid[default]
            if default is not None and choice == '':
                return valid[default]
            elif choice.lower() in valid:
                return valid[choice.lower()]
            else:
                print "Please respond with 'yes' or 'no' (or 'y' or 'n')"
    def require_selection(self, msg, legal_choices, default=None):
        while True:
            sys.stdout.write(msg + " [default=\'%s\']:" % str(default))
            if not self.silent:
                choice = raw_input()
            else:
                return default
            if choice == "" or choice is None:
                return default
            choices = choice.strip().split(",")
            if self._is_legal(choices, legal_choices):
                return sorted(map(int, choices))
            else:
                print "Please input number in %s if multiple, use ',' to seperate" % str(legal_choices)

    def require_menu(self, msg, legal_choices, default=6):
        while True:
            sys.stdout.write(msg + " [default=\'%s\']:" % str(default))
            if not self.silent:
                choice = raw_input()
            else:
                return default
            if choice == "" or choice is None:
                return default
            if choice.isdigit() and int(choice) in legal_choices:
                return int(choice)
            else:
                print "Please input number in %s." % str(legal_choices)

    def _is_legal(self, strs, choices):
        for s in strs:
            if not s.isdigit() or not int(s) in choices:
                return False
        return True
