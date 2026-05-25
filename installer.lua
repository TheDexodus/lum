local files = {
    {
        url = "https://raw.githubusercontent.com/TheDexodus/lum/refs/heads/main/bin/lum.lua",
        path = "/bin/lum.lua"
    },
    {
        url = "https://raw.githubusercontent.com/TheDexodus/lum/refs/heads/main/lib/lum.lua",
        path = "/lib/lum.lua"
    },
    {
        url = "https://raw.githubusercontent.com/TheDexodus/lum/refs/heads/main/startup.lua",
        path = "/startup.lua"
    }
}

local function ensureDir(path)
    local dir = fs.getDir(path)

    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

local function download(url, path)
    print("Downloading " .. path .. "...")

    local response = http.get(url)

    if not response then
        error("Failed to download: " .. url)
    end

    local content = response.readAll()
    response.close()

    ensureDir(path)

    local file = fs.open(path, "w")

    if not file then
        error("Failed to open file: " .. path)
    end

    file.write(content)
    file.close()

    print("Installed: " .. path)
end

for _, file in ipairs(files) do
    download(file.url, file.path)
end

print("Cleaning up installer...")

local installer = shell.getRunningProgram()

if installer and fs.exists(installer) then
    fs.delete(installer)
end

print("Lum installed successfully!")