#!/usr/bin/env python3
"""Read fixed vectors in each original historical implementation. No new vectors."""
import json
from pathlib import Path
import subprocess
p = Path(__file__).resolve().parent
r = p / 'runtime/cross-family'
r.mkdir(parents=True, exist_ok=True)
fixtures = sorted(p.glob('ios-*-vectors.json'))
fixtures = [x for x in fixtures if x.name != 'ios-1x-vectors.json']
all_results = []
for kind, command_file, generator_name, parser in [
    ('fearless', 'build-fearless-commands.json', 'generate_fearless.swift', 'hexString'),
    ('ssf-pod', 'build-ssf-pod-commands.json', 'generate_ssf_pod.swift', 'hexStringSSF'),
    ('spm', 'build-386-commands.json', 'generate_386.swift', 'hexStringSSF')]:
    commands = json.loads((p / command_file).read_text())
    for command in commands:
        if not any(Path(x).name == generator_name for x in command): continue
        if command[0] != 'xcrun': continue
        destination = Path(command[command.index('-o') + 1])
        name = kind + '-' + destination.parent.name
        generated = r / (name + '.swift')
        source = (p / generator_name).read_text().split('let cases:')[0]
        source += '\nfunc parseHex(_ text: String) throws -> Data { try Data(' + parser + ': text) }\n'
        source += (p / 'cross_verify_tail.swift').read_text()
        generated.write_text(source)
        for index, part in enumerate(command):
            if Path(part).name == generator_name: command[index] = str(generated)
        command[command.index('-o') + 1] = str(r / name)
        result = subprocess.run(command, capture_output=True, text=True, errors='replace')
        (r / (name + '.log')).write_text(result.stdout + result.stderr)
        if result.returncode: print(result.stderr[-6000:]); raise SystemExit(result.returncode)
        output = r / (name + '.json')
        result = subprocess.run([str(r / name), str(output), *map(str, fixtures)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, errors='replace')
        if result.returncode: print(result.stderr[-6000:]); raise SystemExit(result.returncode)
        all_results.append({'implementation': name, **json.loads(output.read_text())})
        print(name + ': all ' + str(len(fixtures) * 20) + ' fixed exports/signatures passed', flush=True)
(p / 'cross-family-verification.json').write_text(json.dumps({'historicalImplementations': all_results}, indent=2) + '\n')
