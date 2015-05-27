import os
import re
from log import logger
def get_version(chorus_path):
    version = None
    with open(os.path.join(chorus_path, "version_build"), "r") as f:
        version = f.read().strip()
    return version

def is_upgrade(chorus_path, data_path):
    failover_file = os.path.join(chorus_path, ".failover")
    upgrade = not os.path.exists(failover_file) \
            and os.path.exists(os.path.join(chorus_path, "shared"))\
            and os.listdir(os.path.join(chorus_path, "shared")) != []\
            and os.path.exists(os.path.join(data_path, "db")) \
            and os.listdir(os.path.join(data_path, "db")) != []
    return upgrade

def failover(chorus_path, data_path, is_upgrade):
    if not is_upgrade:
        try:
            with open(os.path.join(chorus_path, ".failover"), "w") as f:
                f.write("failover")
        except IOError:
            pass

def get_agents(alpine_conf):
    with open(alpine_conf, "r") as f:
        agent_dic = []
        agents = re.findall("hadoop\.version\..*\.agents\..*\.enabled=[a-z]+", f.read())
        for agent in agents:
            agent = agent.split(".")
            if agent[5].split("=")[1] == "false":
                agent_dic.append([agent[4], agent[2], ""])
            elif  agent[5].split("=")[1] == "true":
                agent_dic.append([agent[4], agent[2], "(enabled)"])

    return sorted(agent_dic, key=lambda x: x[0])

def migrate_alpine_conf(alpine_conf, alpine_new_conf):
    with open(alpine_conf, "r") as f:
        contents = f.read()
    agent_dic = get_agents(alpine_new_conf)
    org_agent_dic = get_agents(alpine_conf)
    if len(org_agent_dic) > 0:
        agent_content = ""
        for agent in agent_dic:
            if "hadoop.version.%s.agents.%s.enabled" % (agent[1], agent[0]) not in contents:
                agent_content += "%shadoop.version.%s.agents.%s.enabled=%s" % (" "*4, agent[1], agent[0], str(agent[2] == '(enabled)').lower())
        if agent_content == "":
            return
    else:
        uncomments = ""
        for line in contents.split("\n"):
            if line.lstrip().startswith("#"):
                continue
            uncomments += line + "\n"
        for agent in agent_dic:
            if "%s.enabled=true" % agent[0] in uncomments:
                agent[2] = "(enabled)"
            elif "%s.enabled=false" % agent[0] in uncomments:
                agent[2] = ""

        agent_content = "\n".join("%shadoop.version.%s.agents.%s.enabled=%s" % (" "*4, agent[1], agent[0], str(agent[2] == '(enabled)').lower()) for agent in agent_dic)
    new_contents = ""
    for line in contents.split("\n"):
        if line.lstrip().startswith("alpine") and "{" in line:
            line += "\n" + agent_content
        new_contents += line + "\n"
    contents = new_contents
    with open(alpine_conf, "w") as f:
        f.write(contents)

if __name__ == "__main__":
    migrate_alpine_conf("/usr/local/chorus/shared/ALPINE_DATA_REPOSITORY/configuration/alpine.conf", "/usr/local/chorus/alpine-current/ALPINE_DATA_REPOSITORY/configuration/alpine.conf")
