local utils = require("scope.utils")
local config = require("scope.config")

local M = {}

M.cache = {}
M.buf_cache = {}
M.last_buf = {}
M.current_tab = 0
M.last_tab = 0

function M.on_tab_new_entered()
  vim.api.nvim_buf_set_option(0, "buflisted", true)
end

function M.on_tab_enter()
  if config.hooks.pre_tab_enter ~= nil then
    config.hooks.pre_tab_enter()
  end
  M.current_tab = vim.api.nvim_get_current_tabpage()
  local buf_nums = M.cache[M.current_tab]
  if buf_nums then
    for _, k in pairs(buf_nums) do
      vim.api.nvim_buf_set_option(k, "buflisted", true)
    end
    local buf = M.last_buf[M.current_tab]
    if not buf then
      buf = buf_nums[1]
    end
    vim.cmd("buf " .. buf)
  end
  if config.hooks.post_tab_enter ~= nil then
    config.hooks.post_tab_enter()
  end
end

function M.on_buf_enter()
  if config.hooks.pre_buf_enter ~= nil then
    config.hooks.pre_buf_enter()
  end
  local buf = vim.api.nvim_get_current_buf()
  local buf_tab = M.buf_cache[buf]
  if buf_tab then
    if buf_tab ~= M.current_tab then
      M.on_tab_leave()
      M.buf_cache[buf] = buf_tab
      vim.cmd("tabnext " .. buf_tab)
      vim.cmd("buf " .. buf)
      M.on_tab_enter()
    else
      M.last_buf[buf_tab] = buf
    end
  end
  if config.hooks.post_buf_enter ~= nil then
    config.hooks.post_buf_enter()
  end
end

function M.on_tab_leave()
  if config.hooks.pre_tab_leave ~= nil then
    config.hooks.pre_tab_leave()
  end
  local tab = vim.api.nvim_get_current_tabpage()
  local buf_nums = utils.get_valid_buffers()
  M.cache[tab] = buf_nums
  for _, k in pairs(buf_nums) do
    vim.api.nvim_buf_set_option(k, "buflisted", false)
    M.buf_cache[k] = tab
  end
  M.last_tab = tab
  if config.hooks.post_tab_leave ~= nil then
    config.hooks.pre_tab_leave()
  end
end

function M.on_tab_closed()
  if config.hooks.pre_tab_close ~= nil then
    config.hooks.pre_tab_close()
  end
  M.cache[M.last_tab] = nil
  if config.hooks.post_tab_close ~= nil then
    config.hooks.post_tab_close()
  end
end

function M.revalidate()
  local tab = vim.api.nvim_get_current_tabpage()
  local buf_nums = utils.get_valid_buffers()
  M.cache[tab] = buf_nums
end

function M.print_summary()
  print("tab" .. " " .. "buf" .. " " .. "name")
  for tab, buf_item in pairs(M.cache) do
    for _, buf in pairs(buf_item) do
      local name = vim.api.nvim_buf_get_name(buf)
      print(tab .. " " .. buf .. " " .. name)
    end
  end
end

function M.move_current_buf(opts)
  -- ensure current buflisted
  local buflisted = vim.api.nvim_buf_get_option(0, "buflisted")
  if not buflisted then
    return
  end

  local target = tonumber(opts.args)
  if target == nil then
    -- invalid target tab, get input from user
    local input = vim.fn.input("Move buf to: ")
    if input == "" then -- user cancel
      return
    end

    target = tonumber(input)
  end

  -- bufferline always display  tab number, not the handle. When scope use tab handle to store buffer info. So need to convert
  local target_handle = vim.api.nvim_list_tabpages()[target]

  if target_handle == nil then
    vim.api.nvim_err_writeln("Invalid target tab")
    return
  end

  M.move_buf(vim.api.nvim_get_current_buf(), target_handle)
end

function M.move_buf(bufnr, target)
  -- copy current buf to target tab
  local target_bufs = M.cache[target] or {}
  target_bufs[#target_bufs + 1] = bufnr

  -- remove current buf from current tab if it is not the last one in the tab
  local buf_nums = utils.get_valid_buffers()
  if #buf_nums > 1 then
    vim.api.nvim_buf_set_option(bufnr, "buflisted", false)

    -- current buf are not in the current tab anymore, so we switch to the previous tab
    if bufnr == vim.api.nvim_get_current_buf() then
      vim.cmd("bprevious")
    end
  end
end

return M
