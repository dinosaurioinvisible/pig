
import os
import sys
import tifffile as tf


def flatten_dict(d, parent_key="", sep="."):
    flat = {}
    for key, value in d.items():
        new_key = f"{parent_key}{sep}{key}" if parent_key else key
        if isinstance(value, dict):
            flat.update(flatten_dict(value, new_key, sep=sep))
        else:
            flat[new_key] = value
    return flat

# input: path to movie
def get_scanImage_metadata(path_to_movie,igor=False):
    # load movie
    x = tf.TiffFile(path_to_movie)
    metadata = {}
    # the idea is to get info from every tag in metadata
    for key in x.pages[0].tags.keys():
        tag = x.pages[0].tags[key]
        tag_data = x.pages[0].tags[tag.name].value
        # this and software have a lot of data
        if tag.name == 'ImageDescription':
            paired_data = tag_data.split('\n')
            # sometimes they use \r, sometimes \n
            if len(paired_data) == 1:
                paired_data = tag_data.split('\r')
            for i in paired_data:
                try:
                    k,v = i.split('=')
                    metadata[f'{tag.name}.{k.strip()}'] = v.strip()
                except:
                    metadata[f'{tag.name}.{k.strip()}'] = i
        elif tag.name == 'Software':
            if len(paired_data) == 1:
                paired_data = tag_data.split('\r')
            for i in paired_data:
                try:
                    k,v = i.split('=')
                    metadata[f'{tag.name}.{k.strip()}'] = v.strip()
                except:
                    metadata[f'{tag.name}.{k.strip()}'] = i
        # artist also has a lot of data, in json format
        elif tag.name == 'Artist':
            import json
            json_dict = json.loads(tag_data)
            flat_data = flatten_dict(json_dict)
            for k,v in flat_data.items():
                metadata[f'{tag.name}.{k}'] = v
        else:
            # the rest is very simple
            metadata[tag.name] = tag_data
    # output to be loaded in igor
    if igor:
        fdir = os.path.join(os.path.sep.join(path_to_movie.split(os.path.sep)[:-1]),'python_output')
        if not os.path.isdir(fdir):
            os.mkdir(fdir)
        fname = path_to_movie.split(os.path.sep)[-1].split('.')[0] + '_metadata.txt'
        fpath = os.path.join(fdir,fname)
        f = open(f'{fpath}', 'w')
        for k,v in metadata.items():
            # remove commas to avoid data being truncated when read in igor
            v_str = str(v).replace(',',' ')
            f.write(f'{k}={v_str}\n')
        f.close()
    else:
        # printout & return
        print('\n\nmetadata found:\n')
        for k,v in metadata.items():
            print(f'{k} : {v}')
        return metadata

# this, or any other testing movie has to be commented out
# otherwise Igor function won't work
# movie = "/Users/f/Desktop/eemovie/F2C1_Dir12_5Hz_00001.tif"
# movie = "//Users/f/desktop/iGluSnFR-4s tests/050526/AF10_HUC/glusnfr4_CR_20Hz004.tif"
# get_scanImage_metadata(movie)

# to run from terminal
if __name__ == "__main__":
    path_to_movie = sys.argv[1]
    get_scanImage_metadata(path_to_movie,igor=True)






