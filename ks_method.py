
# base imports
import sys
import os
import platform
import matplotlib.pyplot as plt
from pathlib import Path
from matplotlib.animation import FuncAnimation
from check_libs import check_dependencies
# general modules
import numpy as np
import tifffile as tf
import pandas as pd
# specific functions
import get_metadata
from scipy.optimize import curve_fit
from scipy.ndimage import shift, gaussian_filter
from scipy.stats import ks_2samp
from skimage.registration import phase_cross_correlation
from skimage.feature import peak_local_max
from skimage.draw import circle_perimeter
from scipy.ndimage import zoom


class KS_pipeline:
    def __init__(self,
        fpath,                          # path to movie
        fov = 610,                      # field of view at zoom = 1
        alpha = 0.05,                   # threshold for p-value significance
        min_distance = 3,               # between pixel peaks
        synapse_size = 2,               # aprox. size in microns (µm x µm)
        concat = "",                    # needed for concatenated movies
        tempFolder = "",                # dir for temporary files
        analysisWave = False,           # to replace default comparator from mk stimulus
        mk_videos = False,              # makes 2 overlay videos in same folder
        # not definable from terminal
        percentile = 70,                # for peaks (candidates)
        sigma_smooth = 0,               # for gaussian filter in ΔF map
        sigma_fit = 1,                  # for 2d gaussian fit
        lambda_reg = 0.05,              # regul. strength in ridge regression
        edge_margin = 3,                # discarded, could be variable
        # for debugging
        igor = False,                    # for saving & then loading into igor
        analysisWave_array = None       # to give manually instead of txt
        ):
            # chosen in igor
            self.fpath = fpath
            self.fov = fov
            self.alpha = alpha
            self.min_distance = int(min_distance)
            self.synapseSize = synapse_size
            self.concat = concat
            self.tempFolder = tempFolder
            self.analysisWave = analysisWave
            self.mk_videos = mk_videos
            # not changeable from igor
            self.threshold_percentile = percentile
            self.sigma_smooth = sigma_smooth
            self.sigma_fit = sigma_fit
            self.lambda_reg = lambda_reg
            self.edge_margin = edge_margin
            # for debugging mostly
            self.igor = igor
            self.anWave_array = analysisWave_array
            self.run()

    # TODO 
    def run(self):
        # loading and data
        self.load_movie()
        self.get_metadata()
        self.mk_names()
        # make movie & stimulus
        self.deinterleave()
        self.mk_stimulus()
        self.stim_transitions() 
        # registration, interpolation, bleach correction
        self.preprocessing()
        # search for ROIs
        self.define_roi_size()
        self.find_rois()
        self.export_data()
        # plotting
        self.mk_figures()

    
    def load_movie(self):
        # assumes raw movie (not deinterleaved)
        # tf.imread loses metadata
        x = tf.TiffFile(self.fpath)
        # check for concatenation
        if len(self.concat) > 0:
            # paths from igor come in igor format (uses ":" separators)
            if platform.system() == 'Windows':
                movie_paths = [mp[0]+':'+mp[1:].replace(":","\\") for mp in self.concat[1:-1].split(',')]
            elif platform.system() == 'Darwin':
                movie_paths = [mp for mp in self.concat[1:-1].replace(":","/").replace("Macintosh HD","").split(",")]
            else:
                raise OSError(f'\nUnsupported platform: {platform.system()}'
                              'KS only runs on Windows and macOS\n')
            movies = [tf.imread(path) for path in movie_paths]
            self.cc_nframes = [int(len(movie)/2) for movie in movies]
            self.raw_movie = np.concatenate(movies,axis=0)
        else:
            self.raw_movie = x.asarray()
        # safety check: to avoid processing images or non-movie stacks
        if len(self.raw_movie.shape) < 3 or self.raw_movie.shape[0] < 100:
            raise Exception("this doesn't seem to be a framescan")
        # for output data
        if self.igor:
            if len(self.concat) > 0:
                print(f'python: processing movies from: {movie_paths}')
            else:
                print(f'python: processing movie from: {self.fpath}')
                

    # TODO: by removing the tag.names in get_metadata.py
    # this could be halved, taking off the 111 case
    # the other option is to use a dictionary 
    # honestly i don't know if it's worth the effort
    def get_metadata(self):
        self.metadata = get_metadata.get_scanImage_metadata(self.fpath)
        self.movie5d = False
        try_imageDescription, try_zData, try_Igor111 = False, False, False
        # try software type first
        try:
            self.frameRate = round(float(self.metadata['Software.SI.hRoiManager.scanFrameRate']))
            self.zoomFactor = float(self.metadata['Software.SI.hRoiManager.scanZoomFactor'])
            self.scanAngleMultFast = float(self.metadata["Software.SI.hRoiManager.scanAngleMultiplierFast"])
            self.scanAngleMultSlow = float(self.metadata["Software.SI.hRoiManager.scanAngleMultiplierSlow"])
            try_zData = True
        except:
            try_imageDescription = True
        # if software, try volumetric data
        if try_zData:
            try:
                self.zVolumes = int(self.metadata["Software.SI.hStackManager.actualNumVolumes"])
                self.zSlices = int(self.metadata["Software.SI.hStackManager.actualNumSlices"])
                self.zFlyback = int(self.metadata["Software.SI.hFastZ.numDiscardFlybackFrames"])
                self.zTotalSlices = int(self.metadata["Software.SI.hStackManager.numFramesPerVolumeWithFlyback"])
                self.zFrameRate = float(self.metadata["Software.SI.hRoiManager.scanVolumeRate"])
                self.movie5d = True
            except:
                pass
        # if not, try image description
        if try_imageDescription:
            try:
                self.frameRate = float(self.metadata["ImageDescription.state.acq.frameRate"])
                self.zoomFactor = float(self.metadata["ImageDescription.state.acq.zoomFactor"])
                self.scanAngleMultFast = float(self.metadata["ImageDescription.state.acq.scanAngleMultiplierFast"])
                self.scanAngleMultSlow = float(self.metadata["ImageDescription.state.acq.scanAngleMultiplierSlow"])
                # print("Field of view assumed to be 610, but do check this")
            except:
                try_Igor111 = True
        # if not, try user-igor made
        # this is from Igor, so it can be any kind, not only imageDescription
        if try_Igor111:
            try:
                self.frameRate = float(self.metadata['Software.SI.hRoiManager.scanFrameRate'])
                self.zoomFactor = float(self.metadata['Software.SI.hRoiManager.scanZoomFactor'])
                self.scanAngleMultFast = float(self.metadata["Software.SI.hRoiManager.scanAngleMultiplierFast"])
                self.scanAngleMultSlow = float(self.metadata["Software.SI.hRoiManager.scanAngleMultiplierSlow"])
                try_Igor111 = False
                try_zData = True
            except:
                pass
        # if software, try volumetric data
        if try_zData:
            try:
                self.zVolumes = int(self.metadata["Software.SI.hStackManager.actualNumVolumes"])
                self.zSlices = int(self.metadata["Software.SI.hStackManager.actualNumSlices"])
                self.zFlyback = int(self.metadata["Software.SI.hFastZ.numDiscardFlybackFrames"])
                self.zTotalSlices = int(self.metadata["Software.SI.hStackManager.numFramesPerVolumeWithFlyback"])
                self.zFrameRate = float(self.metadata["Software.SI.hRoiManager.scanVolumeRate"])
                self.movie5d = True
            except:
                pass
        # last case
        if try_Igor111:
            try:
                self.frameRate = float(self.metadata["ImageDescription.state.acq.frameRate"])
                self.zoomFactor = float(self.metadata["ImageDescription.state.acq.zoomFactor"])
                self.scanAngleMultFast = float(self.metadata["ImageDescription.state.acq.scanAngleMultiplierFast"])
                self.scanAngleMultSlow = float(self.metadata["ImageDescription.state.acq.scanAngleMultiplierSlow"])
            except:
                raise Exception("\nMetadata info not found\n")
        if self.movie5d:
            self.dt = 1/self.zFrameRate
        else:
            self.dt = 1/self.frameRate
            
    
    # define system paths 
    def mk_names(self):
        self.fdir = f'{os.path.sep}'.join(self.fpath.split(os.path.sep)[:-1])
        self.fname = self.fpath.split(os.path.sep)[-1].split('.')[0]
        # check if route to temp folder has been defined
        if len(self.tempFolder) > 0 and os.path.isdir(self.tempFolder):
            savedir = self.tempFolder         
        else:
            # otherwise, use same dir of movie + python_output
            savedir = os.path.join(self.fdir,'python_output')
            print(f'couldn\'t find temp folder ({self.tempFolder}).\nWill save files at: {savedir}\n')
        # savepath is dir + base filename -- to freely append suffixes later
        self.savepath = os.path.join(savedir,self.fname)
        if self.movie5d:
            self.savepath0 = self.savepath
            self.current_movie = 0
        if not os.path.isdir(savedir):
            os.mkdir(savedir)
        
        
    def deinterleave(self):
        if self.movie5d:
            self.totalFrames, channels, lines, cols = self.raw_movie.shape
            self.raw_movie = self.raw_movie.reshape(self.zTotalSlices, self.zVolumes, channels, lines, cols)
            self.raw_movie = self.raw_movie[:self.zSlices]
        # depending on microscope/move type
        if len(self.raw_movie.shape) == 3:
            self.channel2 = self.raw_movie[1::2]
            self.movie = self.raw_movie[0::2]
        elif len(self.raw_movie.shape) == 4:
            self.channel2 = self.raw_movie[:,1,:,:]
            self.movie = self.raw_movie[:,0,:,:]
        # in this case we have movies, instead of movie
        elif len(self.raw_movie.shape) == 5 and self.movie5d:
            self.channel2 = self.raw_movie[0,:,1,:,:]
            self.movies = self.raw_movie[:,:,0,:,:]
        # define some vars
        if self.movie5d:
            self.nframes = self.zVolumes
            self.duration = self.nframes/self.zFrameRate
        else:
            self.nframes = self.movie.shape[0]
            self.duration = self.nframes/self.frameRate


    # makes steps from linear arr with changing values
    def mk_stimulus(self, delta=0.05):
        # in some cases, ch2 will be empty
        # like in emily & elliot's movies
        # and the only way to know the stimulus will be to access some file
        # this also applies to any arbitrary segmentation to analyse the data
        path_to_anWave = os.path.join(self.fdir,"anWave.txt")
        temp_path_to_anWave = os.path.join(self.tempFolder,"anWave.txt")
        # in case is passed directly as argument
        if isinstance(self.anWave_array,np.ndarray):
            self.stimulus = self.anWave_array
            self.analysisWave = True
        elif os.path.isfile(path_to_anWave) and self.analysisWave:
            self.stimulus = np.loadtxt(path_to_anWave)
        elif os.path.isfile(temp_path_to_anWave) and self.analysisWave:
            self.stimulus = np.loadtxt(temp_path_to_anWave)
        else:
            self.stimulus = self.channel2.mean(axis=(1,2))
            # normalize (only if auto, because of the high values)
            if self.stimulus.max() > 5:
                self.stimulus = self.stimulus/self.stimulus.max()
        # stimulus as a function of time
        self.stimulus2d = np.zeros((2,self.nframes))
        if self.movie5d:
            self.stimulus2d[0] = np.arange(self.nframes)/self.zFrameRate    
        else:
            self.stimulus2d[0] = np.arange(self.nframes)/self.frameRate
        self.stimulus2d[1] = self.stimulus
        if self.igor:
            # tf.imwrite(f'{self.savepath}_stimulus.tif', self.stimulus2d)
            # np.savetxt(f'{self.savepath}_stimulus2d.csv', self.stimulus2d, delimiter=",")
            df = pd.DataFrame({'time': self.stimulus2d[0], 'intensity': self.stimulus})
            df.to_csv(f'{self.savepath}_stimulus.csv', index=False)
        else:
            plt.plot(*self.stimulus2d)
            plt.title("stimulus")
            plt.show()
            
            
    # decouple baseline & activity
    # delta: threshold to count as deviation from baseline
    # post_window: time window considered as potentially active (not baseline)
    def stim_transitions(self,delta=0.01,post_window=500):
        # get approx mean for comparison
        bval = self.stimulus[1:10].mean()
        # replace val at ~ t=0 (first window), to avoid artifacts
        self.stimulus[0] = bval
        self.baseline = np.where(abs(self.stimulus-bval) <= bval*delta, 0, 1)
        # for the analysis wave this isn't necessary
        if not self.analysisWave:
            # wx: window after which, even if baseline, signals reflect activity
            # 500 mls in frames (frameRate = framesPerSecond, so half) = 1s/post_window
            wx = int(self.frameRate * post_window/1000)
            # bis: points where baseline/resting intervals start (skips t=0)
            # if x(t)=rest=0 - x(t-1)=act=1 = -1 => from act to rest
            bis = np.where(self.baseline-np.roll(self.baseline,1)==-1)[0]
            # discard post activity windows
            for bi in bis:
                self.baseline[bi:bi+wx] = 1
        # remaining points are baseline/rest indices
        self.baseline_idxs = np.where(self.baseline==0)[0]
        self.activity_idxs = self.baseline.nonzero()[0]
        if not self.igor:
            baseline = np.zeros(self.baseline.shape)
            baseline[self.baseline_idxs] = 1
            plt.plot(baseline)
            plt.title("baseline idxs")
            plt.show()
            activity = np.zeros(self.baseline.shape)
            activity[self.activity_idxs] = 1
            plt.title("activity idxs")
            plt.plot(activity)
            plt.show()


    # preprocessing
    # added this to handle 5d movies
    def preprocessing(self):
        if self.movie5d:
            for i in range(len(self.movies)):
                self.current_movie = i
                self.movie = self.movies[i].copy()
                self.register()
                self.interpolate_square()
                self.correction()
                self.movies[i] = self.movie.copy()
        else:
            self.register()
            self.interpolate_square()
            self.correction()


    # i'm leaving this as independent in case we want
    # to try other registration methods
    # this registration is very straightforward
    # the mean (for reference) is computed only once, before registration
    # normally a proper registration should update the mean
    # so that it register in relation to the previously registered movie
    # this way (1 reg) introduces a bias to the phase cross corr
    # but is faster & it seems to work well enough nonetheless
    def register(self, upsample_factor=10):
        # static reference
        reference = self.movie.mean(axis=0)
        movie_reg = np.zeros_like(self.movie)
        for i in range(self.nframes):
            shift_est,_,_ = phase_cross_correlation(reference, self.movie[i], upsample_factor=upsample_factor)
            movie_reg[i] = shift(self.movie[i], shift_est)
        # to avoid inheritance problems
        self.movie = movie_reg.copy()
        if self.igor:
            if self.movie5d:
                self.savepath += f'_z{self.current_movie}_reg'
            else:
                self.savepath += '_reg'
            tf.imwrite(f'{self.savepath}.tif', self.movie)


    # it's upscaling because we're increasing the number of pixels in some axis
    # rather than an interpolatetion, it's making the pixels squared 
    # so it is a pixel aspect ratio correction (or anisotropic resample)
    # this is important for the demixing to work correctly
    # otherwise the gaussians could be fitting ovals, instead of circles
    # which wouldn't match the point spread function 
    # which is given by the light produced by the reporter
    def interpolate_square(self, upscale=True):
        # get real physical sizes of pixels (in microns)
        self.or_nrows, self.or_ncols = self.movie.shape[1:]
        self.fovx = self.fov / self.zoomFactor * self.scanAngleMultFast
        self.fovy = self.fov / self.zoomFactor * self.scanAngleMultSlow
        # pixel sizes: px:cols (horizontal), py:rows (vertical)
        self.px = self.fovx / self.or_ncols
        self.py = self.fovy / self.or_nrows

        # if pixels are smaller vertically
        if self.py < self.px:
            # then we need to make px_eq = py
            # and because: fovx = px_eq * ncols_sq
            self.ncols_sq = int(round(self.fovx/self.py))
            # now we can get px_sq (because npixels has to be int)
            # given: fovx = px_sq * ncols_sq
            self.px_sq = self.fovx / self.ncols_sq
            # zoom operates on movie dims (frames, rows, cols)
            # colZoom is the factor by which we need to increase the number of cols
            colZoom = self.ncols_sq / self.or_ncols
            # order 1 = bilinear
            self.movie = zoom(self.movie, zoom=(1, 1, colZoom), order=1)
            # for metadata
            self.py_sq = self.py
        # same, but viceversa
        elif self.px < self.py:
            self.nrows_sq = int(self.fovy/self.px)
            self.py_sq = self.fovy / self.nrows_sq
            rowZoom = self.nrows_sq / self.or_nrows
            self.movie = zoom(self.movie, zoom=(1, rowZoom, 1), order=1)
            self.px_sq = self.px
        # just for metadata
        else:
            self.px_sq, self.py_sq = self.px, self.py
        # else they're already squared
        # new sizes and shapes
        self.nrows, self.ncols = self.movie.shape[1:]
        # pixel size in microns (assuming squared pixels)
        self.pixelSize = (self.px + self.py)/2
        # save
        if self.igor:
            self.savepath += '_isq'
            tf.imwrite(f'{self.savepath}.tif', self.movie)

    
    # if a concatenated movie: 
    # linear/bleach correction is done for each part independently
    # then a normalization of the baseline ∆f/f level
    # otherwise, just do bleach correction
    def correction(self):
        if len(self.concat) == 0:
            self.bleach_correction()
            return
        # if concat:
        # this may seem strange/confusing
        # it's just to avoid changing the code later
        movie = self.movie.copy()
        start, end = 0, 0
        for nframes in self.cc_nframes:
            end += nframes
            # copy individual part and correct
            self.movie = movie[start:end]
            self.bleach_correction(concat=True)
            # copy back, after correction
            movie[start:end] = self.movie
            # new start (same as start = end)
            start += nframes
        # change back
        self.movie = movie.astype(float)
        
        # now ∆f/f normalization for all
        # from Kasia's code
        n_movies = len(self.cc_nframes)
        # first pass: get means & overall mean
        movies_means = np.zeros(n_movies)
        start, end = 0, 0
        for mi,nframes in enumerate(self.cc_nframes):
            end += nframes
            movies_means[mi] = self.movie[start:end].mean()
            start += nframes
        mean_mean = movies_means.mean()
        # second pass: normalize
        start, end = 0, 0
        for mi,nframes in enumerate(self.cc_nframes):
            end += nframes
            # scale: mean in relation to overall mean
            scale = movies_means[mi]/mean_mean
            self.movie[start:end] /= scale
            start += nframes
        # save
        if self.igor:
            self.savepath += '_bc'
            tf.imwrite(f'{self.savepath}.tif', self.movie)
            if self.movie5d:
                self.savepath = self.savepath0
                self.current_movie += 1
    
    # correct for the bleaching of glutamate
    def bleach_correction(self,rescale=True,concat=False):
        # reference
        frame_mean = self.movie.mean(axis=(1,2))
        def exp_decay(t,A,tau,C):
            return A*np.exp(-t/tau)+C
        # t = np.arange(self.nframes)/self.frameRate
        t = np.arange(self.movie.shape[0])/self.frameRate
        # initial guess for params
        p0 = [frame_mean[0] - frame_mean[-1], self.nframes/self.frameRate/2, frame_mean[-1]]
        # fits a curve to the bleaching using frame_mean as reference
        # params = [A_fit, tau_fit, C_fit]
        params,_ = curve_fit(exp_decay,t,frame_mean,p0=p0,maxfev=10000)
        # evaluate at every t
        fit_curve = exp_decay(t,*params)
        if not rescale:
            # divide each frame by fit curve value - 1e-8 is simply to avoid zero div
            self.movie = self.movie / np.maximum(fit_curve[:,None,None],1e-8)
        else:
            # same but rescaled (otherwise you risk normalizing)
            self.movie = self.movie * (fit_curve[0] / np.maximum(fit_curve[:,None,None],1e-8))
        if self.igor:
            if not concat:
                self.savepath += '_bc'
                tf.imwrite(f'{self.savepath}.tif', self.movie)
            if self.movie5d:
                self.savepath = self.savepath0



    # define the radius for 2d gaussian demixing
    def define_roi_size(self):
        # how many pixels per synapse + round it up, because most likely
        # synapses won't fit exactly the pixel grid -> |(| |)|
        self.roi_radius = np.ceil(self.synapseSize/self.pixelSize)/2
        # if min distance between peaks < roi radius (radius of gaussians)
        # then the demixing won't make sense
        if self.min_distance < self.roi_radius:
            self.min_distance = int(self.roi_radius) + 1


    # same as before, this function is here
    # to handle 5d movie cases
    def find_rois(self):
        if self.movie5d:
            self.movies_deltaf_maps, self.movies_deltaf_peaks = [], []
            self.movies_ks_peaks, self.movies_synapses = [], []
            self.movies_pixel_masks, self.movies_roi_masks = [], []
            self.movies_gs_amps = []
            self.movies_dff_traces = []
            # numpy can be tricky with inheritance 
            # so i prefer to do .copy() for these
            for i in range(len(self.movies)):
                self.movie = self.movies[i].copy()
                self.current_movie = i
                # get candidates from ∆F peak values
                self.mk_deltaf_map()
                self.movies_deltaf_maps.append(self.deltaf_map.copy())
                self.movies_deltaf_peaks.append(self.deltaf_peaks.copy())
                # evaluate candidates using KS
                self.ks_distance()
                self.movies_ks_peaks.append(self.ks_peaks.copy())
                self.movies_synapses.append(self.synapses.copy())
                self.movies_pixel_masks.append(self.synapses_mask_pixels.copy())
                self.movies_roi_masks.append(self.synapses_mask_rois.copy())
                # check in case no ROIs were found
                if isinstance(self.synapses, np.ndarray):
                    # demix ROIs using 2d gaussians
                    self.ridge_demixing()
                    self.movies_gs_amps.append(self.gs_amps.copy())
                    # get ROIs signals (∆F/F traces)
                    self.compute_dff_traces()
                    self.movies_dff_traces.append(self.dff_traces.copy())
                else:
                    self.movies_gs_amps.append([])
                    self.movies_dff_traces.append([])
                if not self.igor:
                    print(f'movie {i}: candidate peaks = {len(self.deltaf_peaks)}, significant = {len(self.synapses)}')
        else:
            self.mk_deltaf_map()
            self.ks_distance()
            if isinstance(self.synapses, np.ndarray):
                self.ridge_demixing()
                self.compute_dff_traces()


    # TODO: is percentile the best threshold abs?
    # wouldn't that be threshold rel?
    # ΔF/F map + peak detection
    def mk_deltaf_map(self):
        baseline_mean = self.movie[self.baseline_idxs].mean(axis=0)
        activity_mean = self.movie[self.activity_idxs].mean(axis=0)
        self.deltaf_map = gaussian_filter(activity_mean - baseline_mean, sigma=self.sigma_smooth)
        # minimum intensity for pixels
        threshold_abs = np.percentile(self.deltaf_map, self.threshold_percentile)
        # local max in: 2 * min distance + 1
        self.deltaf_peaks = peak_local_max(self.deltaf_map,
                            min_distance=self.min_distance,
                            threshold_abs=threshold_abs,
                            exclude_border=self.edge_margin)


    # KS between ROIs (baseline vs activity)
    def ks_distance(self):
        self.ks_peaks = []
        self.synapses_mask_pixels = []
        self.synapses_mask_rois = []
        # meshgrid for rows and cols
        yy, xx = np.indices((self.nrows, self.ncols))
        # make ROIs from pixels
        for y0,x0 in self.deltaf_peaks:
            # x^2 + y^2 = r^2
            mask = ((yy-y0)**2 + (xx-x0)**2) <= self.roi_radius**2
            # vals: pixel vals in circular region around pixel across movie
            # [:,mask] doesn't preserve shape: returns 1d arr for each frame
            baseline_vals = self.movie[self.baseline_idxs][:,mask].mean(axis=1)
            activity_vals = self.movie[self.activity_idxs][:,mask].mean(axis=1)
            # ΔF/F = (f1-f0)/f0
            f0 = baseline_vals.mean()
            f1 = activity_vals.mean()
            dff = (f1-f0)/f0 if f0 > 0 else np.nan
            # ks
            dist,pval = ks_2samp(baseline_vals, activity_vals)
            self.ks_peaks.append([y0,x0,dff,dist,pval])
        # ks peaks = [y0, x0, dff, ks dist, ks pval]
        # sort by p-vals
        self.ks_peaks = np.array(sorted(self.ks_peaks, key=lambda x:x[-1]))
        # in case there's no peaks detected
        if len(self.ks_peaks) == 0:
            self.synapses = []
            if self.movie5d:
                print('\nno peaks found\n')
                return
            else:
                raise Exception("\nNo peaks found\n")
        if not self.igor:
            plt.imshow(self.deltaf_map, cmap='gray')
            plt.scatter(*self.deltaf_peaks[:, ::-1].T, color='red')
            plt.title(f"movie {self.current_movie}: {len(self.deltaf_peaks)} peaks found")
            plt.show()
        # regular alpha thresholding
        pvals = self.ks_peaks[:,-1]
        significant = np.where(pvals < self.alpha)[0]
        # in case there's no synapses found
        if not np.any(significant):
            self.synapses = []
            if self.movie5d:
                return
            else:
                raise Exception ('\nNo significative peaks found\n')
        # remove non significant
        self.ks_peaks = self.ks_peaks[significant]
        # sort by ΔF/F and keep coords only (row, col, df/f, ks-d, ks-p)
        self.ks_peaks = np.array(sorted(self.ks_peaks, key=lambda x:x[2], reverse=False))
        self.synapses = self.ks_peaks[:,:2].astype(int)
        # masked 2d arrays for synapses
        self.synapses_mask_pixels = np.full(self.movie.shape[1:], 1, dtype=np.int16)
        self.synapses_mask_rois = np.full(self.movie.shape[1:], 1, dtype=np.int16)
        for ei, (row, col) in enumerate(self.synapses):
            val = -(ei + 1)
            self.synapses_mask_pixels[row,col] = val
            disk = ((yy-row)**2 + (xx-col)**2) <= self.roi_radius**2
            free = disk & (self.synapses_mask_rois == 1)
            self.synapses_mask_rois[free] = val
        if not self.igor:
            plt.imshow(self.deltaf_map, cmap='gray')
            plt.scatter(*self.synapses[:, ::-1].T, color='red')
            plt.title(f"movie {self.current_movie}: {len(self.synapses)} significant peaks")
            plt.show()


    # TODO: using a single bounding box for demixing all together is expensive
    # it may be faster to make clusters/groups of closeby rois to demix
    # the function splitting should be quickto be worthy though
    # TODO: may be useful to find a good lambda reg before demixing
    # returns the scalar amplitude per synapse & per frame, across movie
    # it returns a value for the entire 2d synapse (amplitude)
    # 2 x 2d gaussians fit for demixing
    # note that sigma fit is fixed, so every synapse is calculated using
    # the same gaussian width (safer, not knowing before hand their 3d pos)
    # padding doesn't necessary have to use the same edge_margins here
    def ridge_demixing(self):
        # unzip, same as zip(*synapses)
        ys, xs = np.array(self.synapses).T
        # discard margins
        ymin = max(0, ys.min()-self.edge_margin)
        ymax = min(ys.max()+self.edge_margin, self.nrows)
        xmin = max(0, xs.min()-self.edge_margin)
        xmax = min(xs.max()+self.edge_margin, self.ncols)
        sy = ymax - ymin
        sx = xmax - xmin
        # for the gaussians
        gs_list = []
        yy, xx = np.indices((sy,sx))
        for y0,x0 in self.synapses:
            # creates a 2d gaussian centered around pixel
            gi = np.exp(-((xx-(x0-xmin))**2 + (yy-(y0-ymin))**2)/(2*self.sigma_fit**2))
            gs_list.append(gi.ravel())
        # array of flattended gaussians
        gs = np.column_stack(gs_list)
        # cov matrix - here @ is the same as .matmul()
        # each element (i,j) is the dot product between:
        # the gaussian of synape i and the gaussian of synapse j
        # so the diagonal: dot product with itself => size
        # off-diagonal: overlap among synapses
        gs_cov = gs.T @ gs
        # lambda reg adds a small value to the diagonal (* np.eye)
        # so too small makes the solution unstable
        # too large it looses signals (makes weights almost 0)
        # here is basically hardcoded
        gs_demix = np.linalg.solve(gs_cov + self.lambda_reg * np.eye(gs_cov.shape[0]), gs.T)
        # get amplitudes
        self.gs_amps = np.zeros((self.synapses.shape[0],self.nframes))
        # for nf in range(self.nframes):
        #     frame = self.movie[nf,ymin:ymax,xmin:xmax].flatten()
        #     # example: 23 x (~128x128).flat @ (~128x128).flat x 1 => 23 x 1
        #     self.gs_amps[:,nf] = gs_demix @ frame
        # vectorized version, faster, but needs more checking
        frames = self.movie[:, ymin:ymax, xmin:xmax].reshape(self.nframes, -1).T
        self.gs_amps = gs_demix @ frames
        # save
        if self.igor:
            # the transposition is just for visualization
            if self.movie5d:
                np.savetxt(f'{self.savepath}_gs_amps{self.current_movie}.csv', self.gs_amps.T, delimiter=',')
            else:
                np.savetxt(f'{self.savepath}_gs_amps.csv', self.gs_amps.T, delimiter=',')


    # i assume is the same as only the first window
    def compute_dff_traces(self):
        # skips initial frames, to avoid artifacts
        baseline_idxs_dff = np.arange(20,self.activity_idxs[0])
        # baseline_idxs_dff = np.arange(self.activity_idxs[0])
        # get traces
        self.dff_traces = []
        for i,amp in enumerate(self.gs_amps):
            f0 = np.median(amp[baseline_idxs_dff])
            self.dff_traces.append((amp-f0)/f0)
        self.dff_traces = np.array(self.dff_traces)
        # save
        if self.igor:
            if self.movie5d:
                tf.imwrite(f'{self.savepath}_dff_traces{self.current_movie}.tif', self.dff_traces)
            else:
                tf.imwrite(f'{self.savepath}_dff_traces.tif', self.dff_traces)


    # save results & make plots
    def export_data(self):
        if self.igor:
            if self.movie5d:
                for i in range(len(self.movies)):
                    if len(self.movies_ks_peaks[i]) > 0:
                        dfx = pd.DataFrame(self.movies_ks_peaks[i], columns=["row","col","dF/F","ks-d","ks-p"])
                    if len(self.movies_synapses[i]) > 0:
                        dfx.to_csv(f'{self.savepath}_synapses_data{i}.csv')
                        tf.imwrite(f'{self.savepath}_pixelmask{i}.tif', self.movies_pixel_masks[i])
                        tf.imwrite(f'{self.savepath}_roimask{i}.tif', self.movies_roi_masks[i])
                    # import pdb; pdb.set_trace()
            else:
                dfx = pd.DataFrame(self.ks_peaks, columns=["row","col","dF/F","ks-d","ks-p"])
                dfx.to_csv(f'{self.savepath}_synapses_data.csv')
                tf.imwrite(f'{self.savepath}_pixelmask.tif', self.synapses_mask_pixels)
                tf.imwrite(f'{self.savepath}_roimask.tif', self.synapses_mask_rois)
        # txt info
        if self.igor:
            f = open(f'{self.savepath}_info.txt', 'w')
            f.write(f'movie={self.fname}\n')
            # input from Igor
            f.write(f'fov={self.fov}\n')
            f.write(f'alpha={self.alpha}\n')
            f.write(f'roiSize={self.synapseSize}\n')
            f.write(f'minDist={self.min_distance}\n')
            # volumetric data
            if self.movie5d:
                f.write(f'slices={self.zSlices}\n')
                f.write(f'discardedSlices={self.zFlyback}\n')
                f.write(f'totalSlices={self.zTotalSlices}\n')
                f.write(f'framesPerSlice={self.zVolumes}\n')
                f.write(f'sliceFrameRate={self.zFrameRate}\n')
                # this is for Igor access to this data
                f.write(f'frameRate={self.zFrameRate}\n')
                f.write(f'totalFrameRate={self.frameRate}\n')
                f.write(f'nFrames={self.zVolumes}\n')
                f.write(f'totalFrames={self.totalFrames}\n')
            else:
                f.write(f'frameRate={self.frameRate}\n')
                f.write(f'nFrames={self.nframes}\n')
            # remaining processing parameters
            f.write(f'duration={self.duration}\n')
            f.write(f'dt={self.dt}\n')
            f.write(f'zoomFactor={self.zoomFactor}\n')
            f.write(f'scanAngleMultFast={self.scanAngleMultFast}\n')
            f.write(f'scanAngleMultSlow={self.scanAngleMultSlow}\n')
            f.write(f'fov_x={self.fovx}\n')
            f.write(f'fov_y={self.fovy}\n')
            f.write(f'orig_ncols={self.or_ncols}\n')
            f.write(f'orig_nrows={self.or_nrows}\n')
            f.write(f'orig_pixelSize_x={self.px}\n')
            f.write(f'orig_pixelSize_y={self.py}\n')
            f.write(f'nRows={self.nrows}\n')
            f.write(f'nCols={self.ncols}\n')
            f.write(f'pixelSize_x={self.px_sq}\n')
            f.write(f'pixelSize_y={self.py_sq}\n')
            f.write(f'pixelSize_av={self.pixelSize}\n')
            f.write(f'roiRadius={self.roi_radius}\n')
            if self.movie5d:
                for i in range(len(self.movies)):
                    f.write(f'nSynapses{i}={len(self.movies_synapses[i])}\n')
            else:
                f.write(f'nSynapses={self.synapses.shape[0]}\n')
            f.write(f'fdir={self.fdir}')
            f.close()





    def mk_figures(self):
        if self.movie5d:
            for i in range(len(self.movies)):
                self.current_movie = i
                self.synapses = self.movies_synapses[i]
                if isinstance(self.synapses, np.ndarray):
                    if self.igor:
                        self.plot_synapses()
                        self.movie = self.movies[i]
                        self.overlay_synapses()
                    else:
                        self.plot_synapses(title=f'movie {i}')
                        self.dff_traces = self.movies_dff_traces[i]
                        self.plot_raster(title=f'movie {i}')
                        self.plot_traces(title=f'movie {i}')
        else:
            if isinstance(self.synapses, np.ndarray):
                self.plot_synapses()
                self.overlay_synapses()
                if not self.igor:
                    self.plot_raster()
                    self.plot_traces()


    # TODO: kwargs to scatter
    # th_vmin & th_vmax are the percentiles defining contrast for imshow
    # (to avoid 1 or 2 very bright pixels to mess up the scale)
    # imshow with sorted synapses
    def plot_synapses(self, th_vmin=5, th_vmax=99, title=""):
        vmin = np.percentile(self.deltaf_map, th_vmin)
        vmax = np.percentile(self.deltaf_map, th_vmax)
        plt.imshow(self.deltaf_map, cmap='gray', vmin=vmin, vmax=vmax)
        plt.axis('off')
        # plot synapses
        for ei,(sy,sx) in enumerate(self.synapses):
            # s: typographic points ** 2 & typographic points = 1/72 inches.
            # tp = 1*2.54/72 = 0.35277 
            plt.scatter(sx,sy,s=self.roi_radius*100,facecolors='none',edgecolor='orange',linewidths=1.2)
            # write n in list
            plt.text(sx,sy,str(ei),
                color='red',fontsize=9,
                ha='center',va='center',fontweight='bold')
        plt.tight_layout()
        if self.igor:
            # remove all margins (that's why synapses maps is using plt.savefig)
            plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
            if self.movie5d:
                tf.imwrite(f'{self.savepath}_deltaf{self.current_movie}.tif', self.deltaf_map.astype(np.float32))
                plt.savefig(f'{self.savepath}_synapses_map{self.current_movie}.png', dpi=100, bbox_inches='tight', pad_inches=0)
            else:
                tf.imwrite(f'{self.savepath}_deltaf.tif', self.deltaf_map.astype(np.float32))
                plt.savefig(f'{self.savepath}_synapses_map.png', dpi=100, bbox_inches='tight', pad_inches=0)
        else:
            plt.title(title)
            plt.show()


    # function to overlay circles in the movie
    def overlay_synapses(self,
                         color=(255,0,0),
                         thickness=1, 
                         percentile_clip=(1,99),
                         labels=False):
        # make movie gray
        lo, hi = np.percentile(self.movie, percentile_clip)
        gray = np.clip((self.movie - lo) / max(hi - lo, 1e-12), 0, 1)
        gray8 = (gray * 255).astype(np.uint8)
        # broadcast to RGB: (nframes, rows, cols, 3)
        # np.broadcast_to is cheap (no copy) but tif writer needs contiguous data,
        # so we materialize with repeat
        overlay = np.repeat(gray8[..., None], 3, axis=-1)        
        # calculate circles from coordinates
        # H, W = self.nrows, self.ncols
        rows, cols = [], []
        for r in range(int(self.roi_radius), int(self.roi_radius) + int(thickness)):
            for (y0, x0) in self.synapses:
                rr, cc = circle_perimeter(int(y0), int(x0), r, shape=(self.nrows, self.ncols))
                rows.append(rr)
                cols.append(cc)
        rr = np.concatenate(rows)
        cc = np.concatenate(cols)
        # mk circles
        for ch, val in enumerate(color):
            overlay[:, rr, cc, ch] = val
        # save
        if self.igor:
            if self.movie5d:
                tf.imwrite(f'{self.savepath}_overlay{self.current_movie}.tif', overlay)
            else:
                tf.imwrite(f'{self.savepath}_overlay.tif', overlay)
            if self.mk_videos:
                # I commented out these lines, but i'm not removing them
                # in case someone wants to use this functinoality
                # (it saves a tiff version of the movie with the red overlayed circles, in TIFF)
                # – it is useful to analayse the performance of the algorithm 
                # save a copy in desktop (to avoid permission issues)
                # fcopy_dir = str(Path.home()/"Desktop")
                # fcopy_name = f'{self.fname}_overlay_f{self.fov}_a{self.alpha}_r{self.synapseSize}_d{self.min_distance}.tif'
                # fcopy_path = os.path.join(fcopy_dir,fcopy_name)
                # tf.imwrite(fcopy_path, overlay)
                self.overlay_plus_stimulus(overlay)

    # overlay + stimulus 
    # i'm making this more general, in case we want to use it 
    # for other movies (reg, bc, etc)
    def overlay_plus_stimulus(self, movie):
        import matplotlib as mpl
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
        title = f'{self.fname} - FoV={self.fov}, α={self.alpha}, ~ROIsize={self.synapseSize}, d={self.min_distance}'
        fig.suptitle(title, fontsize=14)
        im = ax_mov.imshow(movie[0])
        # make x axis for time bar
        movie_secs = len(movie)/self.frameRate
        ax_stim.set_xlim(0, movie_secs)
        # every 10 seconds + last
        ticks = np.append(np.arange(0, movie_secs, 10), movie_secs).astype(int)
        ax_stim.set_xticks(ticks)
        ax_stim.set_xlabel("Time (s)")
        ax_stim.plot(*self.stimulus2d)
        bar = ax_stim.axvline(0, color='r')
        # for each frame
        def update(i):
            im.set_data(movie[i])
            # movie time in seconds
            t = i / self.frameRate
            bar.set_xdata([t, t])
            return im, bar

        ani = FuncAnimation(fig, update, frames=len(movie), blit=True)
        # ani.save(f'{self.savepath}_overlay_st.mp4', writer='ffmpeg', fps=int(self.frameRate), dpi=60)
        # save a copy in desktop folder
        fcopy_dir = str(Path.home()/"Desktop")
        fcopy_name = f'{self.fname}_overlay_f{self.fov}_a{self.alpha}_r{self.synapseSize}_d{self.min_distance}.mp4'
        fcopy_path = os.path.join(fcopy_dir,fcopy_name)
        ani.save(fcopy_path, writer='ffmpeg', fps=int(self.frameRate), dpi=60)
        plt.close()
    

    # plot best traces
    # TODO: why re-sorting using ΔF/F?
    # visually i get it, but shouldn't be consistent with imshow?
    # TODO: include significance rank in label
    # TODO: linspace or np.arange
    # for plotting is OK, but this hsould be np.arange
    def plot_traces(self, n=5, title=''):
        f, (a0,a1) = plt.subplots(2,1, gridspec_kw={'height_ratios': [1,7]})
        # for traces in seconds
        a0.plot(*self.stimulus2d)
        a0.set_xlim(xmin=0, xmax=self.duration)
        a0.set_xticks([])
        a0.set_yticks([])
        for ni in range(min(n,len(self.dff_traces))):
            a1.plot(self.stimulus2d[0],self.dff_traces[ni])
        a1.set_xlim(xmin=0, xmax=self.duration)
        # a1.set_xticks(np.arange(0,self.stimulus.size+1,100))
        # a1.set_yticks(np.arange(0,locs.shape[0],5))
        a1.set_ylabel("ΔF/F")
        a1.set_xlabel("seconds")
        plt.suptitle(title)
        plt.tight_layout()
        if self.igor:
            plt.savefig(f'{self.savepath}_{n}traces.png')
        else:
            plt.show()


    # TODO: what is vmax here?
    # basically same as before, but for all
    def plot_raster(self, title=''):
        f, (a0,a1) = plt.subplots(2,1, gridspec_kw={'height_ratios': [1,7]})
        # for traces in seconds
        a0.plot(*self.stimulus2d)
        a0.set_xlim(xmin=0, xmax=self.duration)
        a0.set_xticks([])
        a0.set_yticks([])
        # raster
        # for imshow we can't change the data
        vmax=np.percentile(np.abs(self.dff_traces),99)
        a1.imshow(self.dff_traces, aspect='auto', cmap='gray',
                  vmin=-vmax,vmax=vmax,
                  extent=[0,self.duration,0,self.dff_traces.shape[0]])
        # x ticks (time)
        a1.set_xticks(np.arange(0,self.duration+1,int(self.duration/10)))
        # y ticks need to be inverted (from best to worst)
        # also ticks are placed in n + 0.5 positions
        # to better align with the traces
        # ticks = np.append(np.arange(0,len(self.dff_traces),0.5),len(self.dff_traces))
        # ticks = ticks[::-1]
        # ticks = np.where(ticks[::-1]%1,ticks,0)
        # a1.set_yticklabels(["" if x==0 else int(x) for x in ticks])
        n_synapses = len(self.dff_traces)
        ticks = np.arange(n_synapses) + 0.5        
        a1.set_yticks(ticks)
        a1.set_yticklabels(np.arange(n_synapses -1, -1, -1))
        # labels
        a1.set_ylabel("synapses")
        a1.set_xlabel("seconds")
        plt.suptitle(title)
        plt.tight_layout()
        if self.igor:
            plt.savefig(f'{self.savepath}_rasterplot.png')
        else:
            plt.show()
            # import pdb; pdb.set_trace()

    # quick stimulus plot
    def plot_stimulus(self):
        plt.plot(*self.stimulus2d)
        plt.show()

    # same for baseline
    def plot_baseline(self):
        bx = np.ones(self.nframes)
        bx[self.baseline_idxs] = 0
        plt.plot(np.arange(self.nframes),bx)
        plt.plot(self.stimulus)
        plt.show()


# anWave = np.zeros(600)
# anWave[120:360] = 1
# fpath = "/Users/f/Dropbox/_r66y/data/2p_data/demoMovies/new_movies/AFx_s7_ss5_50lines_L60Mw_00001.tif"
# KS_pipeline(fpath, analysisWave_array=anWave)

# to run from terminal
if __name__ == "__main__":
    path_to_movie = sys.argv[1]
    # default values, these are defined from Igor
    fov = 610
    alpha = 0.05
    min_distance = 3
    synapse_size = 2
    concat = ""                 # has to be changed for concatenated movies
    tempFolder = ""             # dir for files and outputs
    analysisWave = False        # stimulus/analysis wave 
    mk_videos = False           # overlay and overlay + stimulus
    igor = True                 # mostly for debugging
    # look for arguments
    for ei,arg in enumerate(sys.argv):
        # these can be changed from panel in Igor
        if arg.startswith('--fov='):
            fov = float(arg.split('=')[1])
        if arg.startswith('--alpha='):
            alpha = float(arg.split('=')[1])
        if arg.startswith('--minDist='):
            min_distance = float(arg.split('=')[1])
        if arg.startswith('--ROIsize='):
            synapse_size = float(arg.split('=')[1])
        if arg.startswith('--concat'):
            concat = str(arg.split('=')[1])
        if arg.startswith('--tempFolder'):
            tempFolder = str(arg.split('=')[1])
        if arg.startswith('--anwave'):
            analysisWave = True
        if arg == '--mk-videos':
            mk_videos = True
        # can be changed from terminal
        if arg == '--not-igor':
            igor = False
    # check if required libs are installed
    check_dependencies()
    x = KS_pipeline(fpath=path_to_movie,
        fov=fov,
        alpha=alpha,
        min_distance=min_distance,
        synapse_size=synapse_size,
        concat=concat,
        tempFolder=tempFolder,
        analysisWave=analysisWave,
        mk_videos=mk_videos,
        igor=igor,
        )









#
