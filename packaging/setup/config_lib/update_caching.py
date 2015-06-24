import sys
import os
import re
sys.path.append("..")

def update_chorus_caching(options):
    from log import logger
    from text import text
    from chorus_executor import ChorusExecutor
    from func_executor import processify
    @processify(msg=text.get("step_msg", "update_caching"), interval=1.5)
    def run():
        executor = ChorusExecutor(options.chorus_path)
        executor.start_postgres()
        executor.rake("chorus:caching")
        executor.stop_postgres()
    run()
