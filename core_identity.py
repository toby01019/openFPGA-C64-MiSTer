"""Distribution identity only: never modifies FPGA or game bytes."""
import json

OLD_ID = 'Experimental.C64MiSTer'
CORE_ID = 'toby01019.C64'
PLATFORM = 'c64'
URL = 'https://github.com/toby01019/openFPGA-C64-MiSTer'

def renamed_path(name):
    return name.replace(OLD_ID, CORE_ID).replace('Assets/c64mister/', 'Assets/c64/').replace('Platforms/c64mister.json', 'Platforms/c64.json')

def convert(files):
    result = {}
    for name, data in files.items():
        new_name = renamed_path(name)
        if name.endswith('/core.json') and OLD_ID in name:
            obj = json.loads(data)
            obj['core']['metadata'].update(author='toby01019', shortname='C64', platform_ids=[PLATFORM], url=URL,
                description='C64: disk autostart, activity, EasyFlash and Dock keyboard')
            data = (json.dumps(obj, indent=2)+'\n').encode()
        elif name.endswith('Platforms/c64mister.json'):
            obj = json.loads(data)
            obj['platform']['name'] = 'C64'
            data = (json.dumps(obj, indent=2)+'\n').encode()
        elif name.endswith(('.txt', '.md')) and not name.startswith(('validation-', 'tests/')):
            data = data.replace(b'Assets/c64mister/', b'Assets/c64/').replace(b'`Experimental.C64MiSTer` ID is intentionally retained for in-place upgrades.', b'`toby01019.C64` is the new core ID. Existing users: see MIGRATION-EN.txt.')
        assert new_name not in result, 'Identity path collision: '+new_name
        result[new_name] = data
    return result
