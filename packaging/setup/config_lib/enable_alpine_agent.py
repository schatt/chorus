import sys
import os
import re
sys.path.append("..")

def enable_alpine_agent(options):
    from log import logger
    from installer_io import InstallerIO
    from text import text
    from helper import get_agents
    io = InstallerIO(options.silent)

    alpine_conf = os.path.join(options.chorus_path, "shared/ALPINE_DATA_REPOSITORY/configuration/alpine.conf")
    agent_dic = get_agents(alpine_conf)

    with open(alpine_conf, "r") as f:
        contents = f.read()

    agents_str = "\n".join(str(key+1) + ". " + agent_dic[key][1] + " " + agent_dic[key][2] for key in range(0, len(agent_dic)))
    agents_str += "\n%d. exit" % (len(agent_dic) + 1)
    agents = io.require_selection(text.get("interview_question", "alpine_agent_menu") % agents_str, range(1, len(agent_dic)+2), default=[4])

    if (len(agent_dic) + 1) in agents:
        return

    for i in range(1, len(agent_dic) + 1):
        contents = re.sub("hadoop.version.%s.agents.%s.enabled=[a-z]+" % (agent_dic[i-1][1], agent_dic[i-1][0]),\
                          "hadoop.version.%s.agents.%s.enabled=%s" % (agent_dic[i-1][1], agent_dic[i-1][0], str(i in agents).lower()),
                          contents)

    with open(alpine_conf, "w") as f:
        f.write(contents)
    logger.info(str([agent_dic[agent-1][1] for agent in agents]) + " is enabled.")
    logger.info(text.get("status_msg", "enable_agent_post_step") % alpine_conf)

