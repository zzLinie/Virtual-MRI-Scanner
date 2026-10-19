# Medical Imaging Project - Virtual MRI Scanner

Built with MATLAB R2025B, requires Image Processing Toolbox, MATLAB ui

Run this program with either main.m directly in MATLAB or mainapp.mlapp in MATLAB App Designer

The provided GUI allows the user to adjust parameters affecting MRI image acquisition
	Phantom Size: dimensions of ground-truth phantom
	Embedded Structures: base shape of inner structures, either ellipses or rectangle
	Advanced Structure Settings: (optional) allows customization of horizontal/vertical axis of embedded structures and their rotation
	Acquisition Scheme: simulate either cartesian sampling or radial sampling scheme
	Orientation: (cartesian only) allows swapping between horizontal and vertical sampling lines
	Number of Lines: (cartesian) number of sampling lines | (radial) number of sampling spokes
	Point Density: number of sampling points along each line/spoke
	Image Size: size of output image

Recommended parameters based on project findings
	Cartesian: 	Image size = phantom size
			Number of lines and point density = half of phantom size

	Radial:		Ratio between number of lines and image size = 8 or higher
				i.e. number of lines = 1024, image size = 128

Clicking [Run] passes the original phantom and parameters to the specified acquisition function
	Returns image reconstructed from k-space sampling and loss image (original - reconstructed)
	Returns reconstruction statistics, including error between phantom and reconstruction

Program files are found in MedIm2025_Code folder:
	main.m			:	Runs app directly
	mainapp.mlapp		:	Runs app in MATLAB App Designer
	acquisition_radial.m	:	Simulates radial sampling scheme with given parameters
	acquisition_cartesian.m	:	Simulates cartesian sampling scheme with given parameters
	make_phantom.m		:	Builds custom phantoms required within the program
