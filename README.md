# Speed Tactic Ninja
work in progress


## build and run
`zig build run`

## run tests
`zig build test`


## cross compile 
- linux build
  - `zig build -Dtarget=x86_64-linux-gnu`
  - Make executable: `chmod +x speedTacticNinja`
  - (optional) steam api linux lib for steam connection
    - find on the internet "libsteam_api.so" place into folder
    - link lib: `export LD_LIBRARY_PATH=/lib:/usr/lib:/home/helmi/speedTacticNinjaBuild`


### steam upload
`tools\ContentBuilder\builder\steamcmd.exe +login <account_name> +run_app_build ..\scripts\speedTacticNinja.vdf +quit`