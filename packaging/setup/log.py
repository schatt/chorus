import os, sys, getpass
import logging

def getLogger():
    logger = logging.getLogger(getpass.getuser())
    logger.setLevel(logging.DEBUG)

    #create console handler and set level to info
    formatter = logging.Formatter("%(levelname)s : %(message)s")
    consolehandler = logging.StreamHandler()
    consolehandler.setLevel(logging.INFO)
    consolehandler.setFormatter(formatter)
    logger.addHandler(consolehandler)

    #create file handler and set level to debug
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s : %(message)s')
    fileHandler = logging.FileHandler('/tmp/install.log')
    fileHandler.setLevel(level=logging.DEBUG)
    fileHandler.setFormatter(formatter)
    logger.addHandler(fileHandler)

    return logger

logger = getLogger()
