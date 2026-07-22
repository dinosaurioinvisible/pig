#!/usr/bin/env python3
# -*- coding: utf-8 -*-


from pathlib import Path
import numpy as np
import pandas as pd
import tifffile as tf
import matplotlib.pyplot as plt


def save_output(result, savepath, suffix="_uu"):
    savepath = Path(savepath)
    # table-like data
    if isinstance(result, pd.DataFrame):
        output_path = savepath.with_name(f'{savepath.stem}{suffix}.csv')
        result.to_csv(output_path, index=False)
    # ndarray
    elif isinstance(result, np.ndarray):
        # 2D array: grayscale image
        if result.ndim == 2:
            output_path = savepath.with_name(f'{savepath.stem}{suffix}.tif')
            tf.imwrite(output_path, result)
        # 3D array: movie or RGB image
        elif result.ndim == 3:
            if result.shape[-1] in (3, 4):
                # Shape: rows × columns × RGB/RGBA
                output_path = savepath.with_name(f'{savepath.stem}{suffix}.png')
                plt.imsave(output_path, result)
            else:
                # Shape: frames × rows × columns
                output_path = savepath.with_name(f'{savepath.stem}{suffix}.tif')
                tf.imwrite(output_path, result)
        # 4D array: usually an RGB movie
        elif result.ndim == 4 and result.shape[-1] in (3, 4):
            output_path = savepath.with_name(f'{savepath.stem}{suffix}.tif')
            tf.imwrite(output_path, result)
        else:
            # Generic NumPy data
            output_path = savepath.with_name(f'{savepath.stem}{suffix}.npy')
            np.save(output_path, result)
    # text
    elif isinstance(result, str):
        output_path = savepath.with_name(f'{savepath.stem}{suffix}.txt')
        output_path.write_text(result)
    # Anything else
    else:
        raise TypeError(f'Do not know how to save object of type {type(result).__name__}')
    # 
    print(f"\nSaved to: {output_path}")
    return output_path


    







#