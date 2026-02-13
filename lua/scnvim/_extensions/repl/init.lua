local scnvim = require 'scnvim'
local sclang = require 'scnvim.sclang'
local postwin = require 'scnvim.postwin'
local socket = require 'scnvim.udp'
local path = require 'scnvim.path'
local repl = {}

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
-- These functions could actually be overriden to toggle the external terminal
-- via a system command.
postwin.open = function() end
postwin.close = function() end
postwin.toggle = function() end

local function init_(dispatcher)
  socket.start_server()
  local cmd = string.format('SCNvim.port = %d', socket.port)
  vim.system({dispatcher, '-s', cmd}):wait()
  local curpath = vim.fn.expand '%:p'
  curpath = vim.fn.escape(curpath, [[ \]])
  cmd = string.format('SCNvim.currentPath = "%s"', curpath)
  vim.system({dispatcher, '-s', cmd}):wait()
end

sclang.send = function(data, silent)
  silent = silent or false
  local cmd = not silent and '-i' or '-s'
  if repl.is_running then
    local dispatcher = repl.get_sclang_dispatcher()
    if not socket.udp then
      init_(dispatcher)
    end
    vim.system({dispatcher, cmd, data})
  end
end

sclang.start = function()
  local pipe_app = repl.get_sclang_pipe_app()
  local term_cmd = repl.get_term_cmd()
  table.insert(term_cmd, pipe_app)
  vim.system(term_cmd, { detach = true }):wait()
  repl.is_running = true
end

sclang.stop = function()
  local dispatcher = repl.get_sclang_dispatcher()
  vim.system({ dispatcher, '-q' }):wait()
  socket.stop_server()
  repl.is_running = false
end

sclang.recompile = function()
  local dispatcher = repl.get_sclang_dispatcher()
  vim.system({dispatcher, '-k'}):wait()
  vim.system({dispatcher, '-s', '""'}):wait()
  if not socket.udp then
    init_(dispatcher)
  end
  sclang.send(string.format('SCNvim.port = %d', socket.port), true)
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

sclang.poll_server_status = function()
  local config = require'scnvim.config'
  local cmd = string.format('SCNvim.updateStatusLine(%d)', config.statusline.poll_interval)
  sclang.send(cmd, true)
end

sclang.generate_assets = function(on_done)
  assert(repl.is_running, '[scnvim] sclang not running')
  local config = require'scnvim.config'
  local format = config.snippet.engine.name
  local expr = string.format([[SCNvim.generateAssets("%s", "%s")]], path.get_cache_dir(), format)
  sclang.eval(expr, on_done)
end

sclang.eval = function(expr, cb)
  assert(repl.is_running, '[scnvim] sclang not running')
  expr = vim.fn.escape(expr, '"')
  local id = socket.push_eval_callback(cb)
  local cmd = string.format('SCNvim.eval("%s", "%s");', expr, id)
  sclang.send(cmd, true)
end

sclang.reboot = function() print('reboot is not implemented') end

return scnvim.register_extension {
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
