import sys, os
import pwd
import re
import shutil
import glob
import hashlib
import hmac
import base64
import platform
from color import bold
from log import logger
from installer_io import InstallerIO
from chorus_executor import ChorusExecutor
from configure import configure
from health_check import health_check
from func_executor import processify
from helper import get_version, migrate_alpine_conf
from text import text


CHORUS_PSQL = "\
if [ \"$CHORUS_HOME\" = \"\" ]; then\n\
    echo \"CHORUS_HOME is not set.  Exiting...\"\n\
else\n\
    $CHORUS_HOME/current/postgres/bin/psql -U postgres_chorus -p 8543 chorus;\n\
fi\n"

CHORUS_RAILS_CONSOLE = "\
if [ \"$CHORUS_HOME\" = \"\" ]; then\n\
    echo \"CHORUS_HOME is not set.  Exiting...\"\n\
else\n\
    RAILS_ENV=production $CHORUS_HOME/current/bin/ruby $CHORUS_HOME/current/script/rails console\n\
fi\n"

class ChorusSetup:
    """
    chorus installer
    """
    def __init__(self):
        self.database_username = None
        self.database_password = None
        self.alpine_installer = None
        self.alpine_release_path = None

    def set_path(self, options):
        failover_file = os.path.join(options.chorus_path, ".failover")
        if os.path.exists(failover_file):
           os.remove(failover_file)
        self.options = options
        self.io = InstallerIO(self.options.silent)
        self.executor = ChorusExecutor(self.options.chorus_path)
        self.chorus_version = get_version(self.options.chorus_path)
        self.alpine_version = None
        self.release_path = os.path.join(self.options.chorus_path, 'releases/%s' % self.chorus_version)
        self.shared = os.path.join(self.options.chorus_path, "shared")

    def construct_shared_structure(self):
        logger.debug("Construct shared structure in %s" % self.shared)
        self._mkdir_p(self.shared)
        self._mkdir_p(os.path.join(self.shared, "demo_data"))
        self._mkdir_p(os.path.join(self.shared, "libraries"))
        self._mkdir_p(os.path.join(self.shared, "solr"))
        self._mkdir_p(os.path.join(self.shared, "tmp"))
        self._cp_if_not_exist(os.path.join(self.release_path, "packaging/database.yml.example"), \
                              os.path.join(self.shared, "database.yml"))
        self._cp_if_not_exist(os.path.join(self.release_path, "packaging/sunspot.yml.example"), \
                              os.path.join(self.shared, "sunspot.yml"))
        self._cp_if_not_exist(os.path.join(self.release_path, "config/chorus.defaults.properties"), \
                              os.path.join(self.shared, "chorus.properties"))
        os.chmod(os.path.join(self.shared, "chorus.properties"), 0600)
        self._cp_f(os.path.join(self.release_path, "config/chorus.defaults.properties"), \
                   os.path.join(self.shared, "chorus.properties.example"))
        self._cp_f(os.path.join(self.release_path, "config/chorus.license.default"), \
                   os.path.join(self.shared, "chorus.license.default"))
        self._cp_if_not_exist(os.path.join(self.release_path, "config/chorus.license.default"), \
                              os.path.join(self.shared, "chorus.license"))
        os.chmod(os.path.join(self.shared, "chorus.license"), 0600)
        self._cp_f(os.path.join(self.release_path, "config/ldap.properties.active_directory"), \
                   os.path.join(self.shared, "ldap.properties.active_directory"))
        self._cp_f(os.path.join(self.release_path, "config/ldap.properties.opensource_ldap"), \
                   os.path.join(self.shared, "ldap.properties.opensource_ldap"))
        self._cp_if_not_exist(os.path.join(self.release_path, "config/ldap.properties.example"), \
                              os.path.join(self.shared, "ldap.properties"))
        os.chmod(os.path.join(self.shared, "ldap.properties"), 0600)

    def construct_data_structure(self):
        logger.debug("Construct data structure in %s" % self.options.data_path)
        for folder in ["db","system","log","solr/data"]:
            self.executor.run("mkdir -p %s" % os.path.join(self.options.data_path, folder))

    def link_shared_config(self):
        logger.debug("Linking shared configuration files to %s/config" % self.release_path)
        self._ln_sf(os.path.join(self.shared, "chorus.properties"), \
                   os.path.join(self.release_path, "config/chorus.properties"))
        self._ln_sf(os.path.join(self.shared, "chorus.license"), \
                   os.path.join(self.release_path, "config/chorus.license"))
        self._ln_sf(os.path.join(self.shared, "database.yml"), \
                   os.path.join(self.release_path, "config/database.yml"))
        self._ln_sf(os.path.join(self.shared, "sunspot.yml"), \
                   os.path.join(self.release_path, "config/sunspot.yml"))
        self._ln_sf(os.path.join(self.shared, "ldap.properties"), \
                   os.path.join(self.release_path, "config/ldap.properties"))
        self._ln_sf(os.path.join(self.shared, "demo_data"), \
                   os.path.join(self.release_path, "demo_data"))
        self._ln_sf(os.path.join(self.shared, "libraries"), \
                   os.path.join(self.release_path, "lib/libraries"))
    def link_data_folder(self):
        logger.debug("Linking data folders to %s" % self.options.data_path)
        os.chmod(os.path.join(self.options.data_path, "db"), 0700)
        self._ln_sf(os.path.join(self.options.data_path, "db"), \
                   os.path.join(self.shared, "db"))
        self._ln_sf(os.path.join(self.options.data_path, "log"), \
                   os.path.join(self.shared, "log"))
        self._ln_sf(os.path.join(self.options.data_path, "solr/data"), \
                   os.path.join(self.shared, "solr/data"))
        self._ln_sf(os.path.join(self.options.data_path, "system"), \
                   os.path.join(self.shared, "system"))

        self._ln_sf(os.path.join(self.shared, "db"), \
                   os.path.join(self.release_path, "postgres-db"))
        self._ln_sf(os.path.join(self.shared, "log"), \
                   os.path.join(self.release_path, "log"))
        self._ln_sf(os.path.join(self.shared, "solr/data"), \
                   os.path.join(self.release_path, "solr/data"))
        self._ln_sf(os.path.join(self.shared, "tmp"), \
                   os.path.join(self.release_path, "tmp"))
        self._ln_sf(os.path.join(self.shared, "system"), \
                   os.path.join(self.release_path, "system"))
        logger.debug("Linking nginx logs to %s/vendor/nginx/nginx_dist/nginx_data/logs" % self.release_path)
        self._mkdir_p(os.path.join(self.shared, "log/nginx"))
        self._ln_sf(os.path.join(self.shared, "log/nginx"), \
                   os.path.join(self.release_path, "vendor/nginx/nginx_dist/nginx_data/logs"))

        self._ln_sf(os.path.join(self.release_path, "packaging/chorus_control.sh"), \
                   os.path.join(self.options.chorus_path, "chorus_control.sh"))
        self._ln_sf(os.path.join(self.release_path, "packaging/setup/chorus_server"), \
                   os.path.join(self.options.chorus_path, "chorus_server"))
        self.executor.run("chmod -R 0555 %s" % os.path.join(self.release_path, "public"))

    def extract_postgres(self):
        logger.debug("Extract postgres database to %s", self.release_path)
        os_name, version, release = platform.linux_distribution()
        if os_name.lower() in ["redhad", "centos"]  and version.startswith("5"):
            self.executor.extract_postgres("postgres-redhat5.5-9.2.4.tar.gz")
        elif os_name.lower() in ["redhad", "centos"]  and version.startswith("6"):
            self.executor.extract_postgres("postgres-redhat6.2-9.2.4.tar.gz")
        elif os_name.lower()  == "susu" and version == "11":
            self.executor.extract_postgres("postgres-suse11-9.2.4.tar.gz")
        else:
            raise Exception("postgres not installed, no version match the operation system")

    def _ln_sf(self, src, dst):
        logger.debug("Link %s to %s" % (src, dst))
        if os.path.lexists(dst):
            if os.path.isdir(dst) and not os.path.islink(dst):
                shutil.rmtree(dst)
            else:
                os.remove(dst)
        os.symlink(src, dst)

    def _mkdir_p(self, path):
        logger.debug("mkdir %s" % path)
        if os.path.exists(path):
            return
        os.makedirs(path)

    def _cp_if_not_exist(self, src, dst):
        logger.debug("cp %s to %s if not exists" % (src, dst))
        if os.path.exists(dst):
            return
        shutil.copyfile(src, dst)

    def _cp_f(self, src, dst):
        logger.debug("cp -f %s to %s" % (src, dst))
        if os.path.exists(dst):
           os.remove(dst)
        shutil.copyfile(src, dst)

    def _eula_by_brand(self):
        filename = ""
        if os.getenv('PIVOTALLABEL') is None:
            filename = 'eula_alpine.txt'
        else:
            filename = 'eula_emc.txt'
        filename = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)
        with open(filename, 'r') as f:
            eula = f.read();
        return eula

    def prompt_for_eula(self):
        eula = self._eula_by_brand()
        print eula
        ret = self.io.require_confirmation("Do you accept the terms above?")
        if not ret:
            logger.fatal("Setup aborted, Cancelled by user")
            quit()

    def get_passphrase(self):
        key_file_path = os.path.join(self.options.chorus_path, "shared")
        key_file = os.path.join(key_file_path, 'secret.key')
        if not os.path.exists(key_file):
            return self.options.passphrase
        elif os.path.exists(key_file) and self.options.passphrase != "":
            return self.options.passphrase
        return None

    #@processify(msg='->Configuring secret key...')
    def configure_secret_key(self, passphrase):
        key_file_path = os.path.join(self.options.chorus_path, "shared")
        key_file = os.path.join(key_file_path, 'secret.key')
        if passphrase is not None:
            if passphrase.strip() == '':
                passphrase = os.urandom(32)
            secret_key = base64.b64encode(hmac.new(passphrase, digestmod=hashlib.sha256).digest())
            with open(key_file, 'w') as f:
                f.write(secret_key)
        else:
            logger.debug(key_file + " already existed, skipped")
        logger.debug("Secure " + key_file)
        os.chmod(key_file, 0600)
        symbolic = os.path.join(self.release_path, "config/secret.key")
        logger.debug("Create symbolic to " + symbolic)
        if os.path.lexists(symbolic):
            os.remove(symbolic)
        os.symlink(key_file, symbolic)

    #@processify(msg="->Configuring secret token...")
    def configure_secret_token(self):
        token_file_path = os.path.join(self.options.chorus_path, "shared")
        token_file = os.path.join(token_file_path, 'secret.token')

        if not os.path.exists(token_file):
            with open(token_file, 'w') as f:
                f.write(os.urandom(64).encode('hex'))
        else:
            logger.debug(token_file + " already existed, skipped")
        logger.debug("Configuring secret token...")
        logger.debug("Secure " + token_file)
        os.chmod(token_file, 0600)
        symbolic = os.path.join(self.release_path, "config/secret.token")
        logger.debug("Create symbolic to " + symbolic)
        if os.path.lexists(symbolic):
            os.remove(symbolic)
        os.symlink(token_file, symbolic)

    def generate_paths_file(self):
        file_path = os.path.join(self.options.chorus_path, "chorus_path.sh")
        logger.debug("Generating paths file: " + file_path)
        with open(file_path, 'w') as f:
            f.write("export CHORUS_HOME=%s\n" % self.options.chorus_path)
            f.write("export CHORUS_DATA=%s\n" % self.options.data_path)
            f.write("export PATH=$PATH:$CHORUS_HOME\n")
            f.write("export PGPASSFILE=$CHORUS_HOME/.pgpass")

    def generate_chorus_psql_files(self):
        file_path = os.path.join(self.options.chorus_path, ".pgpass")
        logger.debug("generating chorus_psql files")
        if os.path.exists(file_path):
            os.chmod(file_path, 0600)
        with open(file_path, "w") as f:
            f.write("*:*:*:"+ self.database_username + ":" + self.database_password)
        os.chmod(file_path, 0400)

        file_path = os.path.join(self.options.chorus_path, "chorus_psql.sh")
        if os.path.exists(file_path):
            logger.debug(file_path + " existed, skipped")
        else:
            with open(file_path, "w") as f:
                f.write(CHORUS_PSQL)
        os.chmod(file_path, 0500)

    def generate_chorus_rails_console_file(self):
        file_path = os.path.join(self.options.chorus_path, "chorus_rails_console.sh")
        logger.debug("generating chorus_rails_console file")
        if os.path.exists(file_path):
            logger.debug(file_path + " existed, skipped")
            return
        with open(file_path, "w") as f:
            f.write(CHORUS_RAILS_CONSOLE)
        os.chmod(file_path,0700)

    def create_database_config(self):
        database_config_file = os.path.join(self.options.chorus_path, "shared/database.yml")

        content = ""
        with open(database_config_file, 'r') as f:
            lines = f.readlines()
            for i in xrange(0, len(lines)):
                if lines[i].lstrip().startswith("username:"):
                    self.database_username = lines[i].split(":")[1].strip()
                elif lines[i].lstrip().startswith("password:"):
                    if "!binary" in lines[i]:
                        self.database_password = base64.b64decode(lines[i+1].strip())
                        logger.debug("password generated already, skipped")
                        return
                    else:
                        self.database_password = os.urandom(16).encode('hex')
                        lines[i] = lines[i].split(":")[0] + ": !binary |-\n"
                        lines[i] = lines[i] + "    " + base64.b64encode(self.database_password) + "\n"
                if not ":" in lines[i] and not lines[i].startswith("---"):
                    continue
                content += lines[i]
        with open(database_config_file, 'w') as f:
            f.write(content)

    @processify(msg=text.get("step_msg", "initialize_db"), interval=1.5)
    def setup_database(self):
        logger.debug("->Initializing database...")
        pwfile = os.path.join(self.release_path, "postgres/pwfile")
        if os.path.exists(pwfile):
            os.chmod(pwfile, 0600)
        with open(pwfile, "w") as f:
            f.write(self.database_password)
        os.chmod(pwfile, 0400)
        self.executor.initdb(self.options.data_path, self.database_username)
        self.executor.start_postgres()
        db_commands = "db:create db:migrate"
        db_commands += " db:seed"
        db_commands += " enqueue:refresh_and_reindex"
        self.executor.rake(db_commands)
        self.executor.stop_postgres()

    @processify(msg=text.get("step_msg", "db_migrate"), interval=1.5)
    def upgrade_database(self):
        self.executor.start_postgres()
        logger.debug("->Running database migrations...")
        db_commands = "db:migrate"
        db_commands += " enqueue:refresh_and_reindex"
        logger.debug("Running rake " + db_commands)
        self.executor.rake(db_commands)
        self.executor.stop_postgres()

    @processify(msg=text.get("step_msg", "db_validation"), interval=1.5)
    def validate_data_sources(self, msg="", interval=1.5):
        logger.debug("->Running data validation...")
        self.executor.start_postgres()
        self.executor.rake("validations:data_source")

    @processify(msg=text.get("step_msg", "stop_pre_chorus"), interval=1.5)
    def stop_previous_release(self):
        logger.debug("->Shutting down previous Chorus install...")
        self.executor.stop_previous_release()

    def is_alpine_exits(self):
        alpine_dir = os.path.join(self.release_path, "vendor/alpine")
        alpine_sources = [ f for f in glob.glob(os.path.join(alpine_dir, "alpine*.sh")) ]
        if len(alpine_sources) <= 0:
            return False
        else:
            alpine_sources.sort(key=lambda x: os.path.getmtime(x), reverse=True)
            self.alpine_installer = alpine_sources[0]
            self.alpine_version = os.path.basename(self.alpine_installer.rstrip(".sh"))
            self.alpine_release_path = os.path.join(self.options.chorus_path, "alpine-releases/%s" % self.alpine_version)
            return True

    def configure_alpine(self):
        @processify(msg=text.get("step_msg", "setting_up_alpine") % self.alpine_version, interval=1.5)
        def configure():
            logger.debug("Extracting %s to %s" % (self.alpine_installer, self.alpine_release_path))
            self.executor.run("sh %s --target %s --noexec" % (self.alpine_installer, self.alpine_release_path))
            logger.debug("Preparing Alpine Data Repository")
            alpine_data_repo = os.path.join(self.options.chorus_path, "shared/ALPINE_DATA_REPOSITORY")
            if os.path.exists(alpine_data_repo):
                logger.debug("Alpine Data Repository existed, skipped")
                if not os.path.exists(os.path.join(alpine_data_repo, "configuration/hadoop_version.properties")):
                    shutil.copyfile(os.path.join(self.alpine_release_path, "ALPINE_DATA_REPOSITORY/configuration/hadoop_version.properties"),\
                                    os.path.join(alpine_data_repo, "configuration/hadoop_version.properties"))
                migrate_alpine_conf(os.path.join(alpine_data_repo, "configuration/alpine.conf"), \
                                    os.path.join(self.alpine_release_path, "ALPINE_DATA_REPOSITORY/configuration/alpine.conf"))

            else:
                shutil.copytree(os.path.join(self.alpine_release_path, "ALPINE_DATA_REPOSITORY"), alpine_data_repo)
        configure()
    def link_current_to_release(self, link_name, rel_path):
        current = os.path.join(self.options.chorus_path, link_name)
        if os.path.lexists(current):
            if not os.path.islink(current):
                self.shutil.rmtree(current)
            os.unlink(current)
        os.symlink(rel_path, current)

    def source_chorus_path(self):
        logger.debug("source %s/chorus_path.sh" % self.options.chorus_path)
        content = ""
        if os.path.exists(os.path.join(os.path.expanduser("~"), ".bashrc")):
            with open(os.path.join(os.path.expanduser("~"), ".bashrc"), "r") as f:
                content = f.read()
        if not "source %s/chorus_path.sh" % self.options.chorus_path in content:
            with open(os.path.join(os.path.expanduser("~"), ".bashrc"), "a") as f:
                f.write("source %s/chorus_path.sh\n" % self.options.chorus_path)

        if os.getenv("CHORUS_HOME") == None:
            os.environ["CHORUS_HOME"] = self.options.chorus_path
    def setup(self, options, is_upgrade):
        self.set_path(options)
        #if not io.require_confirmation("Do you want to set up the chorus, "
        #                                    + "please make sure you have installed chorus before setting up?"):
        #    logger.fatal("Setup aborted, Cancelled by user")
        #    quit()
        #if not self.options.disable_spec:
        #    health_check()
        #self.prompt_for_eula()

        #pre step:
        passphrase = self.get_passphrase()
        logger.debug("Construct Chorus and Data Directory:")
        self.construct_shared_structure()
        self.construct_data_structure()
        self.link_shared_config()
        self.link_data_folder()
        self.generate_paths_file()

        self.configure_secret_key(passphrase)
        self.configure_secret_token()

        if is_upgrade:
            logger.info(bold(text.get("step_msg", "update_database")))
        else:
            logger.info(bold(text.get("step_msg", "create_database")))
        self.extract_postgres()
        if is_upgrade:
            self.validate_data_sources()
            self.stop_previous_release()
            self.upgrade_database()
        else:
            self.create_database_config()
            self.generate_chorus_psql_files()
            self.generate_chorus_rails_console_file()
            self.setup_database()
            #self.enqueue_solr_reindex()
        self.link_current_to_release("current", self.release_path)

        if self.is_alpine_exits() and self.options.chorus_only is False:
            logger.info(bold(text.get("step_msg", "install_alpine")))
            self.configure_alpine()
            self.link_current_to_release("alpine-current", self.alpine_release_path)
        self.source_chorus_path()
        print "*" * 60
        print text.get("status_msg", "success_install") % \
                (self.options.chorus_path, self.options.data_path, self.chorus_version, self.alpine_version)
        print "*" * 60

        #disable it, health check is not good
        #if self.io.require_confirmation(text.get("interview_question", "do_health_check"), default="no"):
        #    health_check()
        if self.io.require_confirmation(text.get("interview_question", "do_configure") , default="no"):
            configure.config(self.options, is_upgrade)

        print bold(text.get("status_msg", "setup_complete"))
        if is_upgrade:
            print text.get("status_msg", "upgrade")
        print "*" * 60
        print text.get("status_msg", "setup_post_step") % pwd.getpwuid(os.getuid()).pw_name
        print "*" * 60

chorus_set = ChorusSetup()
