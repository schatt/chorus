import ConfigParser, os

config = ConfigParser.RawConfigParser()
config.read(os.path.join(os.path.abspath(os.path.dirname(__file__)), "msg.cfg"))

text = config
if __name__ == '__main__':
    print "\n"
    print text.get("status_msg", "chorus_status")
