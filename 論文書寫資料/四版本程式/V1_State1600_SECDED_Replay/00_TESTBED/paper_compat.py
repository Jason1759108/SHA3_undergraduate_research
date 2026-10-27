"""Small standard-library compatibility helpers for Python 2.7 and Python 3.
Only the filesystem/process/CSV operations used by the paper runners are provided.
"""
from __future__ import print_function, division
import csv as _csv
import errno
import glob as _glob
import io
import math
import os
import subprocess
import sys
import time
try:
    text_type = unicode
except NameError:
    text_type = str
PY2 = sys.version_info[0] == 2


class Path(str):
    def __new__(cls, value):
        if PY2 and isinstance(value, text_type):
            value = value.encode(sys.getfilesystemencoding() or 'utf-8')
        return str.__new__(cls, value)

    def __truediv__(self, other):
        return Path(os.path.join(self, str(other)))
    __div__ = __truediv__

    @property
    def parent(self): return Path(os.path.dirname(self))
    @property
    def name(self): return os.path.basename(self)
    @property
    def suffix(self): return os.path.splitext(self)[1]
    def resolve(self): return Path(os.path.realpath(os.path.abspath(self)))
    def as_posix(self): return self.replace('\\', '/')
    def relative_to(self, root): return Path(os.path.relpath(self, root))
    def exists(self): return os.path.exists(self)
    def is_file(self): return os.path.isfile(self)
    def stat(self): return os.stat(self)
    def iterdir(self): return (self/name for name in os.listdir(self))
    def glob(self, pattern): return (Path(p) for p in _glob.glob(os.path.join(self, pattern)))
    def mkdir(self, parents=False, exist_ok=False):
        try:
            (os.makedirs if parents else os.mkdir)(self)
        except OSError as exc:
            if not (exist_ok and exc.errno == errno.EEXIST and os.path.isdir(self)):
                raise
    def open(self, mode='r', encoding=None, errors=None, newline=None):
        return io.open(self, mode, encoding=encoding, errors=errors, newline=newline)
    def read_bytes(self):
        with self.open('rb') as stream: return stream.read()
    def read_text(self, encoding='utf-8', errors='strict'):
        return self.read_bytes().decode(encoding, errors)
    def write_text(self, data, encoding='utf-8'):
        if not isinstance(data, text_type): data = data.decode(encoding)
        with self.open('wb') as stream: return stream.write(data.encode(encoding))


def emit(*args, **kwargs):
    kwargs.pop('flush', None)
    print(*args, **kwargs)
    sys.stdout.flush()


def isfinite(value): return not (math.isnan(value) or math.isinf(value))


def which(name):
    if os.path.dirname(name):
        return name if os.path.isfile(name) and os.access(name, os.X_OK) else None
    suffixes = [''] + os.environ.get('PATHEXT', '').split(os.pathsep) if os.name == 'nt' else ['']
    for folder in os.environ.get('PATH', '').split(os.pathsep):
        for ext in suffixes:
            candidate = os.path.join(folder, name + ext)
            if os.path.isfile(candidate) and os.access(candidate, os.X_OK): return candidate
    return None


def run_process(command, cwd=None, env=None, stdout=None, stderr=None, timeout=None, check=False):
    proc = subprocess.Popen([str(s) for s in command], cwd=str(cwd) if cwd else None,
                            env=env, stdout=stdout, stderr=stderr)
    started = time.time()
    try:
        while proc.poll() is None:
            if timeout is not None and time.time() - started >= timeout:
                proc.kill(); proc.wait()
                raise RuntimeError('Command timed out after {} seconds: {}'.format(timeout, command))
            time.sleep(0.05)
    except BaseException:
        if proc.poll() is None:
            proc.kill(); proc.wait()
        raise
    if check and proc.returncode:
        raise subprocess.CalledProcessError(proc.returncode, command)
    return proc


def csv_open(path):
    # Python 2 csv requires binary streams; Python 3 csv requires text streams.
    return open(str(path), 'wb') if PY2 else io.open(str(path), 'w', encoding='utf-8', newline='')


def _csv_value(value):
    return value.encode('utf-8') if PY2 and isinstance(value, text_type) else value


class DictWriter(object):
    def __init__(self, stream, fieldnames):
        self.fields = list(fieldnames)
        self.writer = _csv.DictWriter(stream, fieldnames=[_csv_value(k) for k in self.fields])
    def writeheader(self):
        self.writerow(dict((k, k) for k in self.fields))
    def writerow(self, row):
        self.writer.writerow(dict((_csv_value(k), _csv_value(v)) for k, v in row.items()))
    def writerows(self, rows):
        for row in rows: self.writerow(row)
