"""Run XCTest via WSL swiftc without depending on a Package.swift.
Build products live in the Hermes scratch directory, never the repository.
"""
from pathlib import Path
import os
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def linux(path):
    value = str(path.resolve()).replace('\\', '/')
    return '/mnt/' + value[0].lower() + value[2:] if len(value) > 1 and value[1] == ':' else value

with tempfile.TemporaryDirectory(prefix='expiry-core-', dir=os.environ['TMPDIR']) as tmp:
    build = Path(tmp)
    tests = sorted(HERE.glob('*Tests.swift'))
    methods = []
    for test in tests:
        methods.extend(re.findall(r'func (test\w+)\(', test.read_text()))
    (build / 'main.swift').write_text('import XCTest\n@testable import ExpiryCore\nXCTMain([testCase([\n' + ',\n'.join(f'("{name}", ExpiryCoreTests.{name})' for name in methods) + '\n])])\n')
    sources = sorted((ROOT / 'Sources' / 'ExpiryCore').glob('*.swift'))
    if not sources:
        print('RED: ExpiryCore source module does not exist yet', flush=True)
        raise SystemExit(1)
    def run(args, **kwargs):
        result = subprocess.run(['wsl.exe', 'bash', '-lc', 'export TMPDIR=' + shlex.quote(linux(build)) + '; ' + args], **kwargs)
        if result.returncode:
            raise SystemExit(result.returncode)
    import shlex
    q = shlex.quote
    b = q(linux(build))
    run('swiftc -swift-version 6 -warnings-as-errors -emit-library -emit-module -enable-testing -module-name ExpiryCore ' + ' '.join(q(linux(p)) for p in sources) + f' -emit-module-path {b}/ExpiryCore.swiftmodule -o {b}/libExpiryCore.so')
    run(f'swiftc -I {b} -L {b} -lExpiryCore ' + ' '.join(q(linux(p)) for p in tests) + f' {b}/main.swift -o {b}/tests')
    run(f'LD_LIBRARY_PATH={b} {b}/tests')
