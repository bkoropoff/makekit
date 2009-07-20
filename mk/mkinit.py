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

def manifest_name(name):
    return name.upper().replace('-', '_')

def function_name(name):
    return name.lower().replace('-', '_')

class ShellScript:
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
        self.variables = {'COMPONENT': name}
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
                    match = ShellScript.var_pat.match(line)
                    if (match != None):
                        var_names.append(match.group(1))
                    match = ShellScript.func_pat.match(line)
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
                        self.options[name] = ShellScript.Option(name, arg, docs)
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

class Module(ShellScript):
    """Represents a module"""

    def manifest_prefix(self):
        return "MK_MODULE_"

    def emit_manifest(self, out):
        ShellScript.emit_manifest(self, out)

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

class Component(ShellScript):
    """Represents a component"""
    def __init__(self, name, filename):
        ShellScript.__init__(self, name, filename)
        self.module_set = None
        self.module_order = None

    def manifest_prefix(self):
        return "MK_COMPONENT_"

    def emit_manifest(self, out):
        ShellScript.emit_manifest(self, out)

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

class ManifestIn(ShellScript):
    def manifest_prefix(self):
        return ""

class Settings:
    mk_dir = os.path.abspath(os.environ['MK_HOME'])
    root_dir = os.path.abspath(os.getcwd())
    constants = ShellScript("constants", os.path.join(mk_dir, 'lib', 'constants.sh'))
    module_dirname = constants['MK_MODULE_DIRNAME']
    component_dirname = constants['MK_COMPONENT_DIRNAME']
    configure_filename = constants['MK_CONFIGURE_FILENAME']
    action_filename = constants['MK_ACTION_FILENAME']
    makefile_filename = constants['MK_MAKEFILE_FILENAME']
    manifest_filename = constants['MK_MANIFEST_FILENAME']

def load_modules():
    modules = {}    
    mk_module_dir = os.path.join(Settings.mk_dir, Settings.module_dirname)
    proj_module_dir = os.path.join(Settings.root_dir, Settings.module_dirname)

    for dir in [proj_module_dir, mk_module_dir]:
        for f in os.listdir(dir):
            if (not (f in modules)):
                path = os.path.join(dir, f)
                if os.path.isfile(path):
                    modules[f] = Module(f, path)

    for (name,module) in modules.iteritems():
        module.resolve_closure(modules)
        module.resolve_phases()

    return modules

def load_manifest_in():
    return ManifestIn(
        Settings.manifest_filename,
        os.path.join(Settings.root_dir, Settings.manifest_filename + ".in"))

def load_components(modules):
    components = {}

    proj_component_dir = os.path.join(Settings.root_dir, Settings.component_dirname)

    for dir in [proj_component_dir]:
        for f in os.listdir(dir):
            if (not (f in components)):
                path = os.path.join(dir, f)
                if os.path.isfile(path):
                    components[f] = Component(f, path)

    for (name,component) in components.iteritems():
        component.resolve_closure(components)
        component.resolve_modules(modules)
        component.resolve_phases()

    for module in modules.itervalues():
        module.resolve_components(components)

    return components

def order_depends(scripts):
    seen = set([])
    order = []

    for script in scripts.itervalues():
        for item in script.closure_order:
            if not item in seen:
                seen.add(item);
                order.append(item);

    return order

def emit_manifest(manifest, modules, components, out):
    manifest.emit_manifest(out)

    phases = set()

    for module in modules.itervalues():
        if 'PHASES' in module.variables:
            for phase in module['PHASES'].split(" "):
                phases.add(phase)

    out.write("MK_MODULE_INVENTORY='" + " ".join([x.name for x in order_depends(modules)]) + "'\n")
    out.write("MK_COMPONENT_INVENTORY='" + " ".join([x.name for x in order_depends(components)]) + "'\n")
    out.write("MK_PHASE_INVENTORY='" + " ".join(phases) + "'\n")

    for module in modules.itervalues():
        module.emit_manifest(out)

    for component in components.itervalues():
        component.emit_manifest(out)

def process_template(source, dest, callbacks):
    for line in source:
        pieces = re.split(r'(@[^@]*@)', line)
        for piece in pieces:
            if piece and piece[0] == '@':
                args = piece.strip()[1:-1].split(' ')
                apply(callbacks[args[0]], args[1:])
            else:
                dest.write(piece)

def cart(l):
    return l == [] and [[]] or [[x] + y for x in l[0] for y in cart(l[1:])]

def assign_vars(rule, table):
    for (var, val) in table:
        rule = rule.replace('%{' + var + '}', val)
    return rule

def expand_targets(component, rule):
    varnames = [x[2:-1] for x in re.findall(r'%{[^}]*}', rule)]
    
    template = [[(var, val) for val in component[var].split(' ')] for var in varnames if var in component.variables]
    
    return [x for x in [assign_vars(rule, table) for table in cart(template)] if not '%' in x]

def emit_makefile_in(source, dest, all_modules, components):
    def mk_generate_makefile_rules():
        target_dirname = 'target'

        phony = set()

        # Write rules for all phases of each component
        for component in components.itervalues():
            modules = component.module_set
            phases = component.phase_closure
            depends = component.depends

            for phase in phases:
                rule = None
                for module in modules:
                    if 'PHASE_' + manifest_name(phase) in module.variables:
                        rule = module['PHASE_' + manifest_name(phase)]
                        break
                
                if rule == None:
                    raise Exception('No rule found for phase ' + phase)

                pieces = rule.split(':')

                rtype = deps = args = None
                if len(pieces) > 0:
                    rtype = pieces[0].strip()
                if len(pieces) > 1:
                    deps = pieces[1].strip()
                if len(pieces) > 2:
                    args = pieces[2].strip()

                if deps:
                    targets = expand_targets(component, deps)
                else:
                    targets = []

                short_target = '%s-%s' % (phase, component.name)
                long_target = '%s/%s' % (target_dirname, short_target)

                dest.write('%s: %s\n\n' % (short_target, long_target))
                phony.add(short_target)

                dest.write('%s/%s-%s: %s\n' % (
                        target_dirname,
                        phase,
                        component.name,
                        " ".join(["%s/%s" % (target_dirname, x) for x in targets])))                   
                dest.write('\t@$(MK_ACTION) MAKE="$(MAKE)" ' + phase + ' ' + component.name)

                if (args):
                    dest.write(' ' + args)
                dest.write("\n")

                if rtype == 'once':
                    dest.write('\t@touch $@\n')
                else:
                    phony.add(long_target)
                    
                dest.write("\n")

        virtual_deps = {}

        for module in all_modules.itervalues():
            if 'VIRTUALS' in module.variables:
                virtuals = module['VIRTUALS'].split()
                
                for virtual in virtuals:
                    deps = module['VIRTUAL_' + manifest_name(virtual)]
                    targets = expand_targets(module, deps)
                    if virtual in virtual_deps:
                        for target in targets:
                            if target not in virtual_deps[virtual]:
                                virtual_deps[virtual].append(target)
                    else:
                        virtual_deps[virtual] = targets

        for virtual in virtual_deps:
            dest.write("%s: %s\n\n" % (virtual, " ".join(virtual_deps[virtual])))
            phony.add(virtual)

        dest.write(".PHONY: %s\n\n" % " ".join(phony))

    callbacks = {'mk_generate_makefile_rules': mk_generate_makefile_rules}

    process_template(source, dest, callbacks)
    
def emit_action_in(source, dest, modules, components):
    def mk_include(relative):
        with open(os.path.join(Settings.mk_dir, relative)) as source:
            dest.write(source.read())
            dest.write('\n')

    def mk_generate_action_rules():
        basic_funcs = ['load']

        # Emit pre/post phase actions from all modules
        for module in modules.itervalues():
            funcs = basic_funcs

            for phase in module.phase_closure:
                for step in ['pre', 'post']:
                    funcs.append('%s_%s' % (step, phase))

            for func in funcs:
                if func in module.functions:
                    dest.write('\n')
                    dest.write('%s_%s()\n' % (function_name(module.name), func))
                    dest.write('{\n')
                    dest.write('    mk_log_enter "%s"\n' % (module.name))
                    dest.write(module.functions[func])
                    dest.write('    mk_log_leave\n')
                    dest.write('}\n')
        
        # Emit phase actions from all components

        for component in components.itervalues():
            for phase in component.phase_closure:
                extract_script = None
                extract_func = None

                if phase in component.functions:
                    extract_script = component
                    extract_func = phase
                else:
                    for module in reversed(component.module_order):
                        if 'default_' + phase in module.functions:
                            extract_script = module
                            extract_func = 'default_' + phase
                            break

                if extract_script:
                    dest.write('\n')
                    dest.write('%s_%s()\n' % (function_name(component.name), phase))
                    dest.write('{\n')
                    dest.write('    MK_COMP_DEPENDS="%s"\n' % (
                            ' '.join([x.name for x in component.closure_order if x != component])))

                    for module in component.module_order:
                        if 'load' in module.functions:
                            dest.write('    %s_load\n' % (function_name(module.name)))
                    dest.write('    mk_log_enter "%s-%s"\n' % (phase, component.name))
                    for module in component.module_order:
                        if 'pre_' + phase in module.functions:
                            dest.write('    %s_pre_%s\n' % (function_name(module.name), phase))
                    dest.write(extract_script.functions[extract_func])
                    for module in reversed(component.module_order):
                        if 'post_' + phase in module.functions:
                            dest.write('    %s_post_%s\n' % (function_name(module.name), phase))
                    dest.write('    mk_log_leave\n')
                    dest.write('}\n')

    callbacks = {'mk_include': mk_include, 'mk_generate_action_rules' : mk_generate_action_rules}

    process_template(source, dest, callbacks)

def emit_configure(source, dest, modules, components):
    def mk_include(relative):
        with open(os.path.join(Settings.mk_dir, relative)) as source:
            dest.write(source.read())
            dest.write('\n')

    def mk_generate_configure_parse():
        for script in modules.values() + components.values():
            if script.options:
                for option in script.options.itervalues():
                    varname = 'MK_' + manifest_name(option.name)
                    if option.arg:
                        dest.write('        --%s=*)\n' % (option.name))
                        dest.write('            __val="`echo "${_param}" | cut -d= -f2`"\n')
                        dest.write('            %s="${__val}"\n' % (varname))
                        dest.write('            ;;\n')
                    else:
                        dest.write('        --%s)\n' % (option.name))
                        dest.write('            %s=true\n' % (varname))
                        dest.write('            ;;\n')

    def mk_generate_configure_body():
        dest.write('mk_log "Loading modules"\n')
        for module in order_depends(modules):
            if 'load' in module.functions:
                dest.write('mk_log_enter "%s"\n' % (module.name))
                dest.write(module.functions['load'])
                dest.write('mk_log_leave\n')

        dest.write('mk_log "Configuring modules"\n')
        for module in order_depends(modules):
            if 'configure' in module.functions:
                dest.write('mk_log_enter "%s"\n' % (module.name))
                dest.write(module.functions['configure'])
                dest.write('mk_log_leave\n')

        dest.write('mk_log "Configuring components"\n')
        for component in order_depends(components):
            if 'configure' in component.functions:
                dest.write('mk_log_enter "%s"\n' % (component.name))
                dest.write(component.functions['configure'])
                dest.write('mk_log_leave\n')

    def mk_generate_configure_help():
        dest.write('    cat <<EOF\n')
        dest.write('Usage: %s [ options ...]\n' % (Settings.constants['MK_CONFIGURE_FILENAME']))
        dest.write('\n')
        dest.write('Options:\n')
        dest.write('  --help                               Display this help message\n')

        for script in modules.values() + components.values():
            if script.options:
                align = 40
                wrap = 80
                offset = 0
                for option in script.options.itervalues():
                    if option.arg == None:
                        text = '  --%s' % (option.name)
                    else:
                        text = '  --%s=%s' % (option.name, option.arg)
                    dest.write(text)
                    offset += len(text)
                    for x in range(1, (align - offset) - 1):
                        offset += 1
                        dest.write(' ')

                    for word in option.doc:
                        if offset + len(word) >= wrap:
                            dest.write('\n');
                            offset = 0
                        if offset < align:
                            for x in range(1, (align - offset) - 1):
                                offset += 1
                                dest.write(' ')
                        dest.write(' ' + word)
                        offset += 1 + len(word)

                    dest.write('\n')
                    offset = 0
        dest.write('EOF\n')
    
    callbacks = {
        'mk_include': mk_include,
        'mk_generate_configure_help' : mk_generate_configure_help,
        'mk_generate_configure_parse' : mk_generate_configure_parse,
        'mk_generate_configure_body' : mk_generate_configure_body
        }

    process_template(source, dest, callbacks)

def init():
    args = ['sh', os.path.join(Settings.mk_dir, 'lib', 'init.sh'), Settings.root_dir]
    proc = subprocess.Popen(args)
    proc.wait()

def main():
    modules = load_modules()
    components = load_components(modules)
    manifest_in = load_manifest_in()

    with open(Settings.manifest_filename, "w") as dest:
        emit_manifest(manifest_in, modules, components, dest)

    with open(os.path.join(Settings.mk_dir, 'template', 'makefile')) as source:
        with open(Settings.makefile_filename + '.in', "w") as dest:
            emit_makefile_in(source, dest, modules, components)

    with open(os.path.join(Settings.mk_dir, 'template', 'action.sh')) as source:
        with open(Settings.action_filename + '.in', "w") as dest:
            emit_action_in(source, dest, modules, components)

    with open(os.path.join(Settings.mk_dir, 'template', 'configure.sh')) as source:
        with open(Settings.configure_filename, "w") as dest:
            emit_configure(source, dest, modules, components)

#    init()

if __name__ == "__main__":
   
    main()

