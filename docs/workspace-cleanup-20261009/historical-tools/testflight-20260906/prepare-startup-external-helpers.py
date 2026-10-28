#!/usr/bin/env python3
"""Bind retained external-upload verifiers to the actual new publication commit."""
import ast, pathlib, subprocess, sys
root=pathlib.Path(__file__).resolve().parent
source=root/'publish-2026090801-ios'
pub=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()
runtime=subprocess.check_output(['git','rev-parse','HEAD^'],cwd=source,text=True).strip()
assert not subprocess.check_output(['git','status','--porcelain'],cwd=source)
assert subprocess.check_output(['git','rev-parse','@{upstream}'],cwd=source,text=True).strip()==pub
out=root/'external-publication-2026090801'
assert not out.exists()
replacements={'a64ec3253665579b641cde4ad68e9b614585568f':pub,'c86ba01d129fb0747ec3a730b1b366f0fef1920f':runtime,'2026090706':'2026090801','verified0706':'verified0801','completed0705':'completed0801','completed 0705':'completed 0801'}
rendered={}
for name in ['verify-external-package.py','retain-external-upload.py']:
    text=(root/'external-publication-2026090706'/name).read_text()
    for old,new in replacements.items(): text=text.replace(old,new)
    ast.parse(text)
    rendered[name]=text
out.mkdir(mode=0o700)
for name,text in rendered.items(): (out/name).write_text(text)
print('Prepared external package verifiers for publication '+pub+' and runtime '+runtime)
