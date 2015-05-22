import os
import sys
sys.path.append("..")
def configure_ldap(options):
    os.system("${EDITOR:-vi} " + os.path.join(options.chorus_path, "shared/ldap.properties"))

