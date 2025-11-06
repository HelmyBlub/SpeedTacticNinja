# Speed Tactic Ninja
A game made with programming language Zig and Vulkan Graphics API.
You controll a character to slice through enemies, but are limited in movement by random move pieces.
![image](./gameImages/libraryHeader.png)

# Install
- install Zig (version 0.14 used, unsure if newer versions work)
- vulkan developer SDK
- (optional) steam sdk

# Build
`zig build run`

`zig build test`

`zig build steam`

## cross compile 
- linux build
  - `zig build -Dtarget=x86_64-linux-gnu`
  - Make executable: `chmod +x speedTacticNinja`
  - (optional) steam api linux lib for steam connection
    - find on the internet "libsteam_api.so" place into folder
    - link lib: `export LD_LIBRARY_PATH=/lib:/usr/lib:/home/helmi/speedTacticNinjaBuild`


### steam upload
`tools\ContentBuilder\builder\steamcmd.exe +login <account_name> +run_app_build ..\scripts\speedTacticNinja.vdf +quit`