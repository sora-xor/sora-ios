#!/usr/bin/env python3
"""Validate required recovery strings in all shipped iOS language variants."""
from pathlib import Path
from collections import Counter
import json,re,subprocess,hashlib,sys
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[2]
manifestPath=root/'docs/release-3.9.0/recovery-translations.json'
manifest=json.loads(manifestPath.read_text())
keys=manifest['keys']; assert keys and len(set(keys))==len(keys)
pbx=(root/'SoraPassport.xcodeproj/project.pbxproj').read_text()
block=re.search(r'5ED216A7294886A90052C740 /\* Localizable\.strings \*/ = \{(.*?)\n\s*\};',pbx,re.S).group(1)
locales=re.findall(r'/\* ([^*]+) \*/',block)
assert len(locales)==28 and len(set(locales))==28,locales
assert set(manifest['locales'])==set(locales)-{'en','ja'}
fmt=re.compile(r'%(?:\d+\$)?(?:[-+ #0]*)(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|h|ll|l|L|z|j|t)?(?:@|[diuoxXfFeEgGaAcCsSp])')
entry=re.compile(r'^\s*("(?:[^"\\]|\\.)*")\s*=',re.M)
result={'date':'2026-10-12','keyCount':len(keys),'shippedLocaleCount':len(locales),'requiredEntriesChecked':len(keys)*len(locales),'nativeReview':'pending for all 26 newly translated locales; structural validation is not native review','locales':{},'failures':[]}
for locale in locales:
 p=root/'SoraPassport/SoraLocalizable'/f'{locale}.lproj/Localizable.strings'
 raw=p.read_text()
 syntax=subprocess.run(['plutil','-lint',str(p)],capture_output=True,text=True)
 if syntax.returncode:result['failures'].append([locale,'syntax',syntax.stdout,syntax.stderr]);continue
 values=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(p)]))
 counts=Counter(json.loads(m) for m in entry.findall(raw))
 missing=[k for k in keys if k not in values]
 duplicates=[k for k in keys if counts[k]!=1]
 mismatch=[k for k in keys if k in values and Counter(fmt.findall(k))!=Counter(fmt.findall(values[k]))]
 empty=[k for k in keys if not values.get(k,'').strip()]
 english=[k for k in keys if locale!='en' and values.get(k)==k and k not in {'PIN','Google Drive','OK'}]
 for kind,items in [('missing',missing),('duplicateOrUnreadableSourceKey',duplicates),('placeholderMismatch',mismatch),('empty',empty),('untranslatedEnglish',english)]:
  if items:result['failures'].append([locale,kind,items])
 result['locales'][locale]={'coverage':len(keys)-len(missing),'syntax':'passed','requiredKeyDuplicates':duplicates,'placeholderMismatches':mismatch,'untranslatedEnglish':english,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
result['passed']=not result['failures']
out=root/'docs/release-3.9.0/recovery-translations-validation.json'
out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='locales'},ensure_ascii=False,indent=2))
raise SystemExit(0 if result['passed'] else 1)
