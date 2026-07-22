#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import numpy as np
import tifffile as tf
import matplotlib as mpl
import matplotlib.pyplot as plt
from skimage.draw import circle_perimeter
from matplotlib.animation import FuncAnimation
from pathlib import Path


# imshow with sorted synapses
def plot_good_synapses(path_to_image, path_to_synapses, roi_radius, savepath, 
                       th_vmin=5, th_vmax=99):
    # load
    deltaf_map = tf.imread(path_to_image)
    vmin = np.percentile(deltaf_map, th_vmin)
    vmax = np.percentile(deltaf_map, th_vmax)
    # in case is a 4 layers RGB
    if deltaf_map.ndim == 3:
        deltaf_map = deltaf_map[:,:,0]
    # so index, row, col
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
    plt.savefig(f'{savepath}_good.png', dpi=100, bbox_inches='tight', pad_inches=0)
    # remove files
    os.remove(path_to_image)
    os.remove(path_to_synapses)



# function to overlay circles in the movie
def overlay_synapses(path_to_movie, path_to_synapses, roi_radius, savepath,
                     color=(255,0,0), thickness=1, percentile_clip=(1,99), labels=False):
    # load
    movie = tf.imread(path_to_movie)
    # rows & cols
    synapses = np.loadtxt(path_to_synapses, delimiter=',').astype(int)[:,1:3]
    # make movie gray
    lo, hi = np.percentile(movie, percentile_clip)
    gray = np.clip((movie - lo) / max(hi - lo, 1e-12), 0, 1)
    gray8 = (gray * 255).astype(np.uint8)
    # broadcast to RGB: (nframes, rows, cols, 3)
    # np.broadcast_to is cheap (no copy) but tif writer needs contiguous data,
    # so we materialize with repeat
    overlay = np.repeat(gray8[..., None], 3, axis=-1)        
    # calculate circles from coordinates
    # H, W = self.nrows, self.ncols
    rows, cols = [], []
    nrows, ncols = movie.shape[1:]
    for r in range(int(roi_radius), int(roi_radius) + int(thickness)):
        for (y0, x0) in synapses:
            rr, cc = circle_perimeter(int(y0), int(x0), r, shape=(nrows, ncols))
            rows.append(rr)
            cols.append(cc)
    rr = np.concatenate(rows)
    cc = np.concatenate(cols)
    # mk circles
    for ch, val in enumerate(color):
        overlay[:, rr, cc, ch] = val
    # save
    path_to_overlay = f'{savepath}_good.tif'
    tf.imwrite(path_to_overlay, overlay)
    # remove files
    os.remove(path_to_movie)
    os.remove(path_to_synapses)


 # overlay + stimulus 
def mk_movie_plus_stimulus(path_to_movie, path_to_stimulus, frame_rate, savepath):
    # load
    movie = tf.imread(path_to_movie)
    with open(path_to_stimulus, "r") as f:
        awave = f.read()
    stimulus = np.array(awave.splitlines(), dtype=float)
    if os.path.exists('/opt/homebrew/bin/ffmpeg'):
        mpl.rcParams['animation.ffmpeg_path'] = '/opt/homebrew/bin/ffmpeg'
    elif os.path.exists('/opt/miniconda3/bin/ffmpeg'):
        mpl.rcParams['animation.ffmpeg_path'] = '/opt/miniconda3/bin/ffmpeg'
    elif os.path.exists('/opt/anaconda3/bin/ffmpeg'):
        mpl.rcParams['animation.ffmpeg_path'] = '/opt/anaconda3/bin/ffmpeg'
    else:
        try:
            path_to_ffmpeg = '/opt/{}/bin/ffmpeg'.format(os.listdir('/opt')[0])
            mpl.rcParams['animation.ffmpeg_path'] = path_to_ffmpeg
        except:
            print("\nffmpeg not found, skipping .mp4 movie creation")
            return
    fig, (ax_mov, ax_stim) = plt.subplots(2, 1, height_ratios=[4, 1])
    # title = f'{self.fname} - FoV={self.fov}, α={self.alpha}, ~ROIsize={self.synapseSize}, d={self.min_distance}'
    title = f'{Path(savepath).name}'
    fig.suptitle(title, fontsize=14)
    im = ax_mov.imshow(movie[0])
    # make x axis for time bar
    movie_secs = len(movie)/frame_rate
    ax_stim.set_xlim(0, movie_secs)
    # every 10 seconds + last, but if less than 5 secs remaining remove last x10
    ticks10 = np.arange(0, movie_secs, 10)[:-1] if movie_secs%10 < 5 else np.arange(0, movie_secs, 10)
    ticks = np.append(ticks10, movie_secs).astype(int)
    ax_stim.set_xticks(ticks)
    ax_stim.set_xlabel("Time (s)")
    nframes = movie.shape[0]
    stimulus2d = np.zeros((2,nframes))
    stimulus2d[0] = np.arange(nframes)/frame_rate
    stimulus2d[1] = stimulus
    ax_stim.plot(*stimulus2d)
    bar = ax_stim.axvline(0, color='r')

    def update(i):
        im.set_data(movie[i])
        # movie time in seconds
        t = i / frame_rate
        bar.set_xdata([t, t])
        return im, bar
    
    # this is to avoid saving every frame 
    # too slow un prob unnecessary for a quick impression
    # in this case, is every other frame (step = 2)
    step = 2
    frames_out = range(0, len(movie), step)
    # to include all frames do frames=len(movie)
    ani = FuncAnimation(fig, update, frames=frames_out, blit=True)
    # save a copy in desktop folder
    fcopy_dir = str(Path.home()/"Desktop")
    # fcopy_name = f'{savepath}.mp4'
    # savepath is an absolute path, so it's gonna override fcopy_dir
    fcopy_name = f'{Path(savepath).name}.mp4'
    fcopy_path = os.path.join(fcopy_dir,fcopy_name)
    ani.save(fcopy_path, writer='ffmpeg', fps=int(frame_rate)/step, dpi=60)
    plt.close()
    print(f'saved to: {fcopy_path}')
    # clean folder (this doesn't go back to Igor)
    folder = Path(path_to_movie).parent
    for file in folder.iterdir():
        if file.is_file():
            file.unlink()
     
    
    
# to run from terminal
if __name__ == "__main__":
    # Pawel realized that the quotes coming from Igor
    # which are needed to avoid problems like spaces, etc
    # produce an error when calling files from paths
    # the platform > system is a simple fix for this
    from platform import system
    tempFolder = ""
    savename = ""
    for ei,arg in enumerate(sys.argv):
        if arg.startswith('--tempFolder'):
            tempFolder = str(arg.split('=')[1])
            if system() == "Windows":
                tempFolder = tempFolder[1:-1]
        if arg.startswith('--roiRadius'):
            roi_radius = float(arg.split('=')[1])
        if arg.startswith('--frameRate'):
            frame_rate = 1/float(arg.split('=')[1])
        if arg.startswith('--saveName'):
            savename = str(arg.split('=')[1])
    # image (STD, ∆F, etc)
    image_file = [f for f in os.listdir(tempFolder) if f.endswith('_background.tif')]
    path_to_image = os.path.join(tempFolder,image_file[0]) if len(image_file) > 0 else ""
    # movie (overlay or any kind)
    movie_file = [f for f in os.listdir(tempFolder) if f.endswith('_movie.tif')]
    path_to_movie = os.path.join(tempFolder,movie_file[0]) if len(movie_file) > 0 else ""
    # stimulus/analysis wave
    stimulus_file = [f for f in os.listdir(tempFolder) if f.endswith('_stimulus.txt')]
    path_to_stimulus = os.path.join(tempFolder,stimulus_file[0]) if len(stimulus_file) > 0 else ""
    # synapses data
    data_file = [f for f in os.listdir(tempFolder) if f.endswith('_synapses.csv')]
    path_to_synapses = os.path.join(tempFolder, data_file[0]) if len(data_file) > 0 else ""
    # save path
    savepath = tempFolder if not savename else os.path.join(tempFolder,savename)
    # depending on input:
    # background image + synapses > synapses map
    if os.path.isfile(path_to_image) & os.path.isfile(path_to_synapses):
        plot_good_synapses(path_to_image, path_to_synapses, roi_radius, savepath)
    # movie + synapses > overlay
    elif os.path.isfile(path_to_movie) & os.path.isfile(path_to_synapses):
        overlay_synapses(path_to_movie, path_to_synapses, roi_radius, savepath)
    # movie + stimulus > movie in desktop
    elif os.path.isfile(path_to_movie) & os.path.isfile(path_to_stimulus):
        mk_movie_plus_stimulus(path_to_movie, path_to_stimulus, frame_rate, savepath)
    else:
        print(f'path_to_image: {path_to_image}')
        print(f'path_to_movie: {path_to_movie}')
        print(f'path_to_stimulus: {path_to_stimulus}')
        print(f'path_to_synapses" {path_to_synapses}')
        print(f'savepath: {savepath}')
        print("\n?\n")
    
    



















#