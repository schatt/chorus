import os
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

