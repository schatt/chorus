import threading
import sys
import time
from multiprocessing import Process, Queue
from color import fail, done
def processify(msg='', interval=0.5):

    def wrap(func):
        def process_func(q, *args, **kwargs):
            try:
                ret = func(*args, **kwargs)
            except Exception as e:
                ret = None
                error = e
            else:
                error = None
            q.put((ret, error))
        def wrapper(*args, **kwargs):
            q = Queue()
            p = Process(target=process_func, args=[q]+list(args), kwargs=kwargs)
            p.start()
            sys.__stdout__.write(msg+"\n")
            while p.is_alive():
                sys.stdout.write(".")
                sys.stdout.flush()
                time.sleep(interval)
            ret, error = q.get()
            if error:
                sys.__stdout__.write("\r" + "." * 60 + fail() + "\n")
                raise Exception(error)
            sys.__stdout__.write("\r" + "." * 60 + done() + "\n")
            return ret
        return wrapper
    return wrap

@processify(msg='processing...')
def worker():
    time.sleep(10)




