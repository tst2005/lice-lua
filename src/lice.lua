-- =========================================
-- Lice-Lua, A license generator for Lua
-- Copyright (c) 2013 Roland Y., MIT License
-- version 0.0.3 - Uses Lua >= 5.x
-- =========================================

-- =========================================
-- Internals declaration
-- =========================================

-- Catch the passed in root path (handling calls out from the root folder)
local ROOT_PATH = arg[0]:match('(.+)[//\].+$')

-- Check for dependencies
local lfs
do
  assert(pcall(require, 'lfs'),
    'Dependency LuaFileSystem not found.\nCannot execute Lice-Lua')
  lfs = require 'lfs'
end

-- Local binding to global native variables
local package = package
local os_getenv = os.getenv
local io_open = io.open
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local table_concat = table.concat
local assert = assert
local print = print

-- Pattern-matching templates
local TPL_FOLDER           = ('%stemplates/templates'):format(ROOT_PATH and (ROOT_PATH ..'/') or '')
local TPL_VARS_PATTERN     = '{{%s([^{}]+)%s}}'
local TPL_NAME_PATTERN     = '^([a-z0-9%_]+[%-header]*)%.txt$'
local TPL_TO_FNAME_PATTERN = '%s.txt'
local GET_OPT_PATTERN      = '(%-%-?)(%a+)%s*([^%-]*)'
local GET_OPT_LIC_PATTERN  = '^([a-z0-9%_]+)'

-- Default License template
local DEFAULT_LIC_TEMPLATE     = 'bsd3'

-- =========================================
-- Os's facilities
-- =========================================

-- Get directory separator
local function get_dir_sep()
  return (package.config:sub(1,1))
end

-- Is the actual Windows
local function is_windows()
  return (get_dir_sep():match('\\')~=nil)
end

-- Returns the username. Supports Windows and Unix'es as-is.
local function get_username()
  if is_windows() then
    return os_getenv('USERNAME')
  end
  return os_getenv('USER')
end

-- Returns the current folder name.
-- Uses Os's directory separator
local function get_current_folder_name()
  return lfs.currentdir():match(('([^%s]+)$'):format(get_dir_sep()))
end

-- =========================================
-- Internal functions helper
-- =========================================

-- Upvalue  declaration, to visible from the helpers
local templates_list

-- Collects and returns an array of keys from a given table
local function collect_keys(list, sorted)
  local l = {}
  for v in pairs(list) do l[#l+1] = v end
  if sorted then
    table_sort(l)
  end
  return l
end

-- Returns the contents of a file
local function get_file_contents(file_path)
  local fhandle = assert(io_open(file_path, 'r'),
    ('Error on attempt to open <%s>'):format(file_path))
  local contents = fhandle:read('*a')
  fhandle:close()
  return contents
end

-- Writes contents to file
local function write_to_file(f, contents, clear)
  if not clear then
    local previous_contents = get_file_contents(f)
    contents = previous_contents .. contents
  end
  local fhandle = assert(io_open(f, 'w+'),
    ('Cannot open file <%s>'):format(f))
  fhandle:write(contents)
  fhandle:close()
end

-- Extracts license name from file name. "-header"'s have to be supplied.
local function get_template_name(fname)
  return fname:match(TPL_NAME_PATTERN)
end

-- License name to file template name.
local function get_template_fname(name)
  return (TPL_TO_FNAME_PATTERN):format(name)
end

-- Builds the path to license file name.
-- Returned path is relative to the source folder.
local function get_template_fpath(name)
  return ('%s/%s'):format(TPL_FOLDER, get_template_fname(name))
end

-- Returns a list of available templates
-- Template names are stored as keys
local function get_templates_list(path)
  local l = {}
  for fname in lfs.dir(path) do
    if fname~='.' and fname~= '..' then
      local template_name = get_template_name(fname)    
      if template_name then
        l[template_name] = true
      end
    end
  end
  return l
end

-- Returns a list of available templates
-- Template names are stored as keys
local function get_template_vars(template_name)
  local template_file_path = get_template_fpath(template_name)
  local contents = get_file_contents(template_file_path)
  local vars = {}
  for var in contents:gmatch(TPL_VARS_PATTERN) do
    vars[#vars+1] = var
  end
  return vars
end

-- Interpolates template variables with the provided set of options
local function write_license(opts)
  local template_file_path = get_template_fpath(opts.fname)
  local source = get_file_contents(template_file_path)
  local license_text = (source:gsub(TPL_VARS_PATTERN,opts))
  if opts.out then
    local license_file = opts.out ..
      (opts.file_ext and ('.' .. opts.file_ext) or '')
    -- Does the output file already exists ?
    local is_item = lfs.attributes(license_file)
    local is_file = is_item and is_item.mode == 'file' or false
    -- Should we clear its contents  
    local clear_contents = true
    if (opts.no_clear and is_file) then
      clear_contents = false
    end
    write_to_file(license_file, license_text, clear_contents)
  else
    print(license_text)
  end
end

-- =============================================
-- Very minimal (and ugly) GetOpt implementation
-- =============================================

-- Checker for input opt
local function check_opt_style(dash, opt)
  assert(not dash:match('[^%-]'), 'Input is not valid')
  assert(dash:match('^%-%-?$'), 'Input is not valid')
  if dash == '-' then
    assert(opt:len() == 1,
      ('The following was probably mistyped : <%s>'):format(dash..opt))
  elseif dash == '--' then
    assert(opt:len() > 1,
      ('The following was probably mistyped : <%s>'):format(dash..opt))
  end
end

-- Processes input opt
local function process_opt(cfg, template, opt, value)
  if (opt == 'help' or opt == 'h') then
    print([[usage: licelua license [-h] [-o ORGANIZATION] [-p PROJECT]
                       [-t TEMPLATE_PATH] [-y YEAR]
                       [--vars] [--header]

    positional arguments:
      license                   the license to generate. Defaults to bsd3 
                                when not given.
                                
    optional arguments:
      -h, --help                show this help message and exit
      -o, --org ORGANIZATION    organization, defaults environment variable
                                "USERNAME" (on Windows) or "USER" (on Unix'es)
      -p, --proj PROJECT        name of project, defaults to name of current 
                                directory
      -y, --year YEAR           copyright year
      -f, --file OFILEPATH      path to the output source file
      
    optional arguments taking no values (no args)
      --vars                    when supplied, list template variables for 
                                specified license and exit
      --header                  when supplied, will only use the header license
                                if available
      --list                    when supplied, list the available licenses 
                                templates and exit
      --noclear                 when output file is specified and already exists, 
                                forces its previous contents to be erased and updates
                                it with the actual license]]
    )
    os.exit()
  elseif opt == 'vars' then
    local vars = get_template_vars(template)
    print(('License <%s> vars:'):format(template))
    for _, var in ipairs(vars) do
      print('  >> ' .. var)
    end
    os.exit()
  elseif (opt == 'list' or opt == 'l') then
    local sort_list = true
    local list = collect_keys(templates_list, sort_list)
    print(('Available licenses templates:'):format(template))    
    for _,template in pairs(list) do
      print('  >> ' .. template)
    end
    os.exit()
  elseif (opt == 'org' or opt == 'o') then
    cfg.organization = value
  elseif (opt == 'proj' or opt == 'p') then
    cfg.project = value
  elseif (opt == 'year' or opt == 'y') then
    local year = value:gsub('%s$','')
    assert(year:match('^[%d]+[%D+]*[%d+]*$'),
      ('Wrong year: <%s>'):format(value))
    cfg.year = (year:gsub('[^%d]+','-'))
  elseif (opt == 'file' or opt == 'f') then
    cfg.out = cfg.out or value
  end
end

-- Main routine, catch and process args
local function main(_args)
  local template = _args:match(GET_OPT_LIC_PATTERN) or DEFAULT_LIC_TEMPLATE

  -- Handle headers template name auto-completion
  if _args:match('%-%-header') and not template:match('%-header$') then
    template = template .. '-header'
  end
  
  -- Forces the output file not to be updated
  local no_clear = _args:match('%-%-noclear') and true or false
  
  -- Asserts the required license is available
  assert(templates_list[template],
    ('License <%s> is not available'):format(template))

  -- Default config
  local cfg = {
    fname = template,                          -- The template
    organization = get_username(),             -- Defaults to USERNAME or USER
    project = get_current_folder_name(),       -- Defaults to current directory
    year = os.date('%Y'),                      -- Defaults to current year
    no_clear = no_clear
  }
  
  -- Catch, check and resolve options
  for dash, _opt, value in _args:gmatch(GET_OPT_PATTERN) do
    local opt = _opt:lower()
    check_opt_style(dash, opt)
    process_opt(cfg, template, opt, value)
  end

  -- Write license to output
  write_license(cfg)
end

-- Creates the list of templates
do
  templates_list = get_templates_list(TPL_FOLDER)
end

-- Calls main and process input
main(table_concat(arg,' '))