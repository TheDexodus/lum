local LumLoader = {}

function LumLoader.require(packageName)
    return require("/" .. fs.combine(shell.dir(), "packages", packageName, "main"))
end

return LumLoader