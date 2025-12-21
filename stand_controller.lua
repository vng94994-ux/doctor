getgenv().Script = "Moon Stand"
getgenv().Owner = "USERNAME"

getgenv().DisableRendering = false
getgenv().BlackScreen = false
getgenv().FPSCap = 60

getgenv().Guns = {"rifle", "aug", "flintlock", "db", "lmg"}

loadstring(game:HttpGet("https://raw.githubusercontent.com/vng94994-ux/doctor/refs/heads/main/stand_core.lua"))()
