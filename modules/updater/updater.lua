Updater = {}

Updater.maxRetries = 5

local updaterWindow
local loadModulesFunction
local scheduledEvent
local httpOperationId = 0

-- Validates APK metadata before any Android-native operation is requested.
local function getAndroidPackage(data)
  if not g_android or type(data.androidPackage) ~= 'table' then
    return nil
  end

  local package = data.androidPackage
  local versionCode = tonumber(package.versionCode)
  if not versionCode or versionCode <= g_android.getVersionCode() then
    return nil
  end
  if type(package.url) ~= 'string' or not package.url:match('^https://') then
    return nil
  end
  if type(package.sha256) ~= 'string' or not package.sha256:match('^[a-fA-F0-9]+$') or package.sha256:len() ~= 64 then
    return nil
  end
  return package
end

-- Offers the native package first. If postponed, the normal Lua/data updater
-- continues immediately so APK and content updates remain independent.
local function offerAndroidPackageUpdate(package, continueCallback)
  local versionName = tostring(package.versionName or package.versionCode)
  local prompt
  local function updateNow()
    prompt:destroy()
    g_android.requestApkUpdate(package.url, package.sha256, tonumber(package.versionCode))
    Updater.abort()
  end
  local function updateLater()
    prompt:destroy()
    continueCallback()
  end

  prompt = displayGeneralBox(tr('Atualização do aplicativo'),
    tr('Uma nova versão do Crystal (%s) está disponível. Deseja baixar e instalar agora?', versionName), {
      { text = tr('Atualizar'), callback = updateNow },
      { text = tr('Depois'), callback = updateLater }
    }, updateNow, updateLater)
end

local function onLog(level, message, time)
  if level == LogError then
    Updater.error(message)
    g_logger.setOnLog(nil)
  end
end

local function loadModules()
  if loadModulesFunction then
    local tmpLoadFunc = loadModulesFunction
    loadModulesFunction = nil
    tmpLoadFunc()
  end
end

local archiveRoots = { data = true, modules = true, mods = true }

local function supportsArchiveUpdates()
  return type(g_resources.extractDownloadedArchiveToWorkDir) == 'function'
    and type(g_resources.readFileContents) == 'function'
    and type(g_crypt.sha256) == 'function'
end

local function validateArchives(data)
  if data.archives == nil then return {} end
  if type(data.archives) ~= 'table' or not supportsArchiveUpdates() then
    return nil, 'Invalid or unsupported updater ZIP packages'
  end
  for root, archive in pairs(data.archives) do
    if not archiveRoots[root] or type(archive) ~= 'table'
      or archive.file ~= '/' .. root .. '.zip'
      or type(archive.checksum) ~= 'string' or #archive.checksum > 8
      or not archive.checksum:match('^[a-f0-9]+$')
      or type(archive.sha256) ~= 'string' or #archive.sha256 ~= 64
      or not archive.sha256:match('^[a-f0-9]+$')
      or (archive.prefix ~= '' and archive.prefix ~= root) then
      return nil, 'Invalid updater ZIP metadata'
    end
  end
  return data.archives
end

local function verifyDownloadedArchive(file, archive)
  local ok, contents = pcall(g_resources.readFileContents, '/downloads/' .. file:gsub('^/', ''))
  if not ok then return false, tostring(contents) end
  if g_crypt.sha256(contents) ~= archive.sha256 then
    return false, 'Invalid SHA-256 of: ' .. file
  end
  return true
end

local function downloadFiles(url, files, index, retries, doneCallback)
  if not updaterWindow then return end
  local entry = files[index]
  if not entry then -- finished
    return doneCallback()
  end
  local file = entry[1]
  local file_checksum = entry[2]

  if retries > 0 then
    updaterWindow.downloadStatus:setText(tr("Downloading (%i retry):\n%s", retries, file))
  else
    updaterWindow.downloadStatus:setText(tr("Downloading:\n%s", file))
  end
  updaterWindow.downloadProgress:setPercent(0)
  updaterWindow.mainProgress:setPercent(math.floor(100 * index / #files))

  httpOperationId = HTTP.download(entry[3] or (url .. file), file,
    function(file, checksum, err)
      if not err and checksum ~= file_checksum then
        err = "Invalid checksum of: " .. file .. ".\nShould be " .. file_checksum .. ", is: " .. checksum
      end
      if not err and entry.archive then
        local valid, archiveError = verifyDownloadedArchive(file, entry.archive)
        if not valid then err = archiveError end
      end
      if err then
        if retries >= Updater.maxRetries then
          Updater.error("Can't download file: " .. file .. ".\nError: " .. err)
        else
          scheduledEvent = scheduleEvent(function()
            downloadFiles(url, files, index, retries + 1, doneCallback)
          end, 250)
        end
        return
      end
      downloadFiles(url, files, index + 1, 0, doneCallback)
    end,
    function(progress, speed)
      updaterWindow.downloadProgress:setPercent(progress)
      updaterWindow.downloadProgress:setText(speed .. " kbps")
    end)
end

local function updateFiles(data, keepCurrentFiles, skipAndroidPackage)
  if not updaterWindow then return end

  if type(data) ~= "table" then
    return Updater.error("Invalid data from updater api (not table)")
  end

  if type(data.error) == 'string' and data.error:len() > 0 then
    return Updater.error(data.error)
  end

  if not data.files or type(data.url) ~= 'string' or data.url:len() < 4 then
    return Updater.error("Invalid data from updater api: " .. json.encode(data, 2))
  end

  if not skipAndroidPackage then
    local androidPackage = getAndroidPackage(data)
    if androidPackage then
      return offerAndroidPackageUpdate(androidPackage, function()
        updateFiles(data, keepCurrentFiles, true)
      end)
    end
  end

  if data.keepFiles then
    keepCurrentFiles = true
  end

  local archives, archiveError = validateArchives(data)
  if not archives then return Updater.error(archiveError) end

  updaterWindow.status:setText(tr('Verificando arquivos locais...'))
  local newFiles = false
  local finalFiles = {}
  local localFiles = g_resources.filesChecksums()

  local toUpdate = {}
  local toUpdateFiles = {}
  -- keep all files or files from data/things
  for file, checksum in pairs(localFiles) do
    if keepCurrentFiles or string.find(file, "data/things") then
      table.insert(finalFiles, file)
    end
  end

  -- Protocol 2 may route versioned assets to a pinned GitHub commit.
  -- Binary downloads keep the API's VPS base URL.
  if data.fileUrls ~= nil and type(data.fileUrls) ~= 'table' then
    return Updater.error("Invalid updater file URLs")
  end
  local fileUrls = data.fileUrls or {}
  for file, downloadUrl in pairs(fileUrls) do
    if not data.files[file] or type(downloadUrl) ~= 'string' or
       not downloadUrl:match('^https://') then
      return Updater.error("Invalid updater download URL")
    end
  end

  -- Download one ZIP for each newer group that contains changed/missing files.
  local archiveUpdates = {}
  for root, archive in pairs(archives) do
    local prefix = '/' .. root .. '/'
    for file, checksum in pairs(data.files) do
      if file:sub(1, #prefix) == prefix and localFiles[file] ~= checksum then
        local entry = { archive.file, archive.checksum }
        entry.archive = archive
        entry.root = root
        table.insert(toUpdate, entry)
        archiveUpdates[root] = true
        newFiles = true
        break
      end
    end
  end

  -- update files
  for file, checksum in pairs(data.files) do
    table.insert(finalFiles, file)
    local root = file:match('^/([^/]+)/')
    if not archiveUpdates[root] and (not localFiles[file] or localFiles[file] ~= checksum) then
      table.insert(toUpdate, { file, checksum, fileUrls[file] })
      table.insert(toUpdateFiles, file)
      newFiles = true
    end
  end

  -- update binary
  local binary = nil
  if type(data.binary) == "table" and data.binary.file:len() > 1 then
    local selfChecksum = g_resources.selfChecksum()
    if selfChecksum:len() > 0 and selfChecksum ~= data.binary.checksum then
      binary = data.binary.file
      table.insert(toUpdate, { binary, data.binary.checksum })
    end
  end

  if #toUpdate == 0 then -- nothing to update
    updaterWindow.mainProgress:setPercent(100)
    scheduledEvent = scheduleEvent(Updater.abort, 20)
    return
  end

  -- update of some files require full client restart
  local forceRestart = next(archiveUpdates) ~= nil
  local reloadModules = false
  local forceRestartPattern = { "init.lua", "corelib", "updater", "otmod" }
  for _, file in ipairs(toUpdate) do
    for __, pattern in ipairs(forceRestartPattern) do
      if string.find(file[1], pattern) then
        forceRestart = true
      end
      if not string.find(file[1], "data/things") then
        reloadModules = true
      end
    end
  end

  updaterWindow.status:setText(tr("Updating %i files", #toUpdate))
  updaterWindow.mainProgress:setPercent(0)
  updaterWindow.downloadProgress:setPercent(0)
  updaterWindow.downloadProgress:show()
  updaterWindow.downloadStatus:show()

  downloadFiles(data["url"], toUpdate, 1, 0, function()
    updaterWindow.status:setText(tr("Updating client (may take few seconds)"))
    updaterWindow.mainProgress:setPercent(100)
    updaterWindow.downloadProgress:hide()
    updaterWindow.downloadStatus:hide()
    scheduledEvent = scheduleEvent(function()
      local restart = binary or (not loadModulesFunction and reloadModules) or forceRestart
      if #toUpdateFiles > 0 then
        if g_resources.updateFiles(toUpdateFiles, not restart) == false then
          -- The native error is already shown by onLog; do not restart.
          return
        end
      end

      local function installArchives(index)
        if not updaterWindow then return end
        local entry = toUpdate[index]
        if not entry then
          if binary and g_resources.updateExecutable(binary) == false then return end
          if restart then
            g_app.restart()
          else
            if reloadModules then
              g_textures.clearCache()
              g_modules.reloadModules()
            end
            Updater.abort()
          end
          return
        end
        if not entry.archive then return installArchives(index + 1) end
        updaterWindow.status:setText(tr('Descompactando %s. Aguarde...', entry[1]))
        g_logger.info('[updater] Extracting ' .. entry[1] .. ' into ' .. entry.root .. '/')
        -- Let the UI render before the native extractor starts working.
        scheduledEvent = scheduleEvent(function()
          if not updaterWindow then return end
          local ok, extracted = pcall(g_resources.extractDownloadedArchiveToWorkDir,
            entry[1], entry.root, entry.archive.prefix, entry.archive.prefix ~= '')
          if not ok or extracted ~= true then
            return Updater.error('Unable to extract ' .. entry[1] .. ': ' .. tostring(extracted))
          end
          installArchives(index + 1)
        end, 50)
      end
      installArchives(1)
    end, 100)
  end)
end

-- public functions
function Updater.init(loadModulesFunc)
  g_logger.setOnLog(onLog)
  loadModulesFunction = loadModulesFunc
  Updater.check()
end

function Updater.terminate()
  loadModulesFunction = nil
  Updater.abort(true)
end

function Updater.abort(terminate)
  HTTP.cancel(httpOperationId)
  removeEvent(scheduledEvent)
  if updaterWindow then
    updaterWindow:destroy()
    updaterWindow = nil
  end
  loadModules()
  if not terminate then
    signalcall(g_app.onUpdateFinished, g_app)
  end
end

function Updater.check(args)
  if updaterWindow then return end

  updaterWindow = g_ui.displayUI('updater')
  updaterWindow:show()
  updaterWindow:focus()
  updaterWindow:raise()

  local updateData = nil
  local function progressUpdater(value)
    removeEvent(scheduledEvent)
    if value == 100 then
      return Updater.error(tr("Timeout"))
    end
    if updateData and (value > 60 or (not g_platform.isMobile() or not ALLOW_CUSTOM_SERVERS or not loadModulesFunc)) then -- gives 3s to set custom updater for mobile version
      updaterWindow.status:setText(tr('Verificando arquivos locais...'))
      scheduledEvent = scheduleEvent(function() updateFiles(updateData) end, 50)
      return
    end
    scheduledEvent = scheduleEvent(function() progressUpdater(value + 1) end, 100)
    updaterWindow.mainProgress:setPercent(value)
  end
  progressUpdater(0)

  local requestArgs = args or {}
  if g_android then
    requestArgs.androidVersionCode = g_android.getVersionCode()
  end

  httpOperationId = HTTP.postJSON(Services.updater, {
    updaterProtocol = 2,
    archiveUpdates = supportsArchiveUpdates(),
    version = g_app.getBuildRevision(),
    build = g_app.getVersion(),
    os = g_app.getOs(),
    platform = g_window.getPlatformType(),
    arch = g_app.getBuildArch(),
    args = requestArgs
  }, function(data, err)
    if err then
      return Updater.error(err)
    end
    updateData = data
  end)
end

function Updater.error(message)
  removeEvent(scheduledEvent)
  if not updaterWindow then return end
  displayErrorBox(tr("Updater Error"), message).onOk = function()
    Updater.abort()
  end
end
