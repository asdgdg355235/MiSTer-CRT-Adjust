#!/usr/bin/env python3
"""Check inferred Cabinet RAM shape; this is not a Quartus fit report."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

for mlab_parts in (0, 1):
  with tempfile.TemporaryDirectory(prefix='crt-storage-') as tmp:
    out = Path(tmp)/'storage.json'
    commands = (f'read_verilog -sv "{ROOT / "rtl/crt_vsize_fixed.sv"}"; '
                f'chparam -set MLAB_PARTS {mlab_parts} crt_vsize_fixed; '
                'hierarchy -top crt_vsize_fixed; proc; opt; memory_dff; '
                f'memory_collect; write_json "{out}"')
    subprocess.run(['yosys', '-Q', '-q', '-p', commands], check=True)
    cells = json.loads(out.read_text())['modules']['crt_vsize_fixed']['cells']
    memories = [c for name, c in cells.items()
              if c['type'] == '$mem_v2' and ('even_mem' in name or 'odd_mem' in name)]
    stores = [c['parameters'] for c in memories]
    assert len(stores) == 6, 'RGB RAM replicated or missing'
    assert all(int(p['WIDTH'], 2) == 40 and int(p['SIZE'], 2) == 3072
               and int(p['RD_PORTS'], 2) == 1 and int(p['WR_PORTS'], 2) == 1
               and int(p['RD_CLK_ENABLE'], 2) == 1 for p in stores), stores
    bits = sum(int(p['WIDTH'], 2)*int(p['SIZE'], 2) for p in stores)
    assert bits == 737280, bits
    mlab = [c for c in memories if c['attributes']['ramstyle'].startswith('MLAB')]
    assert len(mlab) == 2*mlab_parts, mlab
    print(f'PASS: six 3072 x 40 synchronous RGB RAMs, {bits} bits; '
          f'{(6-len(mlab))*12} M10Ks + {len(mlab)*192} MLABs by geometry, '
          'pending Quartus fitting')
