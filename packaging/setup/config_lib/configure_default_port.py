import os
import sys

sys.path.append("..")

def configure_default_port(options):
    from log import logger
    from installer_io import InstallerIO
    from configParser import ConfigParser
    from text import text
    io = InstallerIO(options.silent)

    config_file = os.path.join(options.chorus_path, "shared/chorus.properties")
    chorus_config = ConfigParser(config_file)
    alpine_config_file = os.path.join(options.chorus_path, "shared/ALPINE_DATA_REPOSITORY/configuration/deploy.properties")
    alpine_config = ConfigParser(alpine_config_file)

    ports = ["server_port", "solr_port"]

    menu = "\n".join(str(i+1) + ". %s: [default: %s]" % (ports[i], chorus_config[ports[i]]) for i in xrange(0, len(ports)))
    menu += "\n"
    alpine_ports = ["alpine_port"]

    menu += "\n".join(str(len(ports)+i+1) + ". %s: [default: %s]" % (alpine_ports[i], alpine_config[alpine_ports[i].replace("_", ".")]) \
                      for i in xrange(0, len(alpine_ports)))
    menu += "\n%d. exit" % (len(ports) + len(alpine_ports) + 1)
    num = io.require_menu(text.get("interview_question", "port_menu")  % menu,
                          range(1, len(ports)+len(alpine_ports)+2), default=len(ports)+len(alpine_ports)+1)
    if num in range(1, len(ports)+1):
        new_port = io.prompt_int(text.get("interview_question", "change_port") % ports[num-1], default=int(chorus_config[ports[num-1]]))
        chorus_config[ports[num-1]] = new_port
        chorus_config.write(config_file)
        logger.info("%s has successfully changed to %d" % (ports[num-1], new_port))
    elif num in range(len(ports)+1, len(ports)+1+len(alpine_ports)):
        new_port = io.prompt_int(text.get("interview_question", "change_port") % alpine_ports[num-len(ports)-1], default=int(alpine_config[alpine_ports[num-len(ports)-1].replace("_", ".")]))
        alpine_config[alpine_ports[num-len(ports)-1].replace("_", ".")] = new_port
        alpine_config.write(alpine_config_file)
        chorus_config["workflow.url"] = "http://%s:%d" % (alpine_config["alpine.host"], new_port)
        chorus_config.write(config_file)
        logger.info("%s has successfully changed to %d" % (alpine_ports[num-len(ports)-1], new_port))




