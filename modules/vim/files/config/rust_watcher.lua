local M = {}

local scanDelayMs = 200
local minimumScanIntervalMs = 1000
local states = {}
local scheduleScan

local function activeClient(state)
  local client = vim.lsp.get_client_by_id(state.clientId)
  if not client or client.name ~= "rust_analyzer" or client:is_stopped() then return nil end
  return client
end

local function finishScan(state)
  state.scanning = false
  if state.rescan then
    state.rescan = false
    scheduleScan(state.clientId)
  end
end

local function parseFiles(root, output)
  local files = {}
  for _, relativePath in ipairs(vim.split(output, "\0", { plain = true, trimempty = true })) do
    local path = vim.fs.normalize(vim.fs.joinpath(root, relativePath))
    files[path] = true
  end
  return files
end

local function fileChanges(previousFiles, currentFiles)
  local changes = {}

  for path in pairs(currentFiles) do
    if not previousFiles[path] then
      table.insert(changes, {
        uri = vim.uri_from_fname(path),
        type = vim.lsp.protocol.FileChangeType.Created,
      })
    end
  end

  for path in pairs(previousFiles) do
    if not currentFiles[path] then
      table.insert(changes, {
        uri = vim.uri_from_fname(path),
        type = vim.lsp.protocol.FileChangeType.Deleted,
      })
    end
  end

  table.sort(changes, function(left, right)
    return left.uri < right.uri
  end)
  return changes
end

local function reportScanError(state, result)
  local detail = vim.trim(result.stderr or "")
  local message = ("Failed to scan Rust workspace %s with rg (exit %d)"):format(state.root, result.code)
  if detail ~= "" then message = message .. ": " .. detail end

  if state.lastError ~= message then
    state.lastError = message
    vim.notify(message, vim.log.levels.WARN)
  end
end

local function runScan(state)
  local client = activeClient(state)
  if not client then
    states[state.clientId] = nil
    return
  end

  if state.scanning then
    state.rescan = true
    return
  end

  state.scanning = true
  state.lastScanStarted = vim.uv.now()
  vim.system({
    "rg",
    "--files",
    "--null",
    "--no-ignore-vcs",
    "--glob",
    "*.rs",
    "--glob",
    "Cargo.toml",
    "--glob",
    "Cargo.lock",
    "--glob",
    "!**/target/**",
  }, { cwd = state.root }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      reportScanError(state, result)
      finishScan(state)
      return
    end

    state.lastError = nil
    local currentFiles = parseFiles(state.root, result.stdout or "")
    if not state.files then
      state.files = currentFiles
      finishScan(state)
      return
    end

    local changes = fileChanges(state.files, currentFiles)
    if #changes == 0 then
      state.files = currentFiles
    elseif client:notify("workspace/didChangeWatchedFiles", { changes = changes }) then
      state.files = currentFiles
    end

    finishScan(state)
  end))
end

scheduleScan = function(clientId)
  local state = states[clientId]
  if not state or state.scheduled then return end

  local elapsed = state.lastScanStarted and (vim.uv.now() - state.lastScanStarted) or minimumScanIntervalMs
  local delay = math.max(scanDelayMs, minimumScanIntervalMs - elapsed)
  state.scheduled = true

  vim.defer_fn(function()
    state.scheduled = false
    runScan(state)
  end, delay)
end

local function trackClient(client)
  if client.name ~= "rust_analyzer" or not client.root_dir or states[client.id] then return end

  local state = {
    clientId = client.id,
    root = vim.fs.normalize(client.root_dir),
  }
  states[client.id] = state
  runScan(state)
end

local function scanClients()
  for clientId in pairs(states) do
    scheduleScan(clientId)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("RustAnalyzerFileReconciliation", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then trackClient(client) end
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermClose" }, {
    group = group,
    callback = scanClients,
  })

  for _, client in ipairs(vim.lsp.get_clients({ name = "rust_analyzer" })) do
    trackClient(client)
  end
end

return M
