MRI C1/C2/C3 MATLAB package
============================
Files:
- main.m: single-frame anatomical point detection and visualization.
- makeAllFramesVideo.m: all-frame MRI video with stored contours and manual landmarks.
- Remaining .m files: functions required by main.m.

Dataset:
- Put M2_358_temp.mat in this folder, or edit matFilePath in main.m and
  makeAllFramesVideo.m to its absolute path.
- Expected top-level variables: annotation, imgs.
- annotation is a struct array; required contour fields are contour1/2/3.
- Manual landmark fields: UL, LL, VEL.

Run:
1. Add this folder to the MATLAB path: addpath(pwd)
2. Run makeAllFramesVideo for the video.
3. Run main for single-frame point detection.

Important:
The supplied MATLAB output confirms that annotation is a 1x72 struct and
that contour1/2/3 and UL/LL/VEL fields exist. It does NOT show the actual
values or sizes of those fields. The video script prints raw field sizes and
counts usable contours. It will not invent contours if fields are empty.
The scripts have not been executed in MATLAB in this environment.
