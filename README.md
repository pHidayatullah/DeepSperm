# DeepSperm
## **Paper**
DeepSperm Paper can be downloaded for FREE (open access) at this link
 : https://www.sciencedirect.com/science/article/pii/S016926072100376X

## **Result**
In our experiment, we achieve 94.11 mAP on the test dataset, F1-score of 0.93, and a processing speed of 51.9 fps. In comparison with YOLOv4, our proposed method is 2.18 x faster on testing, and 2.9 x faster on training with a small dataset, while achieving comparative detection accuracy. The weights file size was also reduced significantly, with one-twentieth that of YOLOv4. Moreover, it requires a 1.07 x less graphical processing unit (GPU) memory than YOLOv4.

## **Method**
In the proposed architecture, we use only one detection layer, which is specific for small object detection. For handling overfitting and increasing accuracy, we set a higher input network resolution, use a dropout layer, and perform data augmentation on saturation and exposure. Several hyper-parameters are tuned to achieve better performance. Mean average precision (mAP), confusion matrix, precision, recall, and F1-score are used to measure accuracy. Frame per second (fps) is used to measure speed. We compare our proposed method with you only look once (YOLO) v3 and YOLOv4.

## **Training**
### **Download pretrained weights**
Download pretrained weights "darknet53.conv.74" file and place it in the backup.<br/>
Link to download: https://pjreddie.com/media/files/darknet53.conv.74<br/>

### **Training Command**
For example:
>`./darknet detector train data/spermRand_CMPBrev2_3_601050.data cfg/deepSperm640-RAJA-Alexey-DOawalCut2NewAug_CMPBrev2_3_601050.cfg backup/darknet53.conv.74 -map`


## **Testing**
### **Test on test image**

> `./darknet detector test data/spermRand_CMPBrev2_3_601050.data cfg/deepSperm640-RAJA-Alexey-DOawalCut2NewAug_CMPBrev2_3_601050.cfg backup/deepSperm640-RAJA-Alexey-DOawalCut2NewAug_CMPBrev2_3_601050_800.weights data/Dataset_802020/40_45test.png -thresh 0.05`
> 
![Test dataset result](predictions-40_45test4.jpg)

### **Test on video**<br/>

 The GIF files are limited to 25fps. They are for illustration purposes only. The real result achieves 51.9 average fps (2x faster than the GIF). <br/>

Download video "40-45.avi" file and place it in the data folder.<br/>
Link to download: https://drive.google.com/file/d/1NgKLW2GZc-IEkLYJT0W704bpSOsUXMFv/view?usp=sharing<br/>

> `./darknet detector demo data/spermRand_CMPBrev2_3_601050.data cfg/deepSperm640-RAJA-Alexey-DOawalCut2NewAug_CMPBrev2_3_601050.cfg backup/deepSperm640-RAJA-Alexey-DOawalCut2NewAug_CMPBrev2_3_601050_800.weights data/40-45.avi -thresh 0.05`

![validation video result](result40_45-deepSperm_new.gif)

## **How to measure accuracy (mAP)**
For example:
>`./darknet detector map data/testmAP_spermRand_CMPBrev2_3_601050.data cfg/deepSperm640-RAJA-Alexey-DOawalCut2NewAug_CMPBrev2_3_601050.cfg backup/deepSperm640-RAJA-Alexey-DOawalCut2NewAug_CMPBrev2_3_601050_800.weights`