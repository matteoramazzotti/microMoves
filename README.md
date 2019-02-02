# microMoves
tools for measuring cell movements in microscopy

#migraPix
migraPix helps in quantifying migration of cells in wound-healing assays and is especially useful in co-culture condition. 
The 

The tool is a simple javascript-enabled html file that must be saved in the same folder of the images to be analyzed.
Once started a a web page is opened in the web browser. A very simple interface is present at this moment.
The processing of images is performed following procedure:
1. click the "Browse" button and select the image to be analyzed.
2. click the "Load image" button to show the image in the right panel. 
3. If the size of the image is too big or too small, change the value of the zoom factor and click the "Load image" button again.
4. Identify the wound margins.
5. The idea now is to draw a line that represent the first migration start. The line is drawn by clicking on the two extreme points of that line.
6. Do the same for an ideal middle-migration line
7. Do the same for a the second migration start
8. Click on cells (or nuclei, or whatever you consider a valid migration point)
9. Depending on the distance form the two straight lines (the dashed one is just for reference), cell distance to the closest line will be reported on the text area on the left.
10. Once finished, copy the content of the text area and apste in your analysis software (MS Excel, Liberoffice Calc or whatever)

The current distribution includes a video representing a demo usage of this program.
