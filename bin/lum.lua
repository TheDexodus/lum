-- Lua Units Manager --

local args = {...}
local commands = {}
local server = "http://77.223.97.81:3000/"
-- local server = "http://localhost:3000/"

local ccstrings = require("cc.strings")

if #args == 0 then
    print("Use \"lum help\" for get help")
    return
end

-- Utils --

local function subarr(arr, first, last)
    local result = {}

    for i = first, last do
        result[#result + 1] = arr[i]
    end

    return result
end

local function stringMultiply(str, count)
    result = ""

    for i = 1, count do
        result = result .. str
    end
    
    return result
end

local function printError(message)
    local currentColor = term.getTextColor()
    term.setTextColor(colors.red)
    print(message)
    term.setTextColor(currentColor)
end

local function printSuccess(message)
    local currentColor = term.getTextColor()
    term.setTextColor(colors.green)
    print(message)
    term.setTextColor(currentColor)
end

local function printInfo(message)
    local currentColor = term.getTextColor()
    term.setTextColor(colors.lightBlue)
    print(message)
    term.setTextColor(currentColor)
end

local function getToken()
    if not fs.exists("/.lum/config.json") then
        return nil
    end

    local file = fs.open("/.lum/config.json", "r")
    local raw = file.readAll()
    file.close()

    return textutils.unserializeJSON(raw).token
end

local function getPackageConfigPath()
    return shell.dir() .. "/lum.json"
end

local function getPackageConfig()
    local packageConfigPath = getPackageConfigPath()
    
    if not fs.exists(packageConfigPath) then
        return nil
    end

    local file = fs.open(packageConfigPath, "r")
    local raw = file.readAll()
    file.close()

    return textutils.unserializeJSON(raw)
end

local function getPackageFiles()
    local stack = {""}
    local result = {}

    while #stack > 0 do
        local currentRelativePath = stack[#stack]
        local currentAbsolutePath = fs.combine(shell.dir(), currentRelativePath)
        local files = fs.list(currentAbsolutePath)

        table.remove(stack, #stack)

        for _, fileName in ipairs(files) do
            if fileName ~= "packages" then
                local absolutePath = fs.combine(currentAbsolutePath, fileName)
                local relativePath = fs.combine(currentRelativePath, fileName)

                if fs.isDir(absolutePath) then
                    stack[#stack + 1] = relativePath
                else
                    local file = fs.open(absolutePath, "r")
                    result[relativePath] = file.readAll()
                    file.close()
                end
            end
        end
    end

    return result
end

local function prettyJson(value, indent, level)
    indent = indent or "  "
    level = level or 0
    local pad = string.rep(indent, level)
    local padNext = string.rep(indent, level + 1)
    local t = type(value)

    if t == "table" then
        if next(value) == nil then
            return "{}"
        end

        -- определяем: массив или объект
        local isArray = true
        local n = 0
        for k in pairs(value) do
            n = n + 1
            if type(k) ~= "number" then isArray = false end
        end
        if isArray then
            for i = 1, n do
                if value[i] == nil then isArray = false; break end
            end
        end

        local parts = {}
        if isArray then
            for i = 1, n do
                parts[#parts + 1] = padNext .. prettyJson(value[i], indent, level + 1)
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
        else
            local keys = {}
            for k in pairs(value) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                parts[#parts + 1] = padNext
                    .. textutils.serializeJSON(tostring(k))
                    .. ": "
                    .. prettyJson(value[k], indent, level + 1)
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
        end
    end

    return textutils.serializeJSON(value)
end

local function writeDependencyInConfig(package, version)
    local packageConfigPath = getPackageConfigPath()
    local packageConfig = getPackageConfig()

    if packageConfig == nil then
        packageConfig = {}
    end

    if packageConfig.dependencies == nil then
        packageConfig.dependencies = {}
    end

    packageConfig.dependencies[package] = version

    local file = fs.open(packageConfigPath, "w+")
    file.write(prettyJson(packageConfig))
    file.close()
end

-- API --

local function apiPost(action, bodyJson, headers)
    if headers == nil then
        headers = {}
    end

    headers["Content-Type"] = "application/json"
    local token = getToken()

    if token ~= nil then
        headers["Authorization"] = "Bearer " .. token
    end

    local response, message = http.post(
        server .. action,
        textutils.serializeJSON(bodyJson),
        headers
    )

    if response == nil then
        printError("API Error: " .. message)
        return
    end

    return textutils.unserializeJSON(response.readAll())
end

local function apiGet(action, headers)
    if headers == nil then
        headers = {}
    end

    headers["Content-Type"] = "application/json"
    local token = getToken()

    if token ~= nil then
        headers["Authorization"] = "Bearer " .. token
    end

    local response, message = http.get(
        server .. action,
        headers
    )

    if response == nil then
        printError("API Error: " .. message)
        return
    end

    return textutils.unserializeJSON(response.readAll())
end

local function getPackageVersions(package)
    local data = apiGet("package/" .. package)

    if data == nil then
        return nil
    end

    return data.versions
end

-- Commands --

local function commandHelp()
    print("Lum Package Manager")
    print("")
    print("Available commands:")

    local rows = {}

    for commandName, command in pairs(commands) do
        print(
            "  " 
            .. commandName
            .. " "
            .. command.arguments
            .. stringMultiply(" ", 22 - #commandName - #command.arguments)
            .. command.description
        )
    end
end

local function commandVersion()
end

local function commandInstall(package, secondaryDependency)
    if package == nil then
        local packageConfig = getPackageConfig()

        if packageConfig == nil then
            printError("File \"lum.json\" not founded for install")
        end

        for dependencyName, dependencyVersion in pairs(packageConfig.dependencies) do
            commandInstall(dependencyName .. ':' .. dependencyVersion, true)
        end

        return
    end

    local packageName, originalVersion = table.unpack(ccstrings.split(package, ":"))
    local author, name = table.unpack(ccstrings.split(packageName, "/"))
    local version = originalVersion

    if version == nil or version == "*" then
        local availableVersions = getPackageVersions(packageName)

        if availableVersions == nil then
            printError("Package \"" .. packageName .. "\" not founded")
            return
        end

        originalVersion = "*"
        version = availableVersions[1]
    end

    printInfo("Installing \"" .. packageName .. ":" .. version .. "\"")

    local data = apiGet("package/" .. packageName .. "/" .. version)

    if data == nil then
        return
    end

    local dependenciesResponse = apiGet("package/" .. packageName .. "/" .. version .. "/dependencies")

    if dependenciesResponse == nil then
        return
    end

    if secondaryDependency ~= true then
        writeDependencyInConfig(package, originalVersion)
    end

    local packagesPath = fs.combine(shell.dir(), "packages")

    if not fs.exists(packagesPath) then
        fs.makeDir(packagesPath)
    end

    local authorPath = fs.combine(packagesPath, author)

    if not fs.exists(authorPath) then
        fs.makeDir(authorPath)
    end

    local packagePath = fs.combine(authorPath, name)

    if fs.exists(packagePath) then
        fs.delete(packagePath)
    end

    fs.makeDir(packagePath)

    for fileName, fileContent in pairs(data.files) do
        local absolutePath = fs.combine(packagePath, fileName)
        local file = fs.open(absolutePath, "w")
        file.write(fileContent)
        file.close()
    end

    for dependencyName, dependencyVersion in pairs(dependenciesResponse.dependencies) do
        commandInstall(dependencyName .. ':' .. dependencyVersion, true)
    end

    printSuccess("Install \"" .. packageName .. ":" .. version .. "\" successfuly!")
end

local function commandRemove(package)
end

local function commandList()
end

local function commandRegister(username, password, justLogin)
    if username == nil then
        printError("Invalid a username")
        return
    end

    if password == nil then
        printError("Invalid a password")
        return
    end

    local action = "register"

    if justLogin == true then
        action = "login"
    end

    local data = apiPost(action, {
        ["username"] = username,
        ["password"] = password
    })

    if data == nil then
        return
    end

    if not fs.exists("/.lum") then
        fs.makeDir("/.lum")
    end

    local file = fs.open("/.lum/config.json", "w+")
    file.write(textutils.serializeJSON({["token"] = data.token}))
    file.close()

    if not justLogin then
        printSuccess("Successfuly registered!")
    else
        printSuccess("Successfuly login!")
    end
end

local function commandLogin(username, password)
    commandRegister(username, password, true)
end

local function commandLogout()
    if getToken() == nil then
        printError("You already not logged in")
        return
    end

    fs.delete("/.lum/config.json")
    printSuccess("You are logout!")
end

local function commandPush()
    local packageConfig = getPackageConfig()
    local files = getPackageFiles()
    
    local data = apiPost(
        "publish",
        {
            ["name"] = packageConfig.name,
            ["version"] = packageConfig.version,
            ["dependencies"] = packageConfig.dependencies,
            ["files"] = files
        }
    )

    if data == nil then
        return
    end

    printSuccess("Package \"" .. packageConfig.name .. "\" successfuly pushed!")
end

local function getCommands()
    return {
        ["help"] = {
            ["function"] = commandHelp,
            ["description"] = "Show availables commands",
            ["arguments"] = ""
        },
        ["version"] = {
            ["function"] = commandVersion,
            ["description"] = "Show a version of LUM",
            ["arguments"] = ""
        },
        ["install"] = {
            ["function"] = commandInstall,
            ["description"] = "Install a package",
            ["arguments"] = "<package?>"
        },
        ["remove"] = {
            ["function"] = commandRemove,
            ["description"] = "Remove a package",
            ["arguments"] = "<package>"
        },
        ["list"] = {
            ["function"] = commandList,
            ["description"] = "List all packages",
            ["arguments"] = "<page?>"
        },
        ["register"] = {
            ["function"] = commandRegister,
            ["description"] = "Register a new account",
            ["arguments"] = "<user> <pass>"
        },
        ["login"] = {
            ["function"] = commandLogin,
            ["description"] = "Login in your account",
            ["arguments"] = "<user> <pass>"
        },
        ["logout"] = {
            ["function"] = commandLogout,
            ["description"] = "Logout from your account",
            ["arguments"] = ""
        },
        ["push"] = {
            ["function"] = commandPush,
            ["description"] = "Push a current package",
            ["arguments"] = ""
        },
    }
end

local argCommand = args[1]
commands = getCommands()

if commands[argCommand] ~= nil then
    commands[argCommand]["function"](table.unpack(subarr(args, 2, #args)))
else
    print("Command \"" .. argCommand .. "\" not founded.")
    print("Use \"lum help\" for get help")
end