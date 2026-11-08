"""Mock Proxmox commands; never create containers, install packages or call the network."""
import os
from pathlib import Path
import subprocess
import tempfile

installer = Path(__file__).resolve().parents[1] / 'proxmox/install-image-server.sh'
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    # Bypass only the host root check in this temporary test copy.
    test_installer = root / 'installer.sh'
    test_installer.write_text(installer.read_text().replace("[[ $EUID -eq 0 ]] || fail 'Run as root on the Proxmox host.'", ':'))
    executable = root / 'mock'
    executable.write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['MOCK_LOG'], 'a') as log: log.write(name+' '+ ' '.join(args)+'\\n')
if name == 'uname': print('x86_64')
elif name == 'pvesh':
    if os.environ['CASE'] == 'occupied': sys.exit(1)
    print('123')
elif name == 'pvesm': print(args[args.index('--storage')+1]+' dir active 100000 0 100000 0%')
elif name == 'pveam' and args[0] == 'available': print('system debian-12-standard_12.12-1_amd64.tar.zst')
elif name == 'pct' and 'bash' in args:
    Path(os.environ['CONTAINER_SCRIPT']).write_text(sys.stdin.read())
    if os.environ['CASE'] == 'install-failed': sys.exit(1)
elif name == 'pct' and 'ip' in args: print('2: eth0 inet 192.0.2.50/24 scope global eth0')
''')
    executable.chmod(0o755)
    for command in ('pct', 'pveam', 'pvesm', 'pvesh', 'ip', 'curl', 'uname'):
        (root / command).symlink_to(executable)
    for case in ('success', 'occupied', 'install-failed'):
        log = root / f'{case}.log'
        env = dict(os.environ, PATH=f'{root}:'+os.environ['PATH'], CTID='123',
                   ROOTFS_STORAGE='local-lvm', IMAGE_DIR=str(root / 'images'),
                   MOCK_LOG=str(log), CONTAINER_SCRIPT=str(root / 'container.sh'), CASE=case)
        result = subprocess.run(['bash', str(test_installer)], env=env, capture_output=True, text=True)
        calls = log.read_text()
        if case == 'success':
            assert result.returncode == 0, result.stderr
            assert '--unprivileged 1' in calls and 'mp=/srv/osdcloud-images,ro=1' in calls
            assert 'http://192.0.2.50/install.wim' in result.stdout
            subprocess.run(['bash', '-n', str(root / 'container.sh')], check=True)
        else:
            assert result.returncode != 0
            if case == 'occupied': assert 'pct create' not in calls
            else: assert 'retained for inspection' in result.stderr
        assert 'pct destroy' not in calls
        print(f'PASS Proxmox installer {case}')
