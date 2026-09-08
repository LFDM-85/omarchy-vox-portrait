"""Pass dictation through unchanged and publish a short-lived UI event."""
import json
import os
from pathlib import Path
import sys
import tempfile
import time


def publish(text):
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "vox-portrait"
    directory.mkdir(mode=0o700, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=directory)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump({"text": text, "time": time.time()}, stream)
        os.replace(temporary, directory / "transcript.json")
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    raw = sys.stdin.buffer.read()
    try:
        publish(raw.decode("utf-8"))
    except (OSError, KeyError, UnicodeError):
        pass
    sys.stdout.buffer.write(raw)
