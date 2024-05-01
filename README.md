## Aim
This program ("Segmentation_and_Sholl.ijm") is designed to partially automate Sholl analysis of astrocytes. 
Trial analysis can be run using the segmentation model and image file included in this repository.

## Input
1. Multichannel 2-dimensional stack images, including fluorescent staining of astrocytes and nuclei. 
2. Segmentation model.
  - This currently uses the Advanced Weka plugin which is included in Fiji v1.54j.
  - Bespoke segmentation models should be train for specific image datasets independently

## Usage
Download the full repository and install the Neuroanatomy plugin to Fiji using the Help >> Update... >> Manage Update Sites >> Neuroanatomy >> Apply and Close

Open "Segmentation_and_Sholl.ijm" in Fiji and run. This will close any open windows.
1. Inputs: 
- Path to image you with to analyse
- Path to the segmentation model
- The program uses the nucleus to set the centre of the Sholl analysis. How far from the centre should this start (px)
- How much separation would you like between the Sholl analysis rings?

2. Specify which channel number in the multichannel stack represents the nucleus and which is the astrocyte staining

3. Segmentation
- Astrocytes are segmented using the using the trained model. The probability map is also currently used to create the mask, allowing relaxation of classificaion. This may not be necessary with better trained models. Masks are skeletonized prior to Sholl analysis. 
- Nuclei are segmented using classical methods, by Gaussian filtering followed by Otsu Thresholding.

4. Draw around cells you wish to analyse using the freehand tool and add to the ROI Manager (press "T"). When complete press "OK". Analysis will run and save outputs
- Use the "Channels" tool to also inspect the segmentation of nuclei and cellular extensions, and guide ROI selection
- ROIs addition/removal and inspection can be managed further using the "ROI Manager" tool


