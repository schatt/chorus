from optparse import OptionParser
import os, sys
def get_options(args):
    usage = "usage: %prog <command> [options]\n\n" \
            + "Commands:\n"\
            + "  setup:\t\tsetup the chorus and alpine if exist\n" \
            + "  health_check:\t\tcheck the system health for chorus and alpine\n" \
            + "  \t\t\trun \"%prog health_check help\" for more info of health check\n"\
            + "  configure:\t\tconfigure the chorus property and alpine property\n"
    parser = OptionParser(usage=usage)

    parser.add_option('--chorus_user', action="store", dest="chorus_user",
                      help="provide the chorus user [default: %default]", default="chorus")
    parser.add_option('--chorus_path', action="store", dest="chorus_path",
                      help="provide the chorus path [default: %default]", default=os.getenv("CHORUS_HOME", "/usr/local/chorus"))
    parser.add_option('--data_path', action="store", dest="data_path",
                      help="provide the chorus data path [default: %default]", default=os.getenv("CHORUS_DATA", "/data/chorus"))
    parser.add_option('--passphrase', action="store", dest="passphrase",
                      help="provide the passphrase [default: \'%default\']", default="")
    parser.add_option('--disable_spec', action="store_true", dest="disable_spec",
                      help="disable the spec check [default: %default]", default=False)
    parser.add_option('--chorus_only', action="store_true", dest="chorus_only",
                      help="only setup chorus, will not install alpine [default: %default]", default=False)
    parser.add_option('-s', '--silent', action="store_true", dest="silent",
                      help="runing script silently [default: %default]", default=False)
    parser.add_option('-f', '--force', action="store_true", dest="force",
                      help="force reinitialize the database [default: %default]", default=False)
    options, args = parser.parse_args(args)
    if options.chorus_path.rstrip("/").endswith("current"):
        options.chorus_path = options.chorus_path.rstrip("/").rstrip("/current")
    if len(args) < 2 or args[1] not in ["setup", "health_check", "configure", "install"]:
        print "[error] please specify the command"
        parser.print_help()
        sys.exit(1)
    if not os.path.exists(options.chorus_path) and not args[1] == "install":
        print "[error] %s not exists" % options.chorus_path
        sys.exit(1)
    elif not os.path.exists(options.data_path) and not args[1] == "install":
        print "[error] %s not exists" % options.data_path
        sys.exit(1)
    return options, args[1], args[2:]

