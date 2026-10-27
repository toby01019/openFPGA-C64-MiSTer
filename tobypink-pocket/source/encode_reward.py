"""Build the current native bitmap reward scene."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('encode_reward_bitmap.py')), run_name='__main__')
