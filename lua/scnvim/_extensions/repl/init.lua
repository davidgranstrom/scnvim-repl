local sclang = require 'scnvim.sclang'
local postwin = require 'scnvim.postwin'
local udp = require 'scnvim.udp'
local path = require 'scnvim.path'
local repl = {}

-- TODO:
-- Use uv.spawn instead of system when interacting with the dispatcher.
-- Set current path when starting sclang (need to wait until process is started)

repl.is_running = false

function repl.get_sclang_pipe_app()
  local root_dir = path.get_plugin_root_dir('repl')
  return path.concat(root_dir, 'ruby', 'start_pipe')
end

function repl.get_sclang_dispatcher()
  if repl.dispatcher then
    return repl.dispatcher
  end
  local root_dir = path.get_plugin_root_dir('repl')
  repl.dispatcher = path.concat(root_dir, 'ruby', 'sc_dispatcher')
  return repl.dispatcher
end

function repl.get_term_cmd()
  if repl.term_cmd then
    return repl.term_cmd
  end
  local system_name = path.get_system()
  local term_cmd
  if system_name == 'macos' then
    term_cmd = {'open', '-a', 'Terminal.app'}
  elseif system_name == 'linux' then
    term_cmd = {'x-terminal-emulator', '-e', '$SHELL', '-ic'}
  else
    return error('Not supported on this system')
  end
  return term_cmd
end


sclang.on_init = nil
sclang.on_exit = nil
sclang.on_output = nil
postwin.open = function() end
postwin.close = function() end
postwin.toggle = function() end

local function format(text)
  text = vim.fn.substitute(text, '\\', '\\\\', 'g')
  text = vim.fn.substitute(text, '"', '\\\\"', 'g')
  text = vim.fn.substitute(text, '`', '\\\\`', 'g')
  text = vim.fn.substitute(text, '\\$', '\\\\$', 'g')
  text = '"' .. text .. '"'
  return text
end

sclang.send = function(data, silent)
  silent = silent or false
  local cmd = not silent and ' -i ' or ' -s '
  if repl.is_running then
    local dispatcher = repl.get_sclang_dispatcher()
    vim.fn.system(dispatcher .. cmd .. format(data))
  end
end

sclang.start = function()
  local pipe_app = repl.get_sclang_pipe_app()
  local term_cmd = repl.get_term_cmd()
  table.insert(term_cmd, pipe_app)
  vim.system(term_cmd, { detach = true })
  -- TODO: detect when sclang has actually started
  repl.is_running = true
  local port = udp.start_server()
  assert(port > 0, 'Could not start scnvim UDP server')
  sclang.send(string.format('SCNvim.port = %d', port), true)
  sclang.set_current_path()
end

sclang.stop = function()
  local dispatcher = repl.get_sclang_dispatcher()
  vim.fn.system(dispatcher .. ' -q')
  udp.stop_server()
  repl.is_running = false
end

sclang.recompile = function()
  local dispatcher = repl.get_sclang_dispatcher()
  vim.fn.system(dispatcher .. ' -k')
  vim.fn.system(dispatcher .. ' -s ""')
  sclang.send(string.format('SCNvim.port = %d', udp.port), true)
  sclang.set_current_path()
end

sclang.set_current_path = function()
  if repl.is_running then
    local curpath = vim.fn.expand '%:p'
    curpath = vim.fn.escape(curpath, [[ \]])
    curpath = string.format('SCNvim.currentPath = "%s"', curpath)
    sclang.send(curpath, true)
  end
end

return require('scnvim').register_extension {
  setup = function(ext_config, user_config)
    repl.term_cmd = ext_config.term_cmd

    local id = vim.api.nvim_create_augroup('scnvim-repl', { clear = true })
    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = id,
      desc = 'Stop sclang on Nvim exit',
      pattern = '*',
      callback = sclang.stop,
    })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufNewFile', 'BufRead' }, {
      group = id,
      desc = 'Set the document path in sclang',
      pattern = { '*.scd', '*.sc', '*.quark' },
      callback = sclang.set_current_path,
    })
  end,
  health = function() end,
}
