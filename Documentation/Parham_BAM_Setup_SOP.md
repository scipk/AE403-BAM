# BAM Full Installation SOP --- Windows (V1.0.1)

This Standard Operating Procedure (SOP) covers the complete installation and setup of NASA's
Baseball Avoidance Multirotor (BAM) simulation with the ROS2 + Colosseum + Unreal Engine
visualization pipeline on Windows 10/11.

> **Source repo:** https://github.com/nasa/Baseball-Avoidance-Multirotor-BAM

---

## Prerequisites

| Software | Version Tested | Notes |
|----------|---------------|-------|
| Windows | 10/11 (64-bit) | |
| Visual Studio 2022 | Community 17.14+ | [Download](https://aka.ms/vs/17/release/vs_community.exe) |
| MATLAB & Simulink | 2024b or newer | Free through SDSU |
| Git | Any recent | Must include Git LFS |
| CMake | 3.20+ | Comes with VS 2022, no worries. |

> **Note:** Everytime you see `%USERPROFILE%` in this document, replace it with your PC profile name.

---

## Step 0: Visual Studio Community 2022
Here's a quick link to download: https://aka.ms/vs/17/release/vs_community.exe

After launching it, the `Visual Studio Installer` should give you options for packages. 
1. Go to the **Workloads** tab. 
2. Under **Desktop & Mobile (5)** select `Desktop development with C++`.
3. Under **Gaming (2)** select `Game development with C++`.

> **NOTE:** When using `Developer Command Prompt for VS 2022`, here are some useful tips:
> 1. To go up one directory, use `cd ..`.
> 1. To go to the top directory, use `cd \`.


## Step 1: Install ROS2 (Robostack)

All commands in this SOP should be run from a `Developer Command Prompt for VS 2022`
unless otherwise noted.

### 1.1 Clone the BAM repository

Before copying this code, know that I have a `D:` drive that I used to save storage. You may do this in your `C:` drive.

```bat
D:
mkdir BAM
cd BAM
git clone https://github.com/nasa/Baseball-Avoidance-Multirotor-BAM.git
cd Baseball-Avoidance-Multirotor-BAM
```

> **Note:** You may see a Git LFS error for `Win_BAM_English_College.zip`. This is the
> Unreal environment binary (~1.2 GB). If LFS fails, download it from the
> [GitHub repo](https://github.com/nasa/Baseball-Avoidance-Multirotor-BAM/blob/main/VisualEnv/UnrealEngine/Win_BAM_English_College.zip) (there's a Download button on the right side of the page)
> and extract it into `VisualEnv\` next to the `VisualEnv\UnrealEngine\` folder.

### 1.2 Install ROS2 Jazzy via Robostack

```bat
cd ROS2_ws
config\win64\install_ros2_jazzy_robostack.bat
```

This installs Pixi (if needed) and creates a Robostack ROS2 Jazzy environment at
`C:\Users\%USERPROFILE%\robostack`. When prompted to activate, choose **Y**.

> **Note:** You will see a warning about replacing `[project]` with `[workspace]`. 
> 1. In your Windows Explorer, navigate to your `C:\users\%USERPROFILE%\robostack\` folder.
> 2. Open the `pixi.toml` with your favorite text editor.
> 3. Replace `[project]` with `[workspace]`. Then save `pixi.toml`.

### 1.3 Activate the ROS2 environment (for all future terminals)

Every time you open a new terminal, run:

```bat
C:\Users\%USERPROFILE%\robostack\activate_ros2_jazzy.bat
```

or if you're feeling extra nerdy:

```bat
cd C:\Users\%USERPROFILE%\robostack
pixi shell -e jazzy
```

Your prompt will change to `(robostack:jazzy)`.

---

## Step 2: Build Colosseum (AirSim successor for Unreal 5)

### 2.1 Clone and build Colosseum

Follow the [Colosseum build instructions](https://codexlabsllc.github.io/Colosseum/build_windows/)
for Windows. 

#### 2.1.1 Instructions
1. Launch `Developer Command Prompt for VS 2022`
2. Open our BAM folder and clone the Repo:
```bat
D:
cd BAM
git clone https://github.com/CodexLabsLLC/Colosseum.git
cd Colosseum
```
3. Run `build.cmd` from the command line. 

> **Note:** If you're using `C:` drive, before you need to do Step 1 in Admin Mode. In the start menu, search for `Developer Command Prompt for VS 2022`, right-click and hover on **More**, then select **Run as Administrator**.

#### 2.1.2 Verify

After a successful build, verify that you have:

```
D:\BAM\Colosseum\AirLib\lib\x64\Release\AirLib.lib
D:\BAM\Colosseum\AirLib\deps\rpclib\lib\x64\Release\rpc.lib
D:\BAM\Colosseum\AirLib\deps\MavLinkCom\lib\x64\Release\MavLinkCom.lib
D:\BAM\Colosseum\AirLib\include\       // A bunch of header files
D:\BAM\Colosseum\AirLib\deps\eigen3\
```

### 2.2 Set the AirSimLib environment variable

**Temporary (current session only):**
```bat
set AirSimLib=D:\BAM\Colosseum\AirLib
```

**Permanent (recommended):**
```bat
setx AirSimLib "D:\BAM\Colosseum\AirLib"
```

> **WARNING:** `setx` takes effect in **new** terminal sessions only. After running `setx`,
> also run the `set` command above for your current session.

#### 2.2.1 Verify the variable

```bat
echo %AirSimLib%
```

Should print: `D:\BAM\Colosseum\AirLib`

---

## Step 3: Build BAM ROS2 Packages

### 3.1 Activate robostack and navigate to the repo root

```bat
cd %USERPROFILE%\robostack
pixi shell -e jazzy
D:
cd BAM\Baseball-Avoidance-Multirotor-BAM
```

#### 3.1.1 Set AirSimLib (if not yet set in this session)

```bat
set AirSimLib=D:\BAM\Colosseum\AirLib
```

### 3.2 Clean build (first time)

In the `Baseball-Avoidance-Multirotor-BAM\` directory:

```bat
colcon build
```

**Expected result: 10 packages finished, 0 failed.**

```
Summary: 10 packages finished [XX.Xs]
```

The packages built are:
- `ros_msg_iface` -- Custom ROS2 message interfaces
- `bam_2_airsim_pkg` -- ROS2 <-> Colosseum/Unreal bridge (requires AirSimLib)
- `mat_airsim_pub` / `mat_airsim_bball_pub` -- MATLAB Simulink s-function publishers
- `mat_airsim_pub_nonlib` / `mat_airsim_bball_pub_nonlib` -- Non-library publisher variants
- `psw_sub` -- Phase Space Warping subscriber
- `drone_plotter_py` -- Python drone plotter
- `phase_space_warping_py` -- Python PSW analysis
- `bam_launcher` -- Launch files

### 3.5 Source the built packages

In the `Baseball-Avoidance-Multirotor-BAM\` directory:

```bat
install\local_setup.bat
```

> **WARNING:** **You must run this in every new terminal session** before using any BAM ROS2
> packages. Without it, `ros2 run` will report "Package not found".

### 3.6 DO NOT use the `install_bam_ros_packages.bat` script

The repo-provided script `ROS2_ws\config\win64\install_bam_ros_packages.bat` has a
known bug on Windows where junction points cause relative path resolution failures in
Python packages (`egg_base` error). Use the manual `colcon build` approach described
above instead.

---

## Step 4: Configure AirSim Settings

### 4.1 Create the AirSim config directory
 
1. Open Windows Explorer
1. Go to `D:\BAM\Baseball-Avoidance-Multirotor-BAM\ROS2_ws\visualization_pkgs\bam_2_airsim`
1. Copy `Sample_settings.json`
1. Go to your `C:\Users\%USERPROFILE%\Documents\` folder
1. Create an `AirSim` folder
1. Paste the `Sample_settings.json` file here and rename it to `settings.json`

This configures Colosseum in **External Physics** mode with a multirotor vehicle named
"Drone", which is what BAM expects.

---

## Step 5: Obtain and Extract the Unreal Environment

### 5.1 Get the executable

At the beginning, you should've downloaded the Unreal Environment executable (`Win_BAM_English_College.zip`, ~1.2 GB) 
via the [GitHub repo](https://github.com/nasa/Baseball-Avoidance-Multirotor-BAM/blob/main/VisualEnv/UnrealEngine/Win_BAM_English_College.zip) (there's a Download button on the right side of the page).

If the Git LFS download succeeded during clone, the file will be at:
```
D:\BAM\Baseball-Avoidance-Multirotor-BAM\VisualEnv\UnrealEngine\Win_BAM_English_College.zip
```

### 5.2 Extract it

Extract the zip into the `VisualEnv` folder:
```
D:\BAM\Baseball-Avoidance-Multirotor-BAM\VisualEnv\Win_BAM_English_College\
```

After extraction, you should have an executable such as `EnglishCollege.exe` inside.

---

## Step 6: Run the Full Pipeline

You need **three terminal sessions** (all Developer Command Prompt for VS 2022):

### Terminal 1: Unreal Environment

```bat
D:\BAM\Baseball-Avoidance-Multirotor-BAM\VisualEnv\Win_BAM_English_College\EnglishCollege.exe
```

Wait for the Unreal environment to fully load before proceeding.

### Terminal 2: Bam2Airsim ROS2 Bridge

```bat
cd C:\Users\%USERPROFILE%\robostack
pixi shell -e jazzy
D:
cd BAM\Baseball-Avoidance-Multirotor-BAM
install\local_setup.bat
ros2 run bam_2_airsim_pkg Bam2Airsim -nobb
```

> **Why `-nobb`?** There is a known bug in Colosseum's `simSpawnObject` RPC binding
> for Unreal 5 that causes the baseball asset spawn to fail with
> `rpc::rpc_error during call`. The `-nobb` flag disables the baseball and runs
> the drone-only visualization. To enable the baseball, a patch to Colosseum's
> `RpcLibServerBase.cpp` is required -- contact daniel.r.hill@nasa.gov for details.

**Expected output:**
```
[Bam2Airsim] >> Starting up Bam2Airsim
[Bam2Airsim] >> Detected flag to disable Baseball Logic.
[Bam2Airsim] >> Checking Airsim Unreal Environment...
Connected!
Client Ver:1 (Min Req:1), Server Ver:1 (Min Req:1)
[Bam2Airsim] >> Multirotor vehicle 'Drone' Confirmed.
[Bam2Airsim] >> Skipping Baseball (Disabled via Options)
[Bam2Airsim] >> Enabling Airsim controls...
[Bam2Airsim] >> Running main ROS execution...
```

### Terminal 3: MATLAB / Simulink

```bat
cd C:\Users\%USERPROFILE%\robostack
pixi shell -e jazzy
D:
cd BAM\Baseball-Avoidance-Multirotor-BAM
install\local_setup.bat
matlab
```

In MATLAB:
```matlab
% Verify ROS2 is available
! ros2

% Run setup
setup;
```

#### Running Example Code in MATLAB
1. Pick any of the examples in `BAM\Baseball-Avoidance-Multirotor-BAM\Examples\` and copy it over to the main directory `BAM\Baseball-Avoidance-Multirotor-BAM\`.
2. Run it through the MATLAB instance we opened through the `Developer Command Prompt`.

---

## Quick Reference: New Terminal Session Checklist

Every time you open a new terminal to work with BAM:

```bat
:: 1. Activate ROS2
cd C:\Users\%USERPROFILE%\robostack
pixi shell -e jazzy

:: 2. Navigate to BAM
D:
cd BAM\Baseball-Avoidance-Multirotor-BAM

:: 3. Set AirSimLib (if not permanent via setx)
set AirSimLib=D:\BAM\Colosseum\AirLib

:: 4. Source ROS2 packages
install\local_setup.bat
```

---

## Known Issues

| Issue | Symptom | Workaround |
|-------|---------|------------|
| LFS budget exceeded | `git clone` fails to download `Win_BAM_English_College.zip` | Download from [Releases](https://github.com/nasa/Baseball-Avoidance-Multirotor-BAM/releases) page |
| Baseball spawn fails | `rpc::rpc_error during call` when Bam2Airsim starts | Use `-nobb` flag to skip baseball |
| `install_bam_ros_packages.bat` fails | `egg_base` path error for Python packages | Use manual `colcon build` from repo root instead |
| `bam_2_airsim_pkg` build fails | `Cannot open include file` for AirSim headers | Set `AirSimLib` env var, then `rd /s /q build\bam_2_airsim_pkg` and rebuild |
| CMake uses cached stale config | Package fails despite correct env var | Delete `build\<package_name>` and rebuild |
| `WNDPROC return value` warning | TypeError after colcon build | Cosmetic only -- can be safely ignored |
| `Package not found` | `ros2 run` can't find BAM packages | Run `call install\local_setup.bat` first |
| `load_ros2_dev.bat` activation error | `The input line is too long` | Caused by PATH being too long after multiple activations; open a fresh terminal |

---

## Contact

- **BAM Lead:** Michael J. Acheson -- michael.j.acheson@nasa.gov
- **Bam2Airsim Lead:** Daniel R. Hill -- daniel.r.hill@nasa.gov