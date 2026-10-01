#!/usr/bin/env python3
"""Redirect a Geant4 example's physics list through the extensible factory.

Usage:
    replace_physics_list.py <example-main.cc> <physics-list-name>

Many Geant4 examples hardcode their physics list in the main program, e.g.

    auto physicsList = new FTFP_BERT;
    physicsList->RegisterPhysics(new G4StepLimiterPhysics());
    runManager->SetUserInitialization(physicsList);

or inline:

    runManager->SetUserInitialization(new PhysicsList);

so the physics list cannot be chosen at run time. This script rewrites the main .cc IN
PLACE so the object handed to G4(MT)RunManager::SetUserInitialization is instead built by
g4alt::G4PhysListFactory (the *extensible* factory, as used by the extensibleFactory example)
from <physics-list-name>. That accepts plain reference lists ("QGSP_BERT", "FTFP_BERT"),
EM-option variants ("FTFP_BERT_EMX") and the "+"/"_" extension syntax
("FTFP_BERT_EMX+G4OpticalPhysics"). This lets hardcoded examples take part in a physics-list
matrix dimension without hand-editing each one.

The transformation:
  * locates the SetUserInitialization(...) call whose argument names the physics list
    (its text contains "physicslist", case-insensitive);
  * if that argument is a plain variable (e.g. physicsList), comments out the other lines that
    build it (the `new <List>`, RegisterPhysics/ReplacePhysics calls, ...);
  * replaces the call with one that uses the factory-built list;
  * ensures #include "G4PhysListFactoryAlt.hh" is present.
"""
import re
import sys

FACTORY_INCLUDE = '#include "G4PhysListFactoryAlt.hh"'

# A SetUserInitialization call on a single line: indent, receiver (e.g. "runManager->"),
# argument, trailing ";".
CALL_RE = re.compile(r'^(\s*)(.*?)SetUserInitialization\s*\(\s*(.*?)\s*\)\s*;\s*$')


def patch(path, physics_list):
	with open(path) as fh:
		lines = fh.readlines()

	# Find the physics-list SetUserInitialization call (its argument mentions a physics list,
	# e.g. `physicsList` or `new PhysicsList`), as opposed to the detector/action ones.
	idx = indent = receiver = arg = None
	for i, line in enumerate(lines):
		if 'SetUserInitialization' in line and 'physicslist' in line.lower():
			m = CALL_RE.match(line)
			if m:
				idx, indent, receiver, arg = i, m.group(1), m.group(2), m.group(3)
				break
	if idx is None:
		sys.exit(f"ERROR: no physics-list SetUserInitialization(...) call found in {path}")

	# If the argument is a plain variable, comment out the lines that construct it; if it is an
	# inline `new SomePhysicsList`, there is nothing else to remove.
	var = arg if re.fullmatch(r'[A-Za-z_]\w*', arg) else None
	if var:
		var_re = re.compile(r'\b' + re.escape(var) + r'\b')
		for j, line in enumerate(lines):
			if j == idx or line.lstrip().startswith('//'):
				continue
			if var_re.search(line):
				lines[j] = re.sub(r'^(\s*)', r'\1// ', line)

	# Replace the call with the factory-built physics list.
	lines[idx] = (
		f'{indent}// physics list selected via the Geant4 extensible factory '
		f'(patched by replace_physics_list.py)\n'
		f'{indent}g4alt::G4PhysListFactory g4ciPhysListFactory;\n'
		f'{indent}{receiver}SetUserInitialization('
		f'g4ciPhysListFactory.GetReferencePhysList("{physics_list}"));\n'
	)

	# Make sure the extensible-factory header is included (once), after the last #include.
	if not any(FACTORY_INCLUDE in line for line in lines):
		includes = [i for i, line in enumerate(lines) if line.lstrip().startswith('#include')]
		if not includes:
			sys.exit(f"ERROR: no #include lines found in {path}")
		lines.insert(includes[-1] + 1, FACTORY_INCLUDE + '\n')

	with open(path, 'w') as fh:
		fh.writelines(lines)
	print(f"patched {path}: physics list -> {physics_list}")


def main(argv):
	if len(argv) != 3:
		sys.exit("usage: replace_physics_list.py <example-main.cc> <physics-list-name>")
	patch(argv[1], argv[2])


if __name__ == '__main__':
	main(sys.argv)
