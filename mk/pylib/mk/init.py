from mk.core import *
import os
import re

__all__ = ['main']

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

def load_project():
    return Project(
        Settings.project_filename,
        os.path.join(Settings.root_dir, Settings.project_filename))

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

def calc_used_modules(modules, components):
    used = {}
    
    for component in components.itervalues():
        for module in component.module_set:
            used[module.name] = module

    for module in modules.itervalues():
        if 'STANDARD' in module.variables:
            for dep in module.closure_set:
                used[dep.name] = dep

    return used
        

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
    
    template = [[(var, val) for val in re.split(r"\s+", component[var]) if val != ''] for var in varnames if var in component.variables]

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
        with open(os.path.join(Settings.mk_dir, 'shlib', relative)) as source:
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
        with open(os.path.join(Settings.mk_dir, 'shlib', relative)) as source:
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

    def mk_generate_output_body():
        for script in order_depends(modules) + order_depends(components):
            if 'output' in script.functions:
                dest.write('mk_log_enter "%s"\n' % (script.name))
                dest.write(script.functions['output'])
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
        'mk_generate_configure_body' : mk_generate_configure_body,
        'mk_generate_output_body' : mk_generate_output_body
        }

    process_template(source, dest, callbacks)

def init():
    args = ['sh', os.path.join(Settings.mk_dir, 'shlib', 'init.sh'), Settings.root_dir]
    proc = subprocess.Popen(args)
    proc.wait()

def main():
    modules = load_modules()
    components = load_components(modules)
    project = load_project()
    used_modules = calc_used_modules(modules, components)

    with open(Settings.manifest_filename, "w") as dest:
        emit_manifest(project, modules, components, dest)

    with open(os.path.join(Settings.mk_dir, 'template', 'makefile')) as source:
        with open(Settings.makefile_filename + '.in', "w") as dest:
            emit_makefile_in(source, dest, used_modules, components)

    with open(os.path.join(Settings.mk_dir, 'template', 'action.sh')) as source:
        with open(Settings.action_filename + '.in', "w") as dest:
            emit_action_in(source, dest, used_modules, components)

    with open(os.path.join(Settings.mk_dir, 'template', 'configure.sh')) as source:
        with open(Settings.configure_filename, "w") as dest:
            emit_configure(source, dest, used_modules, components)

    os.chmod(Settings.configure_filename, 0755)

if __name__ == "__main__":  
    main()
