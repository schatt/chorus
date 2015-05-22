import os
import pwd
import subprocess
import shlex
from log import logger
from helper import get_version
class PSQLException(Exception):
    pass

class RAKEException(Exception):
    pass

class ChorusExecutor:
    def __init__(self, chorus_path=None):
        self.chorus_path = chorus_path
        if chorus_path is None:
            self.release_path = None
        else:
            self.release_path = os.path.join(chorus_path, 'releases/%s' % get_version(chorus_path))

    def call(self, command):
        logger.debug(command)
        return subprocess.call(shlex.split(command))

    def run(self, command, postgres_bin_path=None):
        if self.release_path is not None:
            if postgres_bin_path is None:
                postgres_bin_path = self.release_path
            command = "PATH=%s/postgres/bin:$PATH && %s" % (postgres_bin_path, command)

        logger.debug(command)
        p = subprocess.Popen(command, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = p.communicate()
        if stdout:
            logger.debug(stdout)
        if stderr:
            logger.debug(stderr)
        return p.returncode, stdout, stderr

    def run_as_user(self, command, user):
        """
        only can be used as root user (only useful in install mode)
        """
        def demote(user_uid, user_gid):
            os.setgid(user_gid)
            os.setuid(user_uid)
        pw_record = pwd.getpwnam(user)
        user_uid = pw_record.pw_uid
        user_gid = pw_record.pw_gid
        user_name = pw_record.pw_name
        user_home_dir = pw_record.pw_dir
        env = {}
        ret, stdout, stderr = self.run("su - %s -c \"env\"" % user)
        if ret != 0:
            raise Exception(stderr)
        for line in stdout.strip().split("\n"):
            env[line.split("=")[0]] = line.split("=")[1]
        return subprocess.call(shlex.split(command), preexec_fn=demote(user_uid, user_gid), env=env)

    def extract_postgres(self, package_name):
        self.run("tar xzfv %s -C %s" % (os.path.join(self.release_path, "packaging/postgres/" + package_name),\
                                        self.release_path))

    def chorus_control(self, command):
       command = "CHORUS_HOME=%s %s %s/packaging/chorus_control.sh %s" % \
               (self.release_path, self.alpine_env(), self.release_path, command)
       (ret, stdout, stderr) = self.run(command)
       if ret != 0:
           raise Exception("chorus_constrol.sh command failed")
       return (ret, stdout, stderr)

    def previous_chorus_control(self, command):
        command = "CHORUS_HOME=%s %s %s %s" % \
                (os.path.join(self.chorus_path, "current"), self.alpine_env(),\
                os.path.join(self.chorus_path, "chorus_control.sh"), command)
        (ret, stdout, stderr) = self.run(command)
        if ret != 0:
           raise Exception("chorus_constrol.sh command failed")
        return (ret, stdout, stderr)

    def alpine_env(self):
        return "ALPINE_HOME=%s/alpine-current ALPINE_DATA_REPOSITORY=%s/shared/ALPINE_DATA_REPOSITORY" % \
                (self.chorus_path, self.chorus_path)

    def start_previous_release(self):
        self.previous_chorus_control("start")

    def stop_previous_release(self):
        self.previous_chorus_control("stop")
        #self.run("killall chorus")
    def start_postgres(self):
        logger.debug("Starting postgres...")
        ret, stdout, stderr = self.chorus_control("start postgres")
        if "postgres failed" in stdout:
            raise PSQLException(stdout)

    def stop_postgres(self):
        logger.debug("Stopping postgres")
        ret, stdout, stderr = self.chorus_control("stop postgres")
        if "postgres failed" in stdout:
            raise PSQLException(stdout)

    def initdb(self, data_path, database_user):
        command = "initdb --locale=en_US.UTF-8 -D %s/db --auth=md5 --pwfile=%s/postgres/pwfile --username=%s" % \
                (data_path, self.release_path, database_user)
        ret, stdout, stderr = self.run(command)
        #if "exists but is not empty" in stderr:
        #    logger.warning(stderr)

    def rake(self, command):
        command = "cd %s && RAILS_ENV=production bin/ruby -S bin/rake %s --trace" % \
                (self.release_path, command)
        ret, stdout, stderr = self.run(command)
        if "rake aborted" in stderr:
            raise RAKEException(stderr)

