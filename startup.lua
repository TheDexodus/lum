shell.setPath(shell.path() .. ":/bin")

if fs.exists("/autorun.lua") then
    shell.run("/autorun.lua")
end