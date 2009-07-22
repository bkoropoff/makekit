#!/usr/bin/env python
## 
##  metakit -- the extensible meta-build system
##  Copyright (C) Brian Koropoff
## 
##  This program is free software; you can redistribute it and/or
##  modify it under the terms of the GNU General Public License
##  as published by the Free Software Foundation; either version 2
##  of the License, or (at your option) any later version.
## 
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
## 
##  You should have received a copy of the GNU General Public License
##  along with this program; if not, write to the Free Software
##  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
##

import os
import sys
import re
import subprocess
import string

__all__ = [
    "Script",
    "Module",
    "Component",
    "Project",
    "Settings",
    "order_depends",
    "manifest_name",
    "function_name",
    ]

class Script:
    var_pat = re.compile(r"^([a-zA-Z0-9_]+)=(.*)$")
    func_pat = re.compile(r"^([a-zA-Z0-9_-]+) *\(\)")

    class Option:
        def __init__(self, name, arg, doc):
            self.name = name;
            self.arg = arg;
            self.doc = doc

    def __init__(self, name, filename):
        self.name = name
        self.filename = filename
        self.variables = {'NAME': name}
        self.functions = {}
        self.closure_set = None
        self.closure_order = None
        self.depends = None
        self.resolving = False;
        self.parse_file()
        self.parse_options()

    def __repr__(self):
        return '<' + self.name + '>'

    def __getitem__(self,key):
        return self.variables[key]

    def __iter__(self):
        return self.variables.iterkeys()

    def parse_file(self):
        var_names = []
        mode = "normal"
        with open(self.filename) as file:
            for line in file:
                if (mode == "normal"):
                    match = Script.var_pat.match(line)
                    if (match != None):
                        var_names.append(match.group(1))
                    match = Script.func_pat.match(line)
                    if (match != None):
                        body = ""
                        name = match.group(1)
                        mode = "func"
                elif (mode == "func"):
                    if (line == "{\n"):
                        continue
                    elif (line == "}\n"):
                        self.functions[name] = body
                        mode="normal"
                        continue
                    else:
                        body += line

        echos = ". '%s' && " % self.filename
        echos += ";".join(['echo "self.variables[\'%s\'] = r\\"\\"\\"${%s} \\"\\"\\""[0:-1]' % (x,x) for x in var_names])
        args = ['sh', '-c', echos]
        proc = subprocess.Popen(args, stdout=subprocess.PIPE)
        output = proc.stdout.read()
        proc.wait()
        code = compile(output, '<stdout>', 'exec')
        exec(code)

    def parse_options(self):
        if 'OPTIONS' in self.variables:
            self.options = {}

            mode = 'normal'
            for line in self['OPTIONS'].split('\n'):
                if mode == 'doc':
                    if len(line) and line[0] in string.whitespace:
                        docs += line.split()
                    else:
                        self.options[name] = Script.Option(name, arg, docs)
                        mode = 'normal'
                if mode == 'normal':
                    if not len(line):
                        continue
                    parts = line.split()
                    name = parts[0]
                    arg = parts[1]
                    docs = parts[2:]
                    if arg == '-':
                        arg = None
                    mode = 'doc'
        else:
            self.options = None

    def resolve_closure(self, others):
        if self.resolving:
            raise Exception('Dependency cycle detected')
        elif self.closure_set == None:
            self.resolving = True
            self.closure_order = []
            self.closure_set = set()
            self.depends = set()

            if 'DEPENDS' in self.variables:
                self.depends = set(others[x] for x in self['DEPENDS'].split(" "))
                for other in self.depends:
                    other.resolve_closure(others)
                    for item in other.closure_order:
                        if item not in self.closure_set:
                            self.closure_order.append(item)
                            self.closure_set.add(item)
            self.resolving = False

            self.closure_set.add(self);
            self.closure_order.append(self);

    def emit_manifest(self, out):
        prefix = "%s%s" % (self.manifest_prefix(), manifest_name(self.name))

        out.write("%s_FUNCS='%s'\n" % (prefix, " ".join(self.functions.keys())))

        for (name,value) in self.variables.iteritems():
            out.write("%s_%s='%s'\n" % (prefix, name, value))

class Module(Script):
    """Represents a module"""

    def manifest_prefix(self):
        return "MK_MODULE_"

    def emit_manifest(self, out):
        Script.emit_manifest(self, out)

        prefix = "%s%s" % (self.manifest_prefix(), manifest_name(self.name))

        closure = " ".join([x.name for x in self.closure_order])
        out.write("%s_CLOSURE='%s'\n" % (prefix, closure))

    def resolve_phases(self):
        self.phase_closure = set()
        
        for module in self.closure_order:
            if 'PHASES' in module.variables:
                self.phase_closure.update(module['PHASES'].split(" "))

    def resolve_components(self, components):
        self.component_order = []

        for component in order_depends(components):
            if self in component.module_set:
                self.component_order.append(component)

        self.variables['COMPONENTS'] = " ".join([x.name for x in self.component_order])

class Component(Script):
    """Represents a component"""
    def __init__(self, name, filename):
        Script.__init__(self, name, filename)
        self.module_set = None
        self.module_order = None

    def manifest_prefix(self):
        return "MK_COMPONENT_"

    def emit_manifest(self, out):
        Script.emit_manifest(self, out)

        prefix = "%s%s" % (self.manifest_prefix(), manifest_name(self.name))

        closure = " ".join([x.name for x in self.closure_order])
        out.write("%s_CLOSURE='%s'\n" % (prefix, closure))

        module_closure = " ".join([x.name for x in self.module_order])
        out.write("%s_MODULE_CLOSURE='%s'\n" % (prefix, module_closure))

    def resolve_modules(self, modules):
        self.module_set = set()
        self.module_order = []
        
        if 'MODULES' in self.variables:
            for name in self.variables['MODULES'].split(" "):
                module = modules[name]
                for item in module.closure_order:
                    if item not in self.module_set:
                        self.module_set.add(item)
                        self.module_order.append(item)

    def resolve_phases(self):
        self.phase_closure = set()
        
        for module in self.module_set:
            self.phase_closure.update(module.phase_closure)

class Project(Script):
    def manifest_prefix(self):
        return "MK_"

class Settings:
    mk_dir = os.path.abspath(os.environ['MK_HOME'])
    root_dir = os.path.abspath(os.getcwd())
    constants = Script("constants", os.path.join(mk_dir, 'shlib', 'constants.sh'))
    module_dirname = constants['MK_MODULE_DIRNAME']
    component_dirname = constants['MK_COMPONENT_DIRNAME']
    configure_filename = constants['MK_CONFIGURE_FILENAME']
    action_filename = constants['MK_ACTION_FILENAME']
    makefile_filename = constants['MK_MAKEFILE_FILENAME']
    manifest_filename = constants['MK_MANIFEST_FILENAME']
    project_filename = constants['MK_PROJECT_FILENAME']

def manifest_name(name):
    return name.upper().replace('-', '_')

def function_name(name):
    return name.lower().replace('-', '_')

def order_depends(scripts):
    seen = set([])
    order = []

    for script in scripts.itervalues():
        for item in script.closure_order:
            if not item in seen:
                seen.add(item);
                order.append(item);

    return order
