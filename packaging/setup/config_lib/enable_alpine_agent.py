import sys
import os
import re
sys.path.append("..")

def enable_alpine_agent(options):
    from log import logger
    from installer_io import InstallerIO
    from text import text
    io = InstallerIO(options.silent)
    contents = ""
    alpine_conf = os.path.join(options.chorus_path, "shared/ALPINE_DATA_REPOSITORY/configuration/alpine.conf")
    with open(alpine_conf, "r") as f:
        contents = f.read()

    content = re.findall(r"(#?\s*agent.*{.*?})", contents, re.DOTALL)[0]
    dic = {}
    agent_dic={}
    idx = 1
    for line in content.split("\n"):
        if "enabled" in line:
            if line.split("#")[-2].split("=")[1].strip() == "true" or line.strip().startswith("#"):
                agent_dic[idx] = "(enabled)"
            else:
                agent_dic[idx] = ""
            idx += 1
    idx = 1
    all_agents = ""
    with open(os.path.join(options.chorus_path, "alpine-current/ALPINE_DATA_REPOSITORY/configuration/alpine.conf")) as f:
        all_agents = re.findall(r"(#?\s*agent.*{.*?})", f.read(), re.DOTALL)[0]
        for line in all_agents.split("\n"):
            if "enabled" in line:
                dic[idx] = line.split("#")[-1].strip()
                if not agent_dic.has_key(idx):
                    agent_dic[idx] = ""
                idx += 1
    agents_str = "\n".join(str(e) + ". " + dic[e] + " " + agent_dic[e] for e in dic.keys())

    agents = io.require_selection(text.get("interview_question", "alpine_agent_menu") % agents_str, range(1, idx), default=[4])

    replace = ""
    idx = 1
    for line in all_agents.split("\n"):
        line = line.lstrip().lstrip("#")
        if "enabled" in line:
            line = "\t%d.enabled=%s\t# %s" % (idx, str(idx in agents).lower(), dic[idx])
            idx += 1
        replace += line + "\n"
    contents = contents.replace(content, replace.rstrip("\n"))
    with open(alpine_conf, "w") as f:
        f.write(contents)
    logger.info(str([dic[agent] for agent in agents]) + " is enabled.")
    logger.info(text.get("status_msg", "enable_agent_post_step") % alpine_conf)

