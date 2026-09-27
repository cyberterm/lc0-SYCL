#!/usr/bin/env python3

import os

dir = os.getenv('MESON_BUILD_ROOT')

with open(dir + '/build.ninja', 'r') as file:
  lines = file.readlines()

updated = []
dep_flag = False
link_flag = False

for line in lines:
  # Check if entering a compiler or linker rule/target
  if line.startswith('rule') or line.startswith('build'):
    dep_flag = 'cpp_COMPILER' in line
    link_flag = 'rule cpp_LINKER' in line

  # In linker rules, replace xilink/link with icx and strip MSVC-specific flags
  if link_flag or 'xilink.exe' in line:
    line = line.replace('xilink.exe', 'icx')
    line = line.replace('"xilink.exe"', '"icx"')
    line = line.replace('"link"', '"icx"')
    line = line.replace('command = link ', 'command = icx ')
    line = line.replace('command = "link.exe"', 'command = "icx"')
    line = line.replace('/MACHINE:x64', '')
    line = line.replace('/OUT:', '-o ')
    line = line.replace('/SUBSYSTEM:CONSOLE', '')
    line = line.replace('/OPT:REF', '')
    line = line.replace('/PDB:', '/Fd')
    line = line.replace('"/LTCG"', '').replace('/LTCG', '')
    line = line.replace('"/release"', '').replace('/release', '')

  # Strip MSVC flags from target LINK_ARGS
  if line.strip().startswith('LINK_ARGS ='):
    line = line.replace('"/LTCG"', '').replace('/LTCG', '')
    line = line.replace('"/release"', '').replace('/release', '')
    line = line.replace('/OPT:REF', '')
    line = line.replace('/SUBSYSTEM:CONSOLE', '')
    line = line.replace('/MACHINE:x64', '')

  # Replace msvc compatible dependencies with gcc ones as icx output with /showincludes includes
  # temporary header files causing full project rebuilds.
  if dep_flag:
    line = line.replace('deps = msvc', 'deps = gcc\n depfile = $out.d')
    line = line.replace('/showIncludes', '/QMD')
    if 'icx' in line:
      line = line.replace('/Fo$out', '/Fo$out /QMF$out.d')
  updated.append(line)

with open(dir + '/build.ninja', 'w') as file:
  file.writelines(updated)
