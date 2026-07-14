#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import numpy as np
import tifffile as tf
import matplotlib.pyplot as plt


# imshow with sorted synapses
def plot_good_synapses(path_to_image, path_to_synapses, roi_radius, savepath, th_vmin=5, th_vmax=99):
    # load
    deltaf_map = tf.imread(path_to_image)
    vmin = np.percentile(deltaf_map, th_vmin)
    vmax = np.percentile(deltaf_map, th_vmax)
    # in case is a 4 layers RGB
    if deltaf_map.ndim == 3:
        deltaf_map = deltaf_map[:,:,0]
    synapses = np.loadtxt(path_to_synapses, delimiter=',').astype(int)[:,:3]
    # make plot
    plt.imshow(deltaf_map, cmap='gray', vmin=vmin, vmax=vmax)
    plt.axis('off')
    # plot synapses
    for (ei,sy,sx) in synapses:
        # index, row, col, ∆F/F, ks-d, ks-p
        plt.scatter(sx,sy,s=roi_radius*100,facecolors='none',edgecolor='orange',linewidths=1.2)
        # write n in list
        plt.text(sx,sy,str(ei),color='red',fontsize=9,ha='center',va='center',fontweight='bold')
    # remove margins
    plt.tight_layout()
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    # remove files
    os.remove(path_to_image)
    os.remove(path_to_synapses)
    plt.savefig(f'{savepath}_good.png', dpi=100, bbox_inches='tight', pad_inches=0)



# to run from terminal
if __name__ == "__main__":
    tempFolder = ""
    path_to_image = ""
    path_to_synapses = ""
    savename = ""
    for ei,arg in enumerate(sys.argv):
        if arg.startswith('--tempFolder'):
            tempFolder = str(arg.split('=')[1])
        if arg.startswith('--image'):
            path_to_image = str(arg.split('=')[1])
        if arg.startswith('--synapses'):
            path_to_synapses = str(arg.split('=')[1])
        if arg.startswith('--roiRadius'):
            roi_radius = float(arg.split('=')[1])
        if arg.startswith('--saveName'):
            savename = str(arg.split('=')[1])
    if not path_to_image:
        image_file = [f for f in os.listdir(tempFolder) if f.endswith('_background.tif')][0]
        path_to_image = os.path.join(tempFolder,image_file)
    if not path_to_synapses:
        data_file = [f for f in os.listdir(tempFolder) if f.endswith('_synapses.csv')][0]
        path_to_synapses = os.path.join(tempFolder, data_file)
    savepath = tempFolder if not savename else os.path.join(tempFolder,savename)
    plot_good_synapses(path_to_image, path_to_synapses, roi_radius, savepath)

#