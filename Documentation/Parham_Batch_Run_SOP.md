These instructions are for the SDSU AE 403W Spring 2026 Group 10 "Elite Ball Knowledge" on how to run `EBK_AVOIDANCE.m` to test the MATLAB/Simulink avoidance. 
## I. Setup
1. Open the `AE403-BAM` folder inside MATLAB.
2. Select `setup.m` and press F9 on your keyboard.
	- or right-click on  and press run.
3. Launch `BAM.slx`.
4. Open the `BAM_Controller` subsystem block by double-clicking on it.
5. Open `The NOISER` subsystem block by double-clicking on it.
6. Open the parameters for the `Band-Limited White Noise` block and change "Noise Power:" to your desired noise level.
	- Ensure that inside the "Noise Power:" section you surround your desired noise level with brackets.
	- e.g. `[0.1]` for 10% added noise
7. Select "OK" and save.
	- CTRL+S or the "Save" button on the top-left.
8. You may now close or minimize this window.
## II. Settings
1. Open the `EBK_AVOIDANCE.m` script.
2. Find the "CONFIGURATION" section.
3. Ensure `run_mode = 'batch'`.
4. In the "BATCH SETTINGS" part, ensure:
	```
	N_runs = 100;
	start_pair = 1;
	use_parsim = false;
	```
	- Important to keep `use_parsim = false` because it's not setup yet.
5. In the "OUTPUT SETTINGS", ensure:
```
save_figures = true;
out_dir = './ChallengeProblem/Chal_Prob_Plots/BatchResults/';
model_name = 'BAM';
```
## III. Running
1. With `AE403-BAM\EBK_AVOIDANCE.m` open, press F5 on your keyboard.
	- or press the "Run" button in the "Editor" toolbar at the top.
2. Be patient, this will take a while.
3. When finished, the MATLAB console will print:
```
==============================================  
BATCH RESULTS SUMMARY  
==============================================  
Total runs: #  
Successful runs: #  
Errors: #  
-------------------------------------------

Collisions avoided: # / # (##.##%)  
Collisions/misses: # / # (##.##%)  
-------------------------------------------  
Min miss distance: ###.### m  
Max miss distance: ###.### m  
Mean miss distance: ###.### m  
Median miss distance:###.### m  
-------------------------------------------  
R_safe threshold: #.# m  
Total batch time: ####.# s (###.# min)

Avg time per run: ###.# s  
==============================================

All figures saved to: ./ChallengeProblem/Chal_Prob_Plots/BatchResults/  
Batch testing complete.
```
- Please COPY+PASTE this somewhere safe, like the Discord chat.
4. Open the AE403W google drive folder ([click here](https://drive.google.com/drive/folders/1bekvcEU-mSOycQMjT-gd6jansJ1ohhl1?usp=drive_link)) and open the "Test Batches" folder. Then open your specific folder.
5. Upload the 5 .png files in `AE403-BAM\ChallengeProblem\Chal_Prob_Plots\BatchResults`
	- `MissDistCDF.png`
	- `MissDistHistogram.png`
	- `MissDistScatter.png`
	- `SelectedTrajectories.png`
	- `SuccessRate.png`
6. We will together determine the most interesting graphs and show them in our presentation.
	- Some interesting cases will be run in "DEMO" mode by Parham.