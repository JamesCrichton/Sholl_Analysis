//Written by James Crichton
//Script to segment fluorescent images of astrocytes to create binary skeletons and nuclear masks. These are subsequently quantified by Scholl analysis.
//Requires installation of the Neuroanatomy plugin. 
//Input images currently need to be 2D stacks containing a nuclear image and an astrocyte marker e.g. GFAP


run("Fresh Start");//reset basic parameters

//1a Open Image
#@ File (label="Image file", style="file") file_path
#@ File (label="Segmentation model for Advanced Weka", style="file") seg_model
#@ File (label="Save to directory", style="directory") dir1

//Set up Sholl parameters
#@ Float (label="Radius step size (px)", value=1) step_size
#@ Integer (label="Starting distance from nuclear centroid (px)", value=0) centroid_distance


open(file_path);
img_name=getTitle();

dir2=dir1+File.separator+File.nameWithoutExtension;

File.makeDirectory(dir2);

//1b Define channels
//Make an array for the channlels in the image
channels_array=Array.getSequence(nSlices+1);//make an array from 0 to nslices
channels_array=Array.deleteIndex(channels_array, 0);//remove the first number from the array i.e. 0

//Initialise the values of the nuclear and astrocyte channels 
nuclear_channel=0;
astrocyte_channel=0;

//Set unique numbers for nucleus and astrrocyte
while ((nuclear_channel==astrocyte_channel)|(nuclear_channel==0)|(astrocyte_channel==0)){

	Dialog.createNonBlocking("Setting channels");
	Dialog.addChoice("Nuclear Channel", channels_array);
	Dialog.addChoice("Astrocyte Label Channel", channels_array);
	Dialog.show();
	
	nuclear_channel=Dialog.getChoice();
	astrocyte_channel=Dialog.getChoice();
		}



//2. Segment astrocyte filaments
	//Isolate the astrocyte image
	selectImage(img_name);
	run("Duplicate...", "title=Astrocyte duplicate channels="+astrocyte_channel);

	//Run the pixel classifier to segment 
	run("Advanced Weka Segmentation");
	wait(3000); //wait for Weka to load before loading the model
	call("trainableSegmentation.Weka_Segmentation.loadClassifier", seg_model);
	call("trainableSegmentation.Weka_Segmentation.getProbability");
	
	//Threshold prob map
	selectWindow("Probability maps");
	run("Duplicate...", "title=Map duplicate range=1-1");//select probability map of class 1 (foreground)
	setThreshold(0.4706, 1000000000000000000000000000000.0000);
	run("Convert to Mask");
	
	
	//Skeletonize
	run("Skeletonize (2D/3D)"); //convert to skeleton
	run("Analyze Particles...", "size=80-Infinity pixel show=Masks");//remove little bits (<=80px in length)

//3. Segment nuclei. Does this work OK? Can improve if needed
	selectImage(img_name);
	run("Duplicate...", "title=Nuclear duplicate channels="+nuclear_channel);
	run("Gaussian Blur...", "sigma=5");
	run("Auto Threshold", "method=Otsu white");
	run("Fill Holes");

//4. Make a composite for reference
selectImage(img_name);run("Duplicate...", "title=Astrocyte_original duplicate channels="+astrocyte_channel);run("8-bit");
selectImage(img_name);run("Duplicate...", "title=Nuclear_original duplicate channels="+nuclear_channel);run("8-bit");
selectImage("Mask of Map");run("Duplicate...", "title=skeleton");

run("Merge Channels...", "c1=Astrocyte_original c2=skeleton c3=Nuclear_original c5=Nuclear create keep ignore");
saveAs("tiff", dir2+"/segmentation_composite");

//5. Save masks
selectImage("Probability maps");saveAs("tiff", dir2+"/astrocyte_prob_map");
selectImage("Mask of Map");saveAs("tiff", dir2+"/astrocyte_skeleton");
selectImage("Nuclear");saveAs("tiff", dir2+"/nuclear_mask");


//6 Isolate ROIS for cells to analyse
selectImage("segmentation_composite.tif");
Stack.setActiveChannels("1010");
run("Channels Tool...");

while (roiManager("count")==0){
	setTool("freehand");
	run("ROI Manager...");
	waitForUser("ROI Selection", "Define cell ROIs to be analysed using the freehand tool (selected).\nAdd to the ROI manager by pressing (T)\nSegmentation masks can be turned on/off using the channel viewer tool.\nPress \"OK\" when finished");
}


""""""""""""""""""""""""""""""""""""""""""""""""



//7. Run Sholl analysis

Image.removeScale();//currently removing scale from the image for simplicity 

img="segmentation_composite.tif";

//Loop through cell ROIs
n_ROI=roiManager("count");

for (ROI=0;ROI<n_ROI;ROI++){
	selectImage(img);
	roiManager("Select", ROI);
	roiManager("rename", "Cell_ROI_"+ROI);
			
	//Add nuclear centre to ROI manager as a reference to seed the Sholl analysis
	run("Duplicate...", "title=Nuc_Mask duplicate channels=4");
	run("Clear Outside");
	run("Set Measurements...", "centroid redirect=None decimal=3");
	run("Create Selection");
	run("Measure");
	X=getResult("X", 0);
	Y=getResult("Y", 0);
	run("Clear Results");
	makePoint(X,Y, "small yellow hybrid");
		
	roiManager("Add");
	Cropped_Nuc_ROI=n_ROI+ROI;
	roiManager("Select", Cropped_Nuc_ROI);
	roiManager("rename", "Nuc_ROI_"+ROI);
	close("Nuc_Mask");
	
	//Crop selected astrocyte
	selectImage(img);
	roiManager("Select", ROI);	
	run("Duplicate...", "title=Cropped_Skeleton duplicate channels=2");
	run("Clear Outside");
	run("Select None");

	//Calulate the maximum radius from this centre to measure, using the image frame and the centroid coordinates
	width=getWidth();
	height=getHeight();
		
	distances_to_corners=newArray();
	distances_to_corners=Array.concat(distances_to_corners,pow((pow(X,2)+pow(Y,2)),0.5));//top left
	distances_to_corners=Array.concat(distances_to_corners,pow((pow(width-X,2)+pow(Y,2)),0.5));//top right
	distances_to_corners=Array.concat(distances_to_corners,pow((pow(X,2)+pow(height-Y,2)),0.5));//bottom left
	distances_to_corners=Array.concat(distances_to_corners,pow((pow(width-X,2)+pow(height-Y,2)),0.5));//bottom right
	Array.getStatistics(distances_to_corners, min, max, mean, stdDev);

	//Save each analysis to metadata folder for each cell 
	dir3=dir2+File.separator+"ROI_"+ROI;
	File.makeDirectory(dir3);

	//Run Sholl
	roiManager("Select", Cropped_Nuc_ROI);//Select the nuclear centre ROI for Sholl
	
	run("Legacy: Sholl Analysis (From Image)...", "starting="+centroid_distance+" ending="+max+" radius_step="+step_size+" #_samples=1 integration=Mean enclosing=1 #_primary=0 infer fit linear polynomial=[Best fitting degree] most normalizer=Area create overlay directory=["+dir3+"]");
	
	//Save outpus and close superfluous windows
	selectImage("Cropped_Skeleton_ShollMask.tif");saveAs("tiff", dir3+File.separator+"Cropped_Skeleton_ShollMask.tif");close("Cropped_Skeleton_ShollMask.tif");
	selectImage("Cropped_Skeleton");saveAs("tiff", dir3+File.separator+"Cropped_Skeleton.tif");close();//NB this will have an overlay of the analysis rings
	selectImage("Sholl profile (Linear) for Cropped_Skeleton");saveAs("tiff", dir3+File.separator+"Sholl_Profile_Linear_Plot.tif");close("Sholl_Profile_Linear_Plot.tif");
	selectWindow("Cropped_Skeleton_Sholl-Profiles");saveAs("results", dir3+File.separator+"Sholl_Profiles_Data.csv");close("Sholl_Profiles_Data.csv");
	selectWindow("Sholl Results");saveAs("results", dir3+File.separator+"Sholl_Summary_Results.csv");close("Sholl_Summary_Results.csv");
	
	open_names=getList("image.titles");
	for (i=0;i<lengthOf(open_names);i++){
		window=open_names[i];
		if (window=="Sholl profile (Log-log) for Cropped_Skeleton"){
			selectImage("Sholl profile (Log-log) for Cropped_Skeleton");saveAs("tiff", dir3+File.separator+"Sholl_Profile_Log-Log_Plot.tif");
			close("Sholl_Profile_Log-Log_Plot.tif");			
		}
		if (window=="Sholl profile (Semi-log) for Cropped_Skeleton"){
			selectImage("Sholl profile (Semi-log) for Cropped_Skeleton");saveAs("tiff", dir3+File.separator+"Sholl_Profile_Log-Log_Plot.tif");
			close("Sholl_Profile_Log-Log_Plot.tif");			
		}
	}

	
}

//closing all remaining windows including Advanced Weka
open_names=getList("image.titles");
for (i=0;i<lengthOf(open_names);i++){
	window=open_names[i];
	close(window);

roiManager("Save", dir2+File.separator+"Analysis_Selection.zip"); //save ROIs
close("Channels");close("ROI Manager");
close("*");

//Save the settings used for reference
setResult("Image", 0, file_path);
setResult("Segmentation_Model", 0, seg_model);
setResult("Sholl_step_size", 0, step_size);
setResult("Sholl_starting_radius", 0, centroid_distance);
setResult("Nuclear_Channel", 0, nuclear_channel);
setResult("Cell_Body_Channel", 0, astrocyte_channel);
setResult("ROIs_Analysed", 0, n_ROI);
selectWindow("Results");saveAs("results", dir3+File.separator+"Macro_Settings.csv");close("Macro_Settings.csv");
