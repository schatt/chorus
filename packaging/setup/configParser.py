class ConfigParser(dict):
    def __init__(self, file_name):
       # self._dic = {}
        super(ConfigParser, self).__init__()
        self._config = []
        with open(file_name, 'r') as f:
            count = 0
            for line in f:
                if not line.lstrip().startswith("#") and "=" in line:
                    line = line.split("=", 1)
                    self[line[0].strip()] = line[1].lstrip().strip("\n")
                else:
                    self[line.strip("\n")] = None
                count += 1

    def write(self, file_name):
        with open(file_name, 'w') as f:
            for line in self._config:
                if self[line] is None:
                    f.write(str(line) + "\n")
                else:
                    f.write(str(line) + " = " + str(self[line]) + "\n")

    def __setitem__(self, key, value):
        if not self.has_key(key):
            self._config.append(key)
        super(ConfigParser, self).__setitem__(key, value)

    def __getitem__(self, key):
        if self.has_key(key):
            return super(ConfigParser, self).__getitem__(key)
        return ""

if __name__  ==  "__main__":
    config = ConfigParser("/usr/local/chorus/shared/chorus.properties")
    import sys
    config["nnn"] = 7777
    print config["server_port"]

